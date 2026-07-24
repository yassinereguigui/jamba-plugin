# Authentication and Authorization

## Summary

Authentication (who are you?) and authorization (what are you allowed to do?) are the most consequential security decisions in API design. This file covers OAuth 2.0/2.1, OIDC, token patterns, fine-grained authorization models (RBAC/ABAC/ReBAC), delegation for agentic systems, and practical implementation guidance. The distinction between authentication and authorization is critical — conflating them produces insecure APIs.

---

## OAuth 2.0 Flows: When to Use Each

### Authorization Code + PKCE (Current Best Practice)

For any flow where a user delegates access to a third-party application. PKCE (Proof Key for Code Exchange) is now required for all clients per OAuth 2.1.

**Full flow:**
```
1. App generates code_verifier (random 43-128 char string)
2. App computes code_challenge = BASE64URL(SHA256(code_verifier))
3. Redirect to authorization endpoint:
   GET /authorize?
     response_type=code&
     client_id=app-123&
     redirect_uri=https://app.example.com/callback&
     scope=openid profile orders:read&
     state=random-csrf-protection-value&
     code_challenge=s256_hash_here&
     code_challenge_method=S256

4. User authenticates and consents
5. Auth server redirects to: /callback?code=AUTH_CODE&state=...

6. App exchanges code:
   POST /token
   grant_type=authorization_code&
   code=AUTH_CODE&
   redirect_uri=https://app.example.com/callback&
   client_id=app-123&
   code_verifier=ORIGINAL_VERIFIER  ← PKCE: proves same party that started the flow

7. Response:
   {
     "access_token": "...",
     "token_type": "Bearer",
     "expires_in": 3600,
     "refresh_token": "...",
     "id_token": "..."   ← Only with openid scope (OIDC)
   }
```

**Why PKCE matters:** Without PKCE, an authorization code intercepted by a malicious app (via URL scheme hijacking on mobile, or open redirects) can be exchanged for tokens. PKCE's verifier/challenge makes the intercepted code useless without the original `code_verifier`, which never leaves the legitimate app.

**State parameter:** Prevents CSRF attacks on the authorization flow. Verify that the `state` in the callback matches what was sent in step 3.

### Client Credentials (Machine-to-Machine)

For server-to-server communication where no user is involved:

```
POST /token
grant_type=client_credentials&
client_id=service-a&
client_secret=secret&
scope=orders:read inventory:write

Response:
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

Use this for:
- Backend service calling another backend service
- CI/CD pipelines calling APIs
- Scheduled jobs accessing APIs

**Client secret alternatives:** For higher security M2M auth, use client assertion (JWT signed with private key) instead of a static client secret:
```
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&
client_assertion=<signed_jwt>
```

### Device Authorization Flow

For devices with limited input (smart TVs, IoT, CLI tools):

```
1. Device POSTs to /device/authorize
   Response: { "device_code": "...", "user_code": "WDJB-MJHT", 
               "verification_uri": "https://auth.example.com/device",
               "expires_in": 1800, "interval": 5 }

2. Device displays: "Go to auth.example.com/device and enter WDJB-MJHT"

3. Device polls /token every 5 seconds:
   grant_type=urn:ietf:params:oauth:grant-type:device_code&
   device_code=...

4. User completes flow on another device

5. Next poll returns tokens
```

OpenAPI 3.2 now supports documenting this flow natively.

### Flows to Avoid (Deprecated in OAuth 2.1)

**Implicit Flow:** Tokens returned directly in URL fragment (never safe, removed in OAuth 2.1).

**Resource Owner Password Credentials (ROPC):** User enters credentials directly into the client app. This defeats the entire purpose of OAuth (the delegated authorization model). Still seen in legacy enterprise integrations; avoid entirely in new systems.

---

## OAuth 2.1: What Changed

OAuth 2.1 (IETF draft-ietf-oauth-v2-1-15, stable as of 2025) consolidates:
- RFC 6749 (OAuth 2.0)
- RFC 7636 (PKCE)
- RFC 9700 (OAuth 2.0 Security BCP)

**Changes from 2.0:**
| Change | Impact |
|--------|--------|
| PKCE required for all authorization code flows | Previously only required for public clients |
| Implicit grant removed | Eliminate `response_type=token` |
| ROPC grant removed | Eliminate password grant |
| Exact redirect URI matching required | No wildcard or partial matching |
| Refresh tokens: sender-constrained or one-time-use | Rotation on every use (or DPoP binding) |

Most modern authorization servers (Auth0, Okta, Keycloak, AWS Cognito) already implement OAuth 2.1 semantics even before the RFC is finalized.

---

## OpenID Connect (OIDC)

OIDC is an identity layer on top of OAuth 2.0. It adds a standardized way to get verified user identity information.

**Key additions over OAuth 2.0:**
- **ID Token:** A JWT containing user identity claims (`sub`, `email`, `name`, etc.)
- **UserInfo Endpoint:** `GET /userinfo` with access token returns user claims
- **Discovery:** `GET /.well-known/openid-configuration` returns server metadata
- **Standard Claims:** `sub`, `name`, `email`, `email_verified`, `picture`, `locale`

**ID Token vs. Access Token:**
```json
// ID Token (for the client/frontend to learn about the user)
{
  "iss": "https://auth.example.com",
  "sub": "user-abc123",          // Stable, opaque user identifier
  "aud": "client-app-id",        // Audience: the client app
  "exp": 1735689600,
  "iat": 1735686000,
  "email": "alice@example.com",
  "email_verified": true,
  "name": "Alice Smith"
}

// Access Token (for API authorization — do NOT use as user identity)
// May be opaque or a JWT — its format is undefined by OIDC
// APIs should validate it but not rely on its internal structure
```

**Critical distinction:** The ID token's audience (`aud`) is the client app. The access token's audience is the resource server (API). Never use an access token as an ID token or vice versa.

**OIDC discovery:**
```
GET https://auth.example.com/.well-known/openid-configuration

{
  "issuer": "https://auth.example.com",
  "authorization_endpoint": "https://auth.example.com/authorize",
  "token_endpoint": "https://auth.example.com/token",
  "userinfo_endpoint": "https://auth.example.com/userinfo",
  "jwks_uri": "https://auth.example.com/.well-known/jwks.json",
  "response_types_supported": ["code"],
  "scopes_supported": ["openid", "profile", "email"],
  "token_endpoint_auth_methods_supported": ["client_secret_post", "private_key_jwt"]
}
```

APIs should use the `jwks_uri` to fetch public keys dynamically rather than hardcoding them — enables key rotation without downtime.

---

## Token Patterns: JWT vs. Opaque

### Self-Contained JWT

```json
// Header.Payload.Signature (base64url encoded)
{
  "alg": "RS256",
  "kid": "key-2024-01"
}
.
{
  "iss": "https://auth.example.com",
  "sub": "user-abc123",
  "aud": "https://api.example.com",
  "exp": 1735689600,
  "iat": 1735686000,
  "scope": "orders:read orders:write",
  "customer_tier": "premium"
}
```

**Advantages:**
- Stateless: API can validate without calling auth server
- Low latency: no network round-trip per request
- Embeds claims: API gets user/role info without DB lookup

**Disadvantages:**
- Cannot be revoked before expiry (unless using a revocation list, which is a network call)
- Claims in token can become stale (user changes role; old tokens still carry old role)
- Larger payload (~500 bytes vs ~22 bytes for an opaque token)

### Opaque Token (Token Introspection)

The API receives an opaque token and calls the auth server to validate it:

```
POST /token/introspect
Authorization: Basic <api-credentials>
token=access_token_value

Response:
{
  "active": true,
  "sub": "user-abc123",
  "scope": "orders:read",
  "exp": 1735689600,
  "client_id": "client-app"
}
```

**Advantages:**
- Immediately revocable: mark token inactive at auth server; next introspection returns `active: false`
- Token content changes are reflected immediately
- Token format is opaque to clients (harder to extract claims client-side)

**Disadvantages:**
- Network call per API request (latency hit)
- Auth server becomes a critical dependency for every API call
- Introspection responses can be cached (with short TTL), but this reintroduces the staleness problem

### The Distributed Systems Trade-Off

| Concern | JWT | Opaque |
|---------|-----|--------|
| Immediate revocation | No (TTL-based) | Yes |
| Latency | Low (local validation) | Higher (introspection call) |
| Auth server dependency | Only on key refresh | Every request |
| Claim freshness | Stale until expiry | Fresh on every call |

**Practical resolution:** Use JWTs with short expiry (15 minutes) + refresh token rotation. This limits the revocation window to 15 minutes — acceptable for most use cases. For immediate revocation requirements (high-security, financial), use short-lived JWTs + a revocation list (Redis set of revoked `jti` claims checked on each request).

---

## Refresh Token Rotation

The security best practice (required in OAuth 2.1):

1. Client exchanges refresh token for new access token
2. Auth server issues: new access token + **new** refresh token
3. Auth server invalidates the old refresh token

**Refresh token reuse detection:** If the old refresh token is presented again (attacker stole it and is racing), the auth server detects this and invalidates the *entire token family* (all tokens issued from that original grant). This signals a security event — log it and alert.

```
POST /token
grant_type=refresh_token&
refresh_token=old_refresh_token_here
client_id=app-123

Response:
{
  "access_token": "new_access_token",
  "token_type": "Bearer",
  "expires_in": 900,          // 15 minutes
  "refresh_token": "new_refresh_token_here"  ← New each time
}
```

**Storage on clients:**
- Refresh tokens: `httpOnly; Secure; SameSite=Strict` cookies (backend for web apps) or platform Keychain/Keystore (native apps)
- Access tokens: memory only (not localStorage — XSS risk)

---

## Fine-Grained Authorization

### Authorization Models Overview

**RBAC (Role-Based Access Control):** Users assigned roles; roles have permissions.
```
User Alice → Role: "admin"
Role "admin" → Permission: "orders:delete"
```

**ABAC (Attribute-Based Access Control):** Access decisions based on attributes of the user, resource, and environment.
```
Policy: ALLOW if
  user.department == resource.department AND
  user.clearance >= resource.sensitivity_level AND
  environment.time.hour in [9, 17]
```

**ReBAC (Relationship-Based Access Control):** Access based on a graph of relationships between entities.
```
Alice is editor of Document D
Alice's team is owner of Project P
Document D is in Project P
→ Alice can edit Document D
```

ReBAC is a superset of RBAC (roles are relationships) and can express ABAC patterns (attributes modeled as relationships).

### Choosing an Authorization Model

| Scenario | Recommended Model |
|----------|------------------|
| SaaS with simple roles (admin/user/viewer) | RBAC |
| Multi-tenant with per-resource permissions | ReBAC (Zanzibar-inspired) |
| Healthcare/government with attribute-based controls | ABAC |
| Google Drive-like sharing | ReBAC (this is literally Google Zanzibar's origin) |
| General-purpose policy engine for infrastructure | OPA |

### OPA (Open Policy Agent)

OPA is the CNCF-graduated policy engine. Policies are written in Rego:

```rego
package api.authorization

default allow = false

allow {
  input.method == "GET"
  input.path == ["users", user_id]
  input.user.id == user_id
}

allow {
  input.user.roles[_] == "admin"
}

allow {
  input.user.roles[_] == "moderator"
  input.method in ["GET", "PATCH"]
  startswith(input.path[0], "content")
}
```

OPA evaluates policies at microsecond speeds when running as a sidecar. Integration:
```
POST http://localhost:8181/v1/data/api/authorization/allow
{
  "input": {
    "user": { "id": "u-123", "roles": ["user"] },
    "method": "DELETE",
    "path": ["orders", "o-456"]
  }
}
```

**OPA strengths:** Extremely flexible, great for infrastructure policy (Kubernetes admission, API gateway rules, Terraform validation). **OPA weakness:** Rego has a steep learning curve; policies that need to query dynamic data (database state) require policy data synchronization.

### Cerbos

Cerbos takes a YAML-first approach. More accessible than OPA for application-layer authorization:

```yaml
# resource_policies/order.yaml
apiVersion: api.cerbos.dev/v1
resourcePolicy:
  version: default
  resource: order
  rules:
    - actions: [read]
      effect: EFFECT_ALLOW
      roles: [user, admin]
    - actions: [update, cancel]
      effect: EFFECT_ALLOW
      roles: [admin]
    - actions: [cancel]
      effect: EFFECT_ALLOW
      roles: [user]
      condition:
        match:
          expr: request.resource.attr.status == "pending" && request.resource.attr.owner_id == request.principal.id
```

Cerbos runs as a sidecar or embedded SDK, evaluating policies with sub-millisecond latency. No Rego to learn.

### Zanzibar-Based Systems (ReBAC)

Google's Zanzibar (2019 paper) defines a globally consistent, low-latency authorization system storing tuples:

```
(object, relation, user)
document:doc-123#viewer@user:alice
document:doc-123#editor@user:bob
folder:project-x#owner@user:carol
document:doc-123#parent@folder:project-x
```

A check: "Can Alice view doc-123?" traverses the graph:
- `alice` is `viewer` of `doc-123` → ALLOW
- or: `alice` inherits permissions via `folder:project-x` relationship

**Open-source implementations:**

| Tool | Maturity | Best For |
|------|----------|---------|
| OpenFGA (Auth0/Okta) | Production-ready | Auth0 ecosystem, broad language support |
| SpiceDB (AuthZed) | Production-ready | High scale (used by OpenAI, tens of billions of relationships) |
| Permify | Growing | Developer experience, visual playground |

**When to use Zanzibar-based authorization:** When you have complex sharing semantics (document/folder/workspace hierarchies), multi-tenant resources where users can share access with others, or any "can user X do Y to resource Z?" query that requires graph traversal.

---

## Scopes vs. Claims for Authorization

**Scopes:** OAuth mechanism for coarse-grained consent. Represent categories of access.
```
orders:read    — Can read order data
orders:write   — Can create/modify orders
admin:*        — Full admin access
```

**Claims:** JWT payload fields that carry assertions about the user.
```json
{
  "sub": "user-abc123",
  "scope": "orders:read orders:write",
  "customer_tier": "premium",
  "org_id": "org-xyz",
  "roles": ["user", "billing_admin"]
}
```

**The authorization hierarchy:**
1. Scopes determine what *categories* of operations the token permits (user consent)
2. Claims carry user attributes and roles
3. Fine-grained authorization (OPA/Cerbos/SpiceDB) makes the actual per-resource decision using claims + resource attributes

Don't try to encode fine-grained permissions entirely in JWT claims — this approach doesn't scale. Use scopes for coarse consent, claims for identity, and an authorization service for fine-grained decisions.

---

## Machine-to-Machine Auth Patterns

### Workload Identity (Cloud-Native)

In cloud environments, services should use platform-provided identities rather than long-lived credentials:

- **AWS:** IAM Roles for EC2/ECS/Lambda — no credentials needed; the SDK fetches instance metadata credentials automatically
- **GCP:** Service accounts bound to workloads via Workload Identity — K8s service account → GCP service account mapping
- **Azure:** Managed Identity — system/user-assigned identities attached to compute resources

```python
# AWS: no credentials in code
import boto3
client = boto3.client('s3')  # Automatically uses instance role

# GCP: Application Default Credentials
from google.cloud import storage
client = storage.Client()  # Uses workload identity
```

### SPIFFE/SPIRE

SPIFFE (Secure Production Identity Framework For Everyone) provides a standard for workload identity in multi-cloud and multi-cluster environments. SPIRE (SPIFFE Runtime Environment) is the reference implementation.

Each workload gets a cryptographic identity (SVID — SPIFFE Verifiable Identity Document). Other services verify the SVID. This enables mTLS between services without pre-provisioned certificates.

Istio and Linkerd use SPIFFE SVIDs internally for their automatic mTLS.

---

## Delegated Authorization for Agentic Systems

When AI agents act on behalf of users, the authorization model needs to handle:
1. What is the agent permitted to do?
2. Are the agent's actions traceable to a specific human authorization?
3. Can the human revoke the agent's authorization?

**Token-bound delegation pattern:**

```json
// Access token with agent delegation claim
{
  "sub": "user-alice",           // Human principal
  "act": {                       // RFC 8693 actor claim
    "sub": "agent-assistant-v1", // The agent acting
    "client_id": "ai-assistant"
  },
  "scope": "calendar:read email:read",  // Minimal scope
  "delegation_id": "deleg-abc123",      // Revocable delegation
  "exp": 1735689600
}
```

**RFC 8693 (Token Exchange)** defines how to exchange tokens for delegated-authority tokens. The agent presents the user's token to the auth server and receives a narrower-scope token that records the delegation chain.

**Practical implementation for agents (2024–2025):**
- Issue agents short-lived tokens with minimal scopes (principle of least privilege)
- Record all agent actions with the delegation chain in audit logs
- Provide a "revoke agent access" UX for users
- Rate limit agent-issued requests separately from user-issued requests

MCP (Model Context Protocol) uses OAuth 2.1 for remote server authorization — see `16_mcp_protocol.md` for MCP-specific auth patterns.

---

## API Key Management at Scale

For APIs serving thousands of developers with API keys:

**Key lifecycle:**
```
Generate → Distribute (once, in plaintext) → Store (hashed) → Use → Rotate → Revoke
```

**Key generation:**
```python
import secrets
import hashlib

def generate_api_key(prefix: str = "sk_live") -> tuple[str, str]:
    raw_key = secrets.token_urlsafe(32)  # 256 bits
    full_key = f"{prefix}_{raw_key}"
    key_hash = hashlib.sha256(full_key.encode()).hexdigest()
    return full_key, key_hash  # Return full key once; store only hash
```

**Key lookup pattern:**
```python
def authenticate_request(provided_key: str) -> Optional[ApiKey]:
    # Extract prefix for database index
    prefix = provided_key[:16]  # "sk_live_4K8mX9P2"
    
    # Query by prefix (fast), then verify hash (correct)
    candidates = db.api_keys.filter(prefix=prefix, revoked_at=None)
    
    provided_hash = hashlib.sha256(provided_key.encode()).hexdigest()
    for key in candidates:
        if secrets.compare_digest(key.key_hash, provided_hash):
            db.api_keys.update(id=key.id, last_used_at=now())
            return key
    return None
```

**Usage-based rate limits:** Different API keys can have different rate limits (free tier: 100/min; paid: 10,000/min). Store limits on the key record.

**Usage tracking for billing:** Log key ID + endpoint + timestamp in an analytics pipeline (not the application database — write volume is too high). Use this for billing, abuse detection, and deprecation tracking.

---

## Key References

- [OAuth 2.1 Authorization Framework — IETF Draft](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-10)
- [Auth0: Authorization Code Flow with PKCE](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow-with-pkce)
- [OAuth 2.0 Security Best Current Practice (RFC 9700)](https://datatracker.ietf.org/doc/html/rfc9700)
- [RFC 8693: OAuth 2.0 Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693)
- [OpenFGA Documentation](https://openfga.dev/docs)
- [SpiceDB GitHub](https://github.com/authzed/spicedb)
- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Cerbos Documentation](https://docs.cerbos.dev/)
- [Google Zanzibar Paper](https://research.google/pubs/pub48190/)
- [Auth0: Refresh Token Rotation](https://auth0.com/blog/refresh-tokens-what-are-they-and-when-to-use-them/)
- [SPIFFE/SPIRE](https://spiffe.io/)
- [MCP, OAuth 2.1, PKCE, and the Future of AI Authorization](https://aembit.io/blog/mcp-oauth-2-1-pkce-and-the-future-of-ai-authorization/)
- [WorkOS: OAuth 2.1 What's New](https://workos.com/blog/oauth-2-1-whats-new)

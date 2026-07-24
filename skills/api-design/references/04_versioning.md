# API Versioning Strategies

## Summary

API versioning is the practice of managing change in a public contract over time. It is one of the most consequential and most-argued decisions in API design. Done well, it allows APIs to evolve without breaking consumers. Done poorly, it creates proliferation of dead versions, incompatible clients, and operational burden. There is genuine disagreement among practitioners; this file maps the trade-offs honestly.

---

## The Fundamental Problem Versioning Solves

APIs are contracts between a provider and consumers. Consumers build on documented behavior and expect it to remain stable. Providers need to fix bugs, improve designs, and add features that sometimes require incompatible changes. Versioning is the mechanism for managing this tension.

**The alternative to versioning** is the "additive-only" or "API evolution" approach: never remove or change existing fields; only add. This works until it doesn't — when you need to fundamentally change a design, you either live with the bad design forever or version anyway.

---

## Breaking vs. Non-Breaking Changes

### Non-Breaking (Backward Compatible)

Clients built against the old API continue to work without changes:

- Adding a new optional field to a response body
- Adding a new optional request field
- Adding a new endpoint
- Adding a new optional query parameter
- Adding a new HTTP method to an existing resource
- Relaxing validation (making a formerly required field optional)
- Adding enum values to a response field (caution: clients that switch on enum may break)

### Breaking Changes

Existing clients break without modification:

- Removing or renaming a field in a request or response
- Changing a field's type (e.g., `string` → `integer`)
- Making an optional field required
- Removing an endpoint
- Changing URL structure
- Changing status code semantics
- Adding a new required field to a request body
- Changing authentication scheme

### Subtle Breaking Changes (Often Missed)

- Adding new enum values to a request field (if the server now rejects unknown enum values)
- Tightening validation (a formerly accepted value now fails)
- Changing the order of operations in a transactional endpoint
- Changing the error response schema (clients may parse error bodies)
- Increasing response latency beyond SLA (not a schema change, but a contract break)

---

## Versioning Strategies

### 1. URI Path Versioning

```
/v1/users
/v2/users
/v3/users
```

**Examples:** Stripe (`/v1/`), GitHub REST API (`/v3/`), Twilio, most public APIs.

**Advantages:**

- Immediately visible in logs, URLs, browser address bar
- Easy to route in proxies/gateways based on URL prefix
- Clear intent — developers know exactly which version they're calling
- Simple to test with curl or browser
- No special headers required
- Can serve different versions from different backends

**Disadvantages:**

- URL "changes" the resource identity (REST purists object — `https://api.example.com/users/123` and `https://api.example.com/v2/users/123` refer to the same logical resource)
- Old version URLs persist in bookmarks, documentation, codebases forever
- Must decide on versioning granularity (service-level? resource-level?)

**Consensus:** URI versioning is the dominant approach for public APIs precisely because it is simple, explicit, and requires zero knowledge of HTTP headers. Stripe, Twilio, GitHub, and Shopify all use it. The REST-purity objection is a theoretical concern that does not affect real-world API usability.

### 2. Request Header Versioning

```
GET /users/123
Api-Version: 2024-01-01
```

**Examples:** Stripe (uses this for behavior sub-versioning within `/v1/`), Cloudflare.

**Advantages:**

- Clean URLs that don't change between versions
- Version-specific routing possible in gateways
- Can carry date-based version strings (more expressive than integers)

**Disadvantages:**

- Not browser-friendly (must use API client to set custom headers)
- Requires the `Vary: Api-Version` response header for correct HTTP caching behavior
- Less discoverable — consumers must read docs to know the header exists
- Some proxies strip unknown headers

**Stripe's hybrid approach (notable):** Stripe uses URI versioning (`/v1/`) for the major API version, which never changes. Within `/v1/`, they use date-based header versioning (`Stripe-Version: 2024-06-20`) for behavioral changes. This gives clean URLs for routing while allowing granular evolution.

### 3. Content Negotiation (Accept Header)

```
GET /users/123
Accept: application/vnd.example.v2+json
```

**RFC-compliant** but rarely used in practice.

**Advantages:**

- Formally "correct" by HTTP content negotiation semantics
- Version is part of the media type, not the URL

**Disadvantages:**

- Extremely developer-unfriendly (verbose, not testable in browsers)
- Caching requires `Vary: Accept`
- Essentially no major public API uses this approach
- Documentation complexity is high

**Verdict:** Do not use for public APIs. This is an academic preference with no practical adoption.

### 4. Query Parameter Versioning

```
GET /users/123?version=2
GET /users/123?api-version=2024-01-01
```

**Examples:** Azure REST APIs use `?api-version=2024-01-01`.

**Advantages:**

- Easy to add to existing URLs
- Testable in browser
- Explicit in logs

**Disadvantages:**

- Pollutes query string space
- Easy to forget (no default behavior is clear)
- Caching behavior: CDNs may cache `/users/123` and `/users/123?version=2` as different entries — good for correctness but not for cache efficiency

**Verdict:** Acceptable for internal/enterprise APIs, especially in Microsoft Azure ecosystems. Not the first choice for consumer-facing public APIs.

---

## Date-Based vs. Integer-Based Versioning

| Approach | Example | Notes |
|----------|---------|-------|
| Integers | v1, v2, v3 | Simple; no information about timing |
| Dates | 2024-01-15, 2024-06-01 | Communicates when changes happened; Stripe, Cloudflare |
| Semver | v1.2.3 | Overengineered for APIs; semver conveys patch-level detail that API consumers rarely care about |

**Stripe's date-based approach:** Each developer's account is pinned to a specific API version date. New accounts get the latest version. Old accounts retain their pinned version unless they explicitly upgrade. The Stripe Dashboard shows when you last upgraded your version. This is the most sophisticated public approach and has influenced other API providers.

---

## API Evolution Without Versioning

Some APIs succeed by committing to strict backward compatibility:

**Amazon Web Services:** The AWS API for many services has been stable for over a decade. They add new action names and parameters but never remove or change existing ones. The result: code from 2012 still works against the 2024 API. Cost: accumulated technical debt in API shape, awkward parameter names from early decisions.

**Facebook/Meta Graph API:** Versioned, but maintains old versions for extended periods (~2 years).

**The additive-only contract:**

- Never remove fields from responses
- Never change field types
- Never make optional fields required
- New features add new optional fields/endpoints only

This works if you can commit to it. Most teams cannot — they accumulate design debt until they need a breaking change, at which point they version anyway.

---

## Deprecation Lifecycle

### Sunset Header (RFC 8594)

```
HTTP/1.1 200 OK
Sunset: Sun, 31 Dec 2024 23:59:59 GMT
Deprecation: Thu, 01 Jun 2023 00:00:00 GMT
Link: <https://api.example.com/v2/users>; rel="successor-version",
      <https://docs.example.com/migration/v1-to-v2>; rel="deprecation"
```

**`Deprecation` header:** When the version/feature was deprecated (when the clock started ticking).
**`Sunset` header:** When it will be removed (the deadline).
**`Link` header:** Points to the replacement and migration documentation.

These headers are machine-readable — monitoring tools can alert teams when they're calling deprecated endpoints. API gateway integrations can add these headers automatically based on routing configuration.

### Deprecation Timeline Best Practices

| API type | Minimum notice | Typical notice |
|----------|---------------|----------------|
| Public API, many consumers | 12 months | 18–24 months |
| Internal API, controlled consumers | 3 months | 6 months |
| Webhook event type | 6 months | 12 months |
| A specific field (not endpoint) | 6 months | 12 months |

**What to do at sunset:**

1. Return `410 Gone` with a helpful body pointing to the migration guide
2. Do not silently redirect (this defeats the purpose)
3. Retain the 410 response for 6+ months so latecomers understand what happened

**Monitoring during deprecation:** Track usage of deprecated endpoints. Don't remove a version that still has significant traffic. Some teams set sunset dates based on "90 days after all known callers have migrated" rather than fixed calendar dates.

---

## Consumer-Driven Contract Testing

Contract testing moves API compatibility verification from integration environments to unit test time.

### Pact

Pact is the leading framework for consumer-driven contract testing. The flow:

**1. Consumer writes a test:**

```javascript
// consumer/user-service.test.js
const { Pact } = require('@pact-foundation/pact');

describe('User Service', () => {
  const provider = new Pact({ consumer: 'OrderService', provider: 'UserService' });
  
  before(() => provider.setup());
  after(() => provider.finalize());

  it('returns a user by ID', async () => {
    await provider.addInteraction({
      state: 'user u-123 exists',
      uponReceiving: 'a GET request for user u-123',
      withRequest: { method: 'GET', path: '/users/u-123' },
      willRespondWith: {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          id: 'u-123',
          email: Matchers.string('alice@example.com'),
          name: Matchers.string('Alice'),
        },
      },
    });
    
    const user = await userServiceClient.getUser('u-123');
    expect(user.email).toBeDefined();
    
    await provider.verify();
    // Generates: consumer/pacts/OrderService-UserService.json
  });
});
```

**2. Pact file published to Pact Broker:**

```bash
pact-broker publish ./pacts --broker-base-url https://pacts.example.com --consumer-app-version $COMMIT_SHA
```

**3. Provider verifies:**

```javascript
// provider/user-service.pact.test.js
const { Verifier } = require('@pact-foundation/pact');

describe('Pact Verification', () => {
  it('validates pacts', async () => {
    await new Verifier({
      provider: 'UserService',
      providerBaseUrl: 'http://localhost:8080',
      pactBrokerUrl: 'https://pacts.example.com',
      consumerVersionSelectors: [{ mainBranch: true }, { deployed: true }],
      providerVersion: process.env.COMMIT_SHA,
      stateHandlers: {
        'user u-123 exists': async () => {
          await db.users.create({ id: 'u-123', email: 'alice@example.com', name: 'Alice' });
        },
      },
    }).verifyProvider();
  });
});
```

**4. `can-i-deploy` gate in CI:**

```bash
pact-broker can-i-deploy \
  --pacticipant UserService \
  --version $COMMIT_SHA \
  --to-environment production
```

This command queries the Pact Broker to determine whether all consumers that use this provider version are compatible. If a consumer depends on a field that this version removed, the check fails.

### Bi-Directional Contract Testing (PactFlow)

PactFlow's bi-directional approach uses OpenAPI specs on the provider side:

1. Provider uploads their OpenAPI spec to PactFlow
2. Consumer uploads their Pact file (generated from consumer tests)
3. PactFlow checks that every consumer interaction is a valid subset of the provider's OpenAPI spec
4. No provider-side test infrastructure required — the spec IS the verification

This is more accessible than traditional Pact for teams with well-maintained OpenAPI specs.

---

## Breaking Change Detection Tools

### oasdiff

Go-based tool that compares two OpenAPI specs and reports breaking changes:

```bash
# Compare local spec against main branch
oasdiff breaking openapi-main.yaml openapi-feature.yaml

# Output:
# error   GET /users/{id} response 200 schema property 'role' removed
# warning GET /users/{id} response 200 schema property 'preferences' added with required=true

# In CI:
oasdiff breaking --fail-on ERR origin/main.yaml HEAD.yaml
```

**Severity levels:**

- `error`: Definitively breaking
- `warning`: Likely breaking (evaluate context)

### openapi-diff

Java-based tool with HTML/Markdown output. More verbose than oasdiff, useful for generating human-readable comparison reports.

### buf (for Protobuf)

```bash
buf breaking --against '.git#branch=main'
# Reports: FIELD_SAME_TYPE, FIELD_NO_DELETE, MESSAGE_NO_DELETE, etc.
```

---

## Versioning in Microservices

In a microservices environment, every service exposes an API. Versioning strategy must be decided at the platform level:

**Service-level vs. resource-level versioning:**

- Service-level: `/orders/v2/...` — entire service gets a new version
- Resource-level: `/v2/orders` but `/v1/products` — different resources at different versions

Service-level is simpler to reason about and deploy. Resource-level allows granular evolution but creates complex version matrices.

**GraphQL versioning:** GraphQL officially avoids versioning through careful schema evolution. New fields added; old fields deprecated with `@deprecated` directive. When a field is removed (which must be declared breaking), the convention is to wait until usage is zero (trackable via query analytics or field-level tracing). This works well within a GraphQL ecosystem but does not translate to REST.

**gRPC versioning:** Protobuf's backward-compatible evolution rules handle most cases. Breaking Protobuf changes are rare in well-maintained services; buf enforces this in CI.

---

## When Not to Version

If you control all API consumers (internal services, owned frontends), aggressive versioning may be unnecessary overhead. Instead:

- Expand-contract pattern: add the new field, migrate all callers, remove the old field — all in coordinated deploys
- Feature flags: use flags to deploy new behavior to specific callers before full rollout
- Server-sent versioning: embed a schema version in responses; clients handle both old and new schemas until all are migrated

---

## Key References

- [RFC 8594: The Sunset HTTP Header Field](https://datatracker.ietf.org/doc/html/rfc8594)
- [Stripe API Versioning](https://stripe.com/blog/api-versioning)
- [Stripe Date-Based Versioning — Brandur](https://brandur.org/api-upgrades)
- [Pact Documentation](https://docs.pact.io/)
- [PactFlow Bi-Directional Contract Testing](https://pactflow.io/bi-directional-contract-testing/)
- [oasdiff — OpenAPI Breaking Change Detector](https://github.com/tufin/oasdiff)
- [buf Breaking Change Detection](https://buf.build/docs/breaking/overview)
- [Stripe API Deprecation Policy](https://stripe.com/docs/upgrades)
- [Microsoft REST API Versioning Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md#versioning)
- [Zalando API Versioning](https://opensource.zalando.com/restful-api-guidelines/#compatibility)

# API Design Principles

## Summary

API design is the practice of shaping the contract between a server and its consumers before — or in parallel with — implementation. Good design reduces client bugs, cuts support load, enables evolution, and determines whether an API is adopted or avoided. This file covers the core decisions that define an API's shape: URL design, HTTP semantics, pagination, filtering, error design, idempotency, and the design-first vs. code-first question.

---

## Design-First vs. Code-First

### The Actual Trade-Off

**Design-first:** Write the API specification (OpenAPI, etc.) before writing implementation code. The spec is the source of truth; code is generated or validated against it.

**Code-first:** Write server implementation; generate specification from code annotations (FastAPI decorators, Spring `@ApiOperation`, NestJS `@ApiProperty`).

| Criterion | Design-First | Code-First |
|-----------|-------------|------------|
| Team alignment before code | Excellent | Poor |
| Spec quality | High (spec is primary artifact) | Varies (annotations can be incomplete) |
| Iteration speed | Slower initially | Faster initially |
| API consistency across teams | Enforceable via linting | Harder to enforce |
| Mocking (parallel development) | Immediate (spec → mock) | Blocked on implementation |
| Generated spec accuracy | Perfect (spec IS the contract) | Often missing details |
| Required tooling investment | High | Low |

**The practitioner consensus (2024–2025):** Design-first produces better APIs, but its benefits only materialize if the team has the discipline to keep the spec as the source of truth and to lint/validate it in CI. In practice, many teams declare "design-first" but drift into code-first as pressure mounts, resulting in outdated specs. If you cannot commit to keeping the spec synchronized, code-first with high-quality annotation is more honest.

**Hybrid approach used by Stripe:** The API is spec'd in an internal DSL/TypeSpec-like system; the spec drives SDK generation, documentation, and server-side validation. The spec is the deployment artifact, not documentation generated after the fact.

---

## Resource Modeling

### Nouns vs. Verbs

REST resource design centers on modeling entities as nouns, not actions. The HTTP method expresses the action.

**Wrong:**

```
POST /getUser
POST /createOrder
POST /cancelSubscription
```

**Right:**

```
GET    /users/{id}
POST   /orders
DELETE /subscriptions/{id}
```

**When verbs are acceptable:** Some operations don't map cleanly to CRUD on a resource. Action-based endpoints are legitimate for:

- State transitions: `POST /orders/{id}/ship` (shipping an order is an action, not a CRUD operation on the order resource)
- Bulk operations: `POST /orders/batch-cancel`
- Commands with complex inputs: `POST /documents/{id}/translate`

The key principle: even action endpoints should be noun-like in their resource path and use POST for non-idempotent actions or PUT for idempotent ones.

### URL Conventions

```
# Resource collections — always plural
GET /users
GET /products

# Single resource — ID in path segment
GET /users/{id}

# Sub-resources — max 2 levels of nesting
GET /users/{id}/orders
GET /users/{id}/orders/{orderId}

# Avoid deep nesting — use query params for filtering instead:
# Bad:  GET /users/{id}/orders/{orderId}/items/{itemId}/reviews
# Good: GET /reviews?itemId={itemId}
```

**Nesting depth limit:** Two levels (`/resources/{id}/sub-resources`) is the practical maximum. Deeper nesting signals a modeling problem — the nested resource should either be a top-level resource or the relationship should be expressed via query parameters.

**Query strings:**

```
# Filtering
GET /orders?status=pending&customerId=c-123

# Sorting (convention: field name, prefix - for descending)
GET /orders?sort=-createdAt,status

# Sparse fieldsets
GET /users?fields=id,email,name

# Pagination
GET /orders?cursor=eyJpZCI6MTIzfQ&limit=20
```

**No file extensions in paths:** `/users/123` not `/users/123.json`. Content type belongs in `Accept` header.

**Case convention:** `kebab-case` for multi-word path segments (`/payment-methods`), `camelCase` for JSON property names (matching JavaScript conventions), `snake_case` acceptable for consistency with backend language conventions (Python/Ruby). Choose one and enforce it globally.

---

## HTTP Verbs: Correct Semantics

### Safety and Idempotency Matrix

| Method | Safe | Idempotent | Request Body | Response Body |
|--------|------|------------|--------------|---------------|
| GET | Yes | Yes | No (discouraged) | Yes |
| HEAD | Yes | Yes | No | No (headers only) |
| OPTIONS | Yes | Yes | No | Yes |
| POST | No | No | Yes | Yes |
| PUT | No | Yes | Yes | Yes |
| PATCH | No | No* | Yes | Yes |
| DELETE | No | Yes | Optional | Optional |

*PATCH is not inherently idempotent — it depends on the patch document semantics. JSON Merge Patch (RFC 7396) is idempotent for most cases; JSON Patch (RFC 6902) `add` operations may not be.

**Safe:** Produces no server-side state changes. May be cached.  
**Idempotent:** Multiple identical requests produce the same result as a single request. Important for retry logic.

### Common Misuses

**PUT vs. PATCH:**

```
# PUT — replace the entire resource (idempotent full replacement)
PUT /users/123
{ "name": "Alice", "email": "alice@example.com", "role": "admin" }
# Omitting 'role' would clear it to null — that's the semantics of PUT

# PATCH — partial update (only specified fields change)
PATCH /users/123
{ "name": "Alice Updated" }
# Only 'name' changes; other fields remain
```

If your API uses PUT to mean "partial update," it's wrong. Clients that send `PUT /users/123 { "name": "Alice" }` expecting only the name to change will silently corrupt other fields.

**POST for creation vs. action:**

```
# Creating a resource — POST to collection
POST /orders
{ "customerId": "c-123", "items": [...] }

# Triggering an action — POST to action sub-resource
POST /orders/o-456/cancel
{ "reason": "Customer requested" }
```

**DELETE with a body:** Technically valid per HTTP spec but widely unsupported by proxies, clients, and frameworks. Avoid. Use a POST action endpoint if you need to delete with a body (`POST /items/bulk-delete { "ids": [...] }`).

---

## Status Codes: Correct Usage

Common misuse patterns with correct alternatives:

| Incorrect | Correct | When to Use Correct |
|-----------|---------|---------------------|
| `200` with `{ "error": "..." }` | `4xx` / `5xx` | Never use 200 for errors |
| `200` for resource created | `201 Created` | POST that creates a resource |
| `200` for async acceptance | `202 Accepted` | Long-running async operations |
| `400` for validation failure | `422 Unprocessable Entity` | Request is valid JSON but fails business validation |
| `400` for conflict | `409 Conflict` | Unique constraint violation, state conflict |
| `500` for all errors | `503 Service Unavailable` | Downstream dependency unavailable |

**The 400 vs. 422 distinction:**

- `400 Bad Request`: Malformed request syntax (invalid JSON, missing required headers), or fundamentally invalid input (wrong data type for a field).
- `422 Unprocessable Entity`: Request is syntactically valid but semantically invalid (email field has valid string format but is already registered; date range where start > end).

In practice, many APIs use 400 for both — this is common enough to not be a hard rule, but 422 carries more precise semantic meaning and is preferred in design-first APIs.

---

## Pagination

### Offset Pagination

```
GET /orders?offset=100&limit=20
```

```sql
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 100;
```

**Performance characteristics:** O(N) degradation. At `OFFSET 10000`, PostgreSQL/MySQL must count and skip 10,000 rows before returning results. A 17x slowdown between page 1 and page 500 is observed in real-world benchmarks (see Milan Jovanovic's analysis).

**Additional problem:** Insertion/deletion during pagination causes records to shift. A new order inserted between page 1 and page 2 requests causes one record to appear twice (once as the "last" record of page 1 and once as the "first" of page 2), or a record to be skipped.

**When offset is acceptable:**

- Small, rarely-changing datasets (<10k rows)
- Admin interfaces where users navigate to a specific page number
- Reports and exports where data is static during pagination

### Cursor/Keyset Pagination

```
# First page
GET /orders?limit=20

# Response includes cursor
{
  "data": [...],
  "pagination": {
    "hasNext": true,
    "cursor": "eyJpZCI6MTIzLCJjcmVhdGVkQXQiOiIyMDI0LTAxLTE1In0="
  }
}

# Next page
GET /orders?cursor=eyJpZCI6MTIzLCJjcmVhdGVkQXQiOiIyMDI0LTAxLTE1In0=&limit=20
```

```sql
-- Cursor decodes to: { "id": 123, "createdAt": "2024-01-15" }
SELECT * FROM orders 
WHERE (created_at, id) < ('2024-01-15', 123)  -- Composite keyset
ORDER BY created_at DESC, id DESC 
LIMIT 20;
```

**Performance:** O(log N) against a B-tree index. Page 1 and page 10,000 cost the same. No row-counting overhead.

**Implementation detail — composite cursor:** Use `(timestamp, id)` pairs, not just timestamps, to handle ties deterministically. Encode as opaque base64 JSON to allow server-side cursor format evolution without client changes.

**Limitation:** No random access. You cannot jump to "page 47." This eliminates cursor pagination for use cases requiring direct page navigation (admin tools, reports). For infinite scroll and feed-based UIs, this is not a limitation at all.

### GraphQL Cursor Pagination (Relay Connections)

The Relay specification defines a canonical connection type:

```graphql
query {
  orders(first: 20, after: "cursor123") {
    edges {
      cursor
      node {
        id
        status
        total
      }
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    totalCount
  }
}
```

This is the standard pattern for GraphQL APIs. The `totalCount` field is optional (expensive for large datasets — avoid if not needed).

### Page-Based Pagination

```
GET /reports?page=3&pageSize=50
```

A variant of offset where clients specify page number. Identical performance characteristics to offset pagination. Useful for UIs that display "Page 3 of 47."

---

## Filtering, Sorting, and Searching

### Filtering Conventions

Simple equality filters via query parameters:

```
GET /orders?status=pending&customerId=c-123
```

Range filters — various conventions (no universal standard):

```
# Convention 1: Suffix operators
GET /orders?createdAt[gte]=2024-01-01&createdAt[lte]=2024-12-31

# Convention 2: Colon-separated
GET /orders?filter=createdAt:gte:2024-01-01,status:eq:pending

# Convention 3: Separate params (common for dates)
GET /orders?createdAfter=2024-01-01&createdBefore=2024-12-31
```

No convention has won. Pick one and document it consistently.

### Sorting

```
# Single field
GET /orders?sort=-createdAt      # Descending (- prefix)
GET /orders?sort=status          # Ascending (no prefix)

# Multiple fields
GET /orders?sort=-createdAt,status

# Alternative common convention
GET /orders?sortBy=createdAt&sortOrder=desc
```

The `-` prefix convention (used by JSON:API spec) is compact and common. Document which convention you use.

### Full-Text Search

Avoid implementing full-text search in your database for large datasets — use dedicated search infrastructure (Elasticsearch, OpenSearch, Typesense, Algolia). Expose it via a `q` or `search` parameter:

```
GET /products?q=wireless+headphones&category=electronics
```

The `q` parameter convention comes from search engines and is broadly understood.

---

## Batch Operations

### Bulk Create Pattern

```
POST /users/batch
{
  "items": [
    { "email": "alice@example.com", "name": "Alice" },
    { "email": "bob@example.com", "name": "Bob" }
  ]
}
```

**Partial failure handling — three approaches:**

1. **All-or-nothing (transactional):** If any item fails, roll back all. Return 400/422. Simple for clients.

2. **Best-effort (non-transactional):** Process all items; return per-item success/failure. Use `207 Multi-Status`.

3. **Fail-fast:** Stop on first failure. Simplest to implement; poor UX for large batches.

**207 Multi-Status pattern (recommended for best-effort):**

```json
HTTP/1.1 207 Multi-Status
{
  "results": [
    { "status": 201, "id": "u-1", "email": "alice@example.com" },
    { "status": 422, "email": "invalid-email", "error": {
        "type": "https://api.example.com/errors/validation",
        "title": "Validation Failed",
        "detail": "'invalid-email' is not a valid email address"
      }
    }
  ]
}
```

**Document your semantics explicitly:** Clients must know whether the operation is transactional. This is a critical API contract detail that is frequently underdocumented.

---

## Long-Running Operations (202 Accepted Pattern)

When an operation takes more than a few hundred milliseconds, return immediately with `202 Accepted` and a location to poll:

```
POST /reports/generate
{ "type": "quarterly_summary", "year": 2024 }

HTTP/1.1 202 Accepted
Location: /operations/op-abc123
Retry-After: 5

{
  "operationId": "op-abc123",
  "status": "pending",
  "statusUrl": "/operations/op-abc123"
}
```

**Polling the operation:**

```
GET /operations/op-abc123

{
  "operationId": "op-abc123",
  "status": "in_progress",
  "progress": { "percent": 45, "message": "Processing month 3 of 12" },
  "createdAt": "2024-01-15T10:00:00Z",
  "estimatedCompletionAt": "2024-01-15T10:02:00Z"
}
```

**Completion:**

```
{
  "operationId": "op-abc123",
  "status": "completed",
  "result": {
    "downloadUrl": "/reports/r-xyz789",
    "expiresAt": "2024-01-22T10:02:00Z"
  }
}
```

**Alternative: Webhook callback.** Accept a `callbackUrl` in the initial request; POST the result to it when done. Reduces polling load but requires the client to be reachable. Combine with polling as a fallback.

**The Lro (Long-Running Operation) pattern** from Microsoft Azure codifies this in OpenAPI with `x-ms-long-running-operation` extensions and an `Azure-AsyncOperation` response header pointing to the status endpoint.

---

## Idempotency Keys

Idempotency keys prevent duplicate operations when clients retry after network failures. Critical for any state-changing operation (payments, order creation, user registration).

### Implementation Pattern (based on Stripe's approach)

**Client:** Generate a unique key (UUID v4) per logical operation, include in header:

```
POST /charges
Idempotency-Key: 4d3eee9e-ca56-4ab2-8d01-6e8d1c7a0521
{ "amount": 2000, "currency": "usd", "source": "card_123" }
```

**Server algorithm:**

1. Extract `Idempotency-Key` header
2. Look up key in idempotency store (Redis, database)
3. If not found: acquire a lock on the key, execute the operation, store `(key, response, fingerprint)`, release lock, return response
4. If found and completed: return cached response (same status code + body)
5. If found and in-progress: return `409 Conflict` (another request is already processing)
6. If found with different request fingerprint (same key, different body): return `422 Unprocessable Entity` — key collision

**Storage considerations (Brandur's implementation guide):**

```sql
CREATE TABLE idempotency_keys (
  key VARCHAR(255) PRIMARY KEY,
  locked_at TIMESTAMP,
  locked_by VARCHAR(255),    -- server instance ID
  request_fingerprint VARCHAR(255),  -- hash of method + path + body
  response_status INTEGER,
  response_body JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
-- TTL: expire keys after 24 hours (Stripe's approach) or 30 days (Stripe v2 approach)
```

**Key scope (Stripe v2):** Keys are scoped to `(account + API endpoint)` — the same key can be reused across different endpoints without collision. This allows clients to use a single transaction ID across multiple API calls that are logically related.

**IETF Idempotency-Key header RFC (draft):** There's an active IETF draft for standardizing `Idempotency-Key` semantics. Stripe's implementation largely follows it; adoption is increasing.

---

## Content Negotiation

HTTP content negotiation allows clients and servers to negotiate the format of the response body.

```
# Client requests JSON
GET /orders/123
Accept: application/json

# Client requests JSON with embedded links (HAL)
GET /orders/123
Accept: application/hal+json

# Client requests problem details in JSON
GET /orders/999
Accept: application/problem+json
```

**Practical use:**

- Most APIs serve only `application/json` — content negotiation is irrelevant
- `application/problem+json` (RFC 9457) is worth supporting for error responses
- `application/x-ndjson` (newline-delimited JSON) for streaming large datasets
- Vendor media types (`application/vnd.example.v2+json`) — one way to do header-based versioning

**`Content-Type` must always be set on request bodies.** Missing `Content-Type` on a POST request is a common client error; APIs should return `415 Unsupported Media Type` if content type is missing or wrong.

---

## Postel's Law at API Boundaries

Jon Postel's robustness principle: "Be conservative in what you send, be liberal in what you accept."

**For API design, this is contested:**

**Arguments for applying it:**

- Reduces friction for early API consumers
- Allows graceful evolution (ignore unknown fields rather than error)
- Improves tolerance for minor protocol variations

**Arguments against (the modern position):**

- Strict validation at the boundary catches bugs earlier (fail fast)
- Accepting malformed input creates implicit contracts that are hard to break
- Security: "being liberal in what you accept" has caused multiple injection vulnerabilities

**Current consensus:** Be strict at trust boundaries (input validation), but ignore unknown JSON fields in responses (forward compatibility). Explicitly validate: required fields, types, formats, ranges. Do not silently coerce: a number provided as a string ("123" vs 123) should be rejected, not silently converted.

---

## API Contracts and Forward Compatibility

**Additive changes are non-breaking (generally):**

- Adding a new optional field to a response
- Adding a new endpoint
- Adding a new optional query parameter
- Adding a new optional request body field

**Breaking changes:**

- Removing or renaming a field
- Changing a field's type
- Adding a new required field to a request
- Changing status codes for existing scenarios
- Changing URL structure

**Rule for clients:** Ignore unknown fields in responses. This is the fundamental rule that allows servers to add fields without breaking existing clients. JSON parsers that throw on unknown keys create extremely brittle clients.

**Rule for servers:** Never remove or rename fields without versioning. The field may be used by a client you didn't know about.

---

## Field Selection (Sparse Fieldsets)

Allows clients to request only specific fields, reducing payload size and database query overhead:

```
GET /users/123?fields=id,email,name
```

```json
{ "id": "u-123", "email": "alice@example.com", "name": "Alice" }
```

**JSON:API standardizes this as `fields[type]=field1,field2`:**

```
GET /users/123?fields[users]=id,email,name
```

**Implementation concern:** Field selection can break caching if not properly normalized (different orderings of the same fields result in different cache keys). Normalize field lists before cache key generation.

---

## Key References

- [Roy Fielding on HATEOAS and REST misuse (2008)](https://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven)
- [Stripe's API Design Guide](https://stripe.com/blog/payment-api-design)
- [Designing Robust and Predictable APIs with Idempotency — Stripe Blog](https://stripe.com/blog/idempotency)
- [Implementing Stripe-like Idempotency Keys in Postgres — Brandur](https://brandur.org/idempotency-keys)
- [Understanding Cursor Pagination — Milan Jovanovic](https://www.milanjovanovic.tech/blog/understanding-cursor-pagination-and-why-its-so-fast-deep-dive)
- [PostgreSQL Keyset Pagination vs Offset — Stacksync](https://www.stacksync.com/blog/keyset-cursors-postgres-pagination-fast-accurate-scalable)
- [RFC 7231: HTTP/1.1 Semantics and Content](https://datatracker.ietf.org/doc/html/rfc7231)
- [RFC 5789: PATCH Method for HTTP](https://datatracker.ietf.org/doc/html/rfc5789)
- [RFC 7396: JSON Merge Patch](https://datatracker.ietf.org/doc/html/rfc7396)
- [JSON:API Specification](https://jsonapi.org/)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)
- [Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/)

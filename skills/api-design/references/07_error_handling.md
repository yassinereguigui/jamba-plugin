# Error Handling

## Summary

Error handling is one of the most neglected aspects of API design and one of the most impactful for developer experience. A well-designed error response tells the consumer exactly what went wrong, why, and what to do about it — in both machine-readable and human-readable form. This file covers HTTP status code semantics, RFC 9457 (Problem Details), error response design, gRPC and GraphQL error patterns, and client-side guidance.

---

## HTTP Status Codes: Correct Usage

### The Common Misuses

**200 with an error body:**

```json
// WRONG — don't do this
HTTP/1.1 200 OK
{ "success": false, "error": "User not found" }
```

This pattern breaks HTTP caching, monitoring, and alerting. All downstream systems (CDNs, load balancers, API gateways, observability tools) interpret 2xx as success. You lose metric clarity and make client error handling harder.

**Generic 400 for everything:**

```
400 → "Bad request" (for validation, business logic, conflicts, missing auth... everything)
```

This is common but suboptimal. 4xx codes carry semantic meaning.

### The Status Code Reference

**2xx — Success:**

| Code | Name | Use |
|------|------|-----|
| 200 | OK | GET, PUT, PATCH, DELETE success with body |
| 201 | Created | POST created a resource; include `Location` header |
| 202 | Accepted | Request accepted for async processing |
| 204 | No Content | DELETE, PUT success with no body |
| 207 | Multi-Status | Partial success (batch operations) |

**3xx — Redirection:**

| Code | Name | Use |
|------|------|-----|
| 301 | Moved Permanently | Permanent URL change (update bookmarks) |
| 302 | Found | Temporary redirect |
| 304 | Not Modified | `If-None-Match` / `If-Modified-Since` cache hit |
| 308 | Permanent Redirect | Like 301 but preserves HTTP method |

**4xx — Client Errors:**

| Code | Name | Use |
|------|------|-----|
| 400 | Bad Request | Malformed syntax, invalid JSON, missing required headers |
| 401 | Unauthorized | Authentication required or failed (misnomer — it means "unauthenticated") |
| 403 | Forbidden | Authenticated but not authorized for this resource |
| 404 | Not Found | Resource doesn't exist (or intentionally hidden for security) |
| 405 | Method Not Allowed | HTTP method not supported; include `Allow` header |
| 409 | Conflict | State conflict (unique constraint violation, version conflict) |
| 410 | Gone | Resource permanently deleted (vs. 404 which may be transient) |
| 415 | Unsupported Media Type | `Content-Type` not supported |
| 422 | Unprocessable Entity | Valid syntax but semantic validation failure |
| 429 | Too Many Requests | Rate limit exceeded; include `Retry-After` header |

**5xx — Server Errors:**

| Code | Name | Use |
|------|------|-----|
| 500 | Internal Server Error | Unexpected server failure |
| 501 | Not Implemented | Method/feature not yet implemented |
| 502 | Bad Gateway | Upstream service returned invalid response |
| 503 | Service Unavailable | Server overloaded or maintenance; include `Retry-After` |
| 504 | Gateway Timeout | Upstream service timed out |

### The 401 vs. 403 Distinction

This confuses many engineers:

- **401 Unauthorized:** The request lacks valid authentication credentials. Response should include `WWW-Authenticate` header indicating what auth scheme to use. Send this when the user is not logged in or their token is expired/invalid.
- **403 Forbidden:** Authentication succeeded; the authenticated identity lacks permission for this resource. Do not return `WWW-Authenticate`.

A common security pattern: return 404 instead of 403 to avoid leaking resource existence to unauthorized users. "You don't have access to this document" reveals that the document exists; "not found" does not.

---

## RFC 9457: Problem Details for HTTP APIs

RFC 9457 (July 2023, superseding RFC 7807) defines a standard JSON structure for API error responses. The media type is `application/problem+json`.

### Structure

```json
{
  "type": "https://api.example.com/problems/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 400,
  "detail": "Your account balance of $10.00 is insufficient for this $50.00 transaction.",
  "instance": "/transactions/tx-abc123",
  
  // Extension members (non-standard, application-specific)
  "account": "acct-456",
  "balance": 10.00,
  "required": 50.00,
  "correlationId": "req-7f8a3b2c"
}
```

**Field semantics:**

- **`type`** (URI): Identifies the problem type. Should resolve to human-readable documentation. Stable across instances.
- **`title`** (string): Human-readable summary of the problem type. Same for all instances of this type; do not include specific values.
- **`status`** (integer): HTTP status code for this problem. Should match the response status code.
- **`detail`** (string): Human-readable explanation specific to this instance. May include specific values.
- **`instance`** (URI): URI identifying this specific occurrence. May be a URL to a log entry, a ticket, or just the request path.

### Changes from RFC 7807

1. **Problem type registry:** IANA and SmartBear maintain registries of common problem type URIs. If your error matches a common type (`about:blank`, authentication failures), use the registered URI.
2. **`about:blank`:** Use as the `type` URI when the HTTP status code alone is sufficient — no additional semantics needed. Title should then be the standard HTTP status phrase.
3. **Clarified extension member handling:** Extension members must not duplicate standard members.

### Implementation Patterns

**Express.js:**

```typescript
class ProblemDetailsError extends Error {
  type: string;
  title: string;
  status: number;
  detail?: string;
  extensions?: Record<string, unknown>;

  constructor(params: {
    type: string;
    title: string;
    status: number;
    detail?: string;
    extensions?: Record<string, unknown>;
  }) {
    super(params.title);
    Object.assign(this, params);
  }
}

// Middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof ProblemDetailsError) {
    return res.status(err.status)
      .set('Content-Type', 'application/problem+json')
      .json({
        type: err.type,
        title: err.title,
        status: err.status,
        detail: err.detail,
        instance: req.path,
        ...err.extensions,
      });
  }
  
  // Unknown errors — don't leak stack traces
  console.error(err); // Log internally with full context
  res.status(500)
    .set('Content-Type', 'application/problem+json')
    .json({
      type: 'about:blank',
      title: 'Internal Server Error',
      status: 500,
      instance: req.path,
      correlationId: req.headers['x-correlation-id'],
    });
});
```

**Throwing in handlers:**

```typescript
// Business logic throws typed errors
throw new ProblemDetailsError({
  type: 'https://api.example.com/problems/duplicate-email',
  title: 'Email Already Registered',
  status: 409,
  detail: `The email address ${email} is already associated with an account.`,
  extensions: { email },
});
```

**Validation errors (multiple field errors):**

```json
{
  "type": "https://api.example.com/problems/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The request body contains validation errors.",
  "instance": "/users",
  "errors": [
    { "field": "email", "code": "invalid_format", "message": "'notanemail' is not a valid email address" },
    { "field": "age", "code": "out_of_range", "message": "Age must be between 0 and 150; received -5" }
  ]
}
```

### The `type` URI and Documentation

The `type` URI should resolve to human-readable documentation. This makes errors self-documenting:

```
GET https://api.example.com/problems/insufficient-funds

<html>
<h1>Insufficient Funds</h1>
<p>This error occurs when you attempt a transaction that exceeds your available balance.</p>
<h2>How to resolve</h2>
<p>Add funds to your account at /account/deposit before retrying the transaction.</p>
</html>
```

Some organizations serve these from a `problems/` path in their documentation site. This is best practice — the error format links directly to fix documentation.

---

## Error Response Design Principles

### Machine-Readable Error Codes

Beyond HTTP status codes, include a stable `code` field that clients can switch on:

```json
{
  "type": "https://api.example.com/problems/rate-limit-exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "code": "RATE_LIMIT_EXCEEDED",      // Stable enum value
  "detail": "You have exceeded 100 requests per minute. Your limit resets in 45 seconds.",
  "retryAfter": 45,
  "limit": 100,
  "remaining": 0,
  "resetAt": "2024-01-15T10:01:00Z"
}
```

The `code` field enables client-side switch statements without string-matching `detail` messages (which may change). `detail` messages are for humans; `code` values are for machines.

### Correlation IDs

Every response (success and error) should include a correlation ID traceable through your logging system:

```
HTTP/1.1 500 Internal Server Error
X-Correlation-ID: req-7f8a3b2c-...

{
  "type": "about:blank",
  "title": "Internal Server Error",
  "status": 500,
  "correlationId": "req-7f8a3b2c-..."
}
```

The correlation ID should be:

- Generated at the API gateway or service entry point
- Propagated to all downstream service calls (via headers)
- Included in all log entries for the request
- Returned to the client so they can reference it in support requests

### What Not to Include in Error Responses

**Stack traces:** Expose internal implementation details and may reveal exploitable information.

```json
// WRONG
{
  "error": "NullPointerException at com.example.UserRepository.findById(UserRepository.java:45)\n\tat..."
}
```

**Database error messages:** Reveal table/column names, query structure.

```json
// WRONG
{
  "error": "duplicate key value violates unique constraint \"users_email_key\""
}
```

**Internal service names/IPs:** Reveal internal architecture.
**PII in error details:** Don't echo back email addresses in authentication errors (prevents enumeration).

---

## Retry-After and Exponential Backoff

When returning 429 (Too Many Requests) or 503 (Service Unavailable), include guidance on when to retry:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1735689600
```

`Retry-After` accepts either a number of seconds or an HTTP date:

```
Retry-After: 120
Retry-After: Thu, 01 Jan 2026 00:00:00 GMT
```

**API documentation should specify backoff behavior:**

```
On 429 responses:
- Read the Retry-After header
- If absent, wait 60 seconds
- Apply jitter: actual_wait = retry_after + random(0, 10)

On 5xx responses:
- Retry with exponential backoff: 1s, 2s, 4s, 8s, 16s
- Maximum 5 retries
- Apply jitter: ±20% of the wait time
- Do not retry 4xx errors (they are client errors, retrying won't help)
```

---

## gRPC Status Codes and REST Mapping

gRPC uses a distinct set of status codes that require mapping when exposing gRPC services via REST (gRPC-Gateway):

| gRPC Status | HTTP Mapping | Description |
|-------------|-------------|-------------|
| OK | 200 | Success |
| CANCELLED | 499 | Client cancelled (Nginx convention) |
| UNKNOWN | 500 | Unknown error |
| INVALID_ARGUMENT | 400 | Bad request |
| DEADLINE_EXCEEDED | 504 | Gateway timeout |
| NOT_FOUND | 404 | Not found |
| ALREADY_EXISTS | 409 | Conflict |
| PERMISSION_DENIED | 403 | Forbidden |
| RESOURCE_EXHAUSTED | 429 | Rate limited |
| FAILED_PRECONDITION | 400 | Business logic precondition failed |
| ABORTED | 409 | Aborted (optimistic lock failure) |
| UNAUTHENTICATED | 401 | Authentication failed |
| UNAVAILABLE | 503 | Service unavailable |
| UNIMPLEMENTED | 501 | Not implemented |

gRPC status messages carry a `Status` message in the trailer:

```protobuf
// ErrorInfo provides rich error details
import "google/rpc/error_details.proto";

// Usage in server code
return Status(StatusCode::INVALID_ARGUMENT, "Invalid email format")
  .set_details(BadRequest()
    .add_field_violations()
    .set_field("email")
    .set_description("'notanemail' is not a valid email address"));
```

---

## GraphQL Error Patterns

GraphQL has two distinct error patterns:

### Top-Level Errors

Request-level errors that prevent execution:

```json
{
  "errors": [
    {
      "message": "Cannot query field 'nonexistent' on type 'User'.",
      "locations": [{ "line": 3, "column": 5 }],
      "extensions": {
        "code": "GRAPHQL_VALIDATION_FAILED"
      }
    }
  ]
}
```

### Partial Success (Inline Errors)

The defining feature of GraphQL error handling — operations can partially succeed:

```json
{
  "data": {
    "user": {
      "id": "u-123",
      "name": "Alice",
      "paymentMethods": null   // Failed
    }
  },
  "errors": [
    {
      "message": "Not authorized to view payment methods",
      "path": ["user", "paymentMethods"],
      "extensions": {
        "code": "UNAUTHORIZED",
        "http": { "status": 403 }
      }
    }
  ]
}
```

This partial success behavior is simultaneously GraphQL's power (clients get what they can) and its operational challenge (200 OK doesn't mean success — you must check `errors`).

**Union types for typed errors (preferred pattern):**

Instead of relying on the `errors` array, encode error cases in the schema:

```graphql
union CreateUserResult = User | EmailAlreadyExistsError | ValidationError

type EmailAlreadyExistsError {
  message: String!
  email: String!
  suggestedAction: String!
}

type ValidationError {
  message: String!
  fields: [FieldError!]!
}

type Mutation {
  createUser(input: CreateUserInput!): CreateUserResult!
}
```

This makes error handling explicit in the type system rather than hidden in the `errors` array. The client must handle the union:

```graphql
mutation CreateUser($input: CreateUserInput!) {
  createUser(input: $input) {
    ... on User { id email }
    ... on EmailAlreadyExistsError { message email }
    ... on ValidationError { message fields { field message } }
  }
}
```

This pattern (popularized by Shopify's GraphQL API) is considered best practice for mutations.

---

## Error Propagation in Microservices

When Service A calls Service B, and Service B returns an error, Service A must decide:

**1. Translate the error** (most common):

```python
try:
    user = user_service.get_user(user_id)
except UserService.NotFoundError:
    raise ResourceNotFoundError(f"User {user_id} not found")
except UserService.ServiceUnavailableError:
    raise DependencyError("User service temporarily unavailable")
```

Clients of Service A should not see Service B's internal error format.

**2. Propagate correlation IDs** (always do this):

```python
headers = {
    'X-Correlation-ID': request.correlation_id,
    'X-Request-ID': generate_new_request_id(),  # New for this sub-request
}
```

**3. Handle circuit breaker states:**
When a downstream service is repeatedly failing, a circuit breaker opens and fails fast without calling the service:

```python
# With resilience4j-style circuit breaker
@circuit_breaker(failure_threshold=5, timeout=10)
def call_inventory_service(product_id: str) -> InventoryResponse:
    return inventory_client.get_stock(product_id)
```

On circuit open: return 503 with `Retry-After`, log the circuit state, and propagate a meaningful error to the client.

---

## Key References

- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html)
- [Problem Details RFC 9457 — Swagger/SmartBear Guide](https://swagger.io/blog/problem-details-rfc9457-doing-api-errors-well/)
- [RFC 7231: HTTP Status Codes](https://datatracker.ietf.org/doc/html/rfc7231)
- [gRPC Status Codes](https://grpc.github.io/grpc/core/md_doc_statuscodes.html)
- [Google Cloud APIs: Error Model](https://cloud.google.com/apis/design/errors)
- [Stripe Error Handling](https://stripe.com/docs/api/errors)
- [GraphQL Errors Specification](https://spec.graphql.org/June2018/#sec-Errors)
- [Shopify GraphQL Union Error Pattern](https://shopify.dev/docs/api/usage/errors)
- [Microsoft REST API Error Responses](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md#handling-errors)

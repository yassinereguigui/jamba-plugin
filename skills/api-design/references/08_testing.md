# API Testing

## Summary

API testing covers a wide spectrum: from unit tests of request handlers to distributed load tests. The discipline has matured significantly: property-based testing against API specs (Schemathesis), consumer-driven contract testing (Pact), and chaos engineering are now practical for most teams. The key insight is that different test types verify different properties — no single approach replaces the others.

---

## Testing Scope and Layers

```
                        ↑ Cost / Confidence / Scope
Chaos Engineering       │ ●
E2E API Tests           │ ●●
Load / Performance      │ ●●●
Contract Tests          │ ●●●●
Integration Tests       │ ●●●●●
Schema Validation Tests │ ●●●●●●
Unit Tests (handlers)   │ ●●●●●●●
                        └──────────────────────────
                          ↑ Speed / Isolation / Volume
```

**Testing philosophy:** Test behavior at the lowest layer that gives meaningful confidence. Unit testing HTTP handler internals rarely adds value — test the API surface (integration tests) against the documented contract.

---

## Unit Testing API Handlers

Unit tests for API handlers are appropriate when the handler contains non-trivial logic that doesn't require a full HTTP stack:

```typescript
// Test business logic, not framework plumbing
describe('calculateOrderTotal', () => {
  it('applies discount when customer tier is premium', () => {
    const order = createOrder({ 
      items: [{ price: 100, quantity: 2 }],
      customer: { tier: 'premium' }
    });
    expect(calculateOrderTotal(order)).toBe(180); // 10% discount
  });

  it('does not apply discount for standard tier', () => {
    const order = createOrder({ 
      items: [{ price: 100, quantity: 2 }],
      customer: { tier: 'standard' }
    });
    expect(calculateOrderTotal(order)).toBe(200);
  });
});
```

**What not to unit test:** HTTP method routing, authentication middleware, request/response serialization — these are framework concerns, tested more effectively via integration tests.

---

## Integration Testing: Testing the HTTP Surface

Test the API as a black box via HTTP. Tests should:
- Make real HTTP requests to the running application (or a test instance)
- Validate response status codes, headers, and body schema
- Cover the happy path and documented error cases
- Be independent of implementation details

```typescript
// Using supertest (Node.js) — tests the actual HTTP surface
import request from 'supertest';
import { app } from '../app';
import { db } from '../db';

describe('GET /orders/:id', () => {
  beforeEach(async () => {
    await db.orders.deleteMany({});
  });

  it('returns the order when it exists and belongs to the authenticated user', async () => {
    const order = await db.orders.create({
      data: { customerId: 'user-alice', status: 'pending', total: 150 }
    });
    
    const response = await request(app)
      .get(`/orders/${order.id}`)
      .set('Authorization', `Bearer ${aliceToken}`)
      .expect(200)
      .expect('Content-Type', /application\/json/);
    
    expect(response.body).toMatchObject({
      id: order.id,
      status: 'pending',
      total: 150,
    });
    // Verify no sensitive fields leaked
    expect(response.body).not.toHaveProperty('internalNotes');
  });

  it('returns 404 for a non-existent order', async () => {
    const response = await request(app)
      .get('/orders/non-existent-id')
      .set('Authorization', `Bearer ${aliceToken}`)
      .expect(404);
    
    expect(response.body.type).toContain('not-found');
    expect(response.body.status).toBe(404);
  });

  it('returns 403 when order belongs to a different user', async () => {
    const order = await db.orders.create({
      data: { customerId: 'user-bob', status: 'pending', total: 100 }
    });
    
    await request(app)
      .get(`/orders/${order.id}`)
      .set('Authorization', `Bearer ${aliceToken}`)
      .expect(403); // Not 404 — alice knows she's authenticated
  });
});
```

**Database isolation:** Run against a real test database, not mocks. Mocked database behavior diverges from production in subtle ways (constraint handling, transaction semantics, type coercions). Use a separate test database schema, a containerized database (Docker), or a test-specific database reset strategy.

---

## Schema Validation Testing: Schemathesis

Schemathesis performs property-based testing against OpenAPI or GraphQL schemas. It generates test cases automatically, targeting edge cases that manual tests miss.

```bash
# Run against a live server
schemathesis run http://localhost:8000/openapi.json \
  --checks all \
  --auth "Authorization: Bearer test-token" \
  --hypothesis-max-examples=200 \
  --target response_time

# Run against a schema file (with test server)
schemathesis run openapi.yaml \
  --base-url http://localhost:8000 \
  --stateful=links  # Follow OpenAPI links for stateful tests
```

**What Schemathesis checks by default:**
- `not_a_server_error` — no endpoint returns 5xx
- `response_schema_conformance` — responses conform to the documented schema
- `response_headers_conformance` — headers match spec
- `content_type_conformance` — Content-Type header is correct

**What it generates:**
- Minimum values, maximum values, empty strings, null values
- Very long strings, Unicode edge cases
- Malformed but plausible values
- Numbers at integer boundaries

```yaml
# .github/workflows/schemathesis.yml
- name: API Schema Testing
  run: |
    schemathesis run ${{ secrets.API_URL }}/openapi.json \
      --checks all \
      --report=schemathesis-report.xml \
      --junit-xml=junit.xml
  
- name: Upload Results
  uses: actions/upload-artifact@v3
  with:
    name: schemathesis-results
    path: junit.xml
```

---

## Contract Testing with Pact

See `04_versioning.md` for detailed Pact flow. Key patterns for CI:

### Pact Broker Integration

```yaml
# CI pipeline — consumer side
- name: Run Consumer Tests
  run: npm test -- --testPathPattern="pact"
  
- name: Publish Pacts
  run: |
    pact-broker publish ./pacts \
      --broker-base-url $PACT_BROKER_URL \
      --broker-token $PACT_TOKEN \
      --consumer-app-version $GITHUB_SHA \
      --branch $GITHUB_REF_NAME

# CI pipeline — provider side (triggers on publish or push)
- name: Verify Provider
  run: npm run test:pact:provider
  env:
    PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
    PACT_TOKEN: ${{ secrets.PACT_TOKEN }}
    
- name: Can I Deploy?
  run: |
    pact-broker can-i-deploy \
      --pacticipant $SERVICE_NAME \
      --version $GITHUB_SHA \
      --to-environment production
```

### Consumer Test Structure

```javascript
// consumer/orders-client.pact.test.js
describe('OrdersClient', () => {
  const provider = new PactV3({
    consumer: 'FrontendApp',
    provider: 'OrdersService',
  });

  describe('getOrder', () => {
    it('returns an order when it exists', async () => {
      await provider
        .given('order o-123 exists for user alice')
        .uponReceiving('a GET request for order o-123')
        .withRequest({ method: 'GET', path: '/orders/o-123' })
        .willRespondWith({
          status: 200,
          headers: { 'Content-Type': 'application/json' },
          body: {
            id: 'o-123',
            status: MatchersV3.string('pending'),
            total: MatchersV3.number(150.00),
            // Note: only fields the CONSUMER actually uses
          },
        })
        .executeTest(async (mockServer) => {
          const client = new OrdersClient(mockServer.url);
          const order = await client.getOrder('o-123');
          expect(order.status).toBe('pending');
        });
    });
  });
});
```

**Key principle:** Consumer pact tests should only specify the fields the consumer *actually uses*. If the consumer uses only `id` and `status`, don't assert on `total`, `items`, or other fields. This makes pacts less brittle and gives providers freedom to add fields.

---

## Performance and Load Testing: k6

### k6 Basics

k6 (Grafana) is the current leading API load testing tool. Tests are JavaScript; execution is Go (very efficient).

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const orderCreationDuration = new Trend('order_creation_duration');

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up
    { duration: '5m', target: 100 },   // Steady state
    { duration: '2m', target: 200 },   // Spike
    { duration: '5m', target: 200 },   // Sustained spike
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests < 500ms
    http_req_failed: ['rate<0.01'],    // Error rate < 1%
    errors: ['rate<0.05'],             // Custom error metric
    order_creation_duration: ['p(99)<2000'],
  },
};

export default function () {
  const params = {
    headers: {
      'Authorization': `Bearer ${__ENV.API_TOKEN}`,
      'Content-Type': 'application/json',
    },
  };

  // List orders
  const listRes = http.get(`${__ENV.BASE_URL}/orders`, params);
  check(listRes, {
    'list orders 200': (r) => r.status === 200,
    'list has items': (r) => JSON.parse(r.body).data.length > 0,
  });
  errorRate.add(listRes.status !== 200);

  // Create order
  const start = new Date();
  const createRes = http.post(
    `${__ENV.BASE_URL}/orders`,
    JSON.stringify({
      items: [{ productId: 'prod-001', quantity: 1 }],
    }),
    params
  );
  orderCreationDuration.add(new Date() - start);
  
  check(createRes, {
    'create order 201': (r) => r.status === 201,
  });
  errorRate.add(createRes.status !== 201);

  sleep(1);
}
```

### k6 Test Types

| Type | Config | Purpose |
|------|--------|---------|
| Smoke test | 1-5 VUs, 1 min | Quick sanity check in CI |
| Load test | Expected peak VUs, 20-60 min | Validate normal operation |
| Stress test | 2-3x expected peak | Find breaking point |
| Soak test | Sustained load, hours/days | Find memory leaks, DB degradation |
| Spike test | 0 → 10x → 0 instantly | Validate auto-scaling behavior |

**k6 in CI (smoke test pattern):**
```yaml
- name: API Smoke Test
  run: |
    k6 run \
      --vus 10 \
      --duration 60s \
      --env BASE_URL=${{ secrets.STAGING_URL }} \
      --env API_TOKEN=${{ secrets.STAGING_TOKEN }} \
      tests/smoke.js
```

### k6 vs. Gatling vs. Locust vs. Artillery

| Tool | Language | Strengths | Weaknesses |
|------|----------|-----------|------------|
| k6 | JavaScript | Modern, cloud-native, great DX, Grafana integration | Paid cloud features |
| Gatling | Scala/Java | Excellent reports, Akka actors (efficient) | Scala learning curve |
| Locust | Python | Pythonic, distributed, programmable | Python GIL limits single-node capacity |
| Artillery | YAML/JS | YAML-first, easy to learn | Less control than k6 for complex scenarios |

**k6 is the current community favorite** for new projects. Gatling is preferred in Java/enterprise environments. Locust is common in Python shops.

---

## Security Testing

### OWASP ZAP API Scan

Automated DAST (Dynamic Application Security Testing) against your API:

```yaml
# GitHub Actions integration
- name: ZAP API Scan
  uses: zaproxy/action-api-scan@v0.9.0
  with:
    target: 'https://staging-api.example.com/openapi.json'
    format: openapi
    rules_file_name: .zap/rules.tsv  # Custom rule weights
    cmd_options: '-a'  # All active scan rules
```

ZAP generates HTML/XML reports. Integrate the XML report with your CI system for build gates.

### Nuclei API Templates

Nuclei (ProjectDiscovery) runs curated vulnerability templates against APIs:

```yaml
# nuclei-api-template.yaml
id: jwt-none-algorithm
info:
  name: JWT None Algorithm Accepted
  severity: high
requests:
  - method: GET
    path: ["{{BaseURL}}/protected-endpoint"]
    headers:
      Authorization: "Bearer eyJhbGciOiJub25lIn0.eyJzdWIiOiJhZG1pbiJ9."
    matchers:
      - type: status
        status: [200]  # Should be 401, not 200
```

---

## Mocking Tools for Development and Testing

### Prism (Stoplight)

Generates a mock server from an OpenAPI spec:

```bash
prism mock openapi.yaml
# Listening at http://localhost:4010

# Call the mock
curl http://localhost:4010/users/123 -H "Accept: application/json"
# Returns response matching the spec's example or generated from schema
```

**Prism validation proxy mode:** Sits in front of your real server and validates requests and responses against the spec:
```bash
prism proxy openapi.yaml http://localhost:8000
# Forwards to real server but validates both request and response
```

### Mockoon

Desktop GUI tool for creating mock APIs without code. Useful for frontend developers who need a mock API before the backend is built:
- Define routes, methods, response bodies, status codes
- Support for templating (dynamic responses)
- Import OpenAPI specs

### WireMock

Java-based HTTP mock server. Excellent for integration testing where you need to mock downstream services:

```java
// Java / JVM ecosystem
wireMockServer.stubFor(
  get(urlEqualTo("/users/123"))
    .willReturn(aResponse()
      .withStatus(200)
      .withHeader("Content-Type", "application/json")
      .withBody("{\"id\": \"123\", \"name\": \"Alice\"}")
    )
);
```

WireMock supports recording (capture real responses for playback) and fault injection (simulate timeouts, malformed responses).

---

## Test Data Management

A persistent challenge in API testing: tests need realistic, consistent, isolated data.

**Strategies:**

**1. Factory pattern:**
```typescript
function createTestOrder(overrides = {}) {
  return {
    id: generateId(),
    customerId: 'test-customer-123',
    status: 'pending',
    items: [{ productId: 'test-product-001', quantity: 1, price: 100 }],
    total: 100,
    createdAt: new Date().toISOString(),
    ...overrides,
  };
}
```

**2. Database seeding:**
```typescript
// Before each test suite
beforeAll(async () => {
  await db.reset(); // Drop and recreate test data
  await seed(db);   // Insert reference data (products, categories)
});
```

**3. Test database per CI job:** Each CI run gets an isolated database. Works well with containerized databases (postgres:15 container per CI job).

**4. Snapshot testing for responses:**
```typescript
it('returns the order response in the expected format', async () => {
  const response = await request(app).get('/orders/fixture-order-123');
  expect(response.body).toMatchSnapshot();
});
```

Snapshots catch unexpected response shape changes. Update snapshots intentionally when the format changes.

---

## Chaos Engineering for APIs

Chaos engineering tests system resilience by deliberately injecting faults:

**Tools:**
- **Chaos Monkey (Netflix):** Randomly terminates instances
- **Chaos Mesh:** Kubernetes-native chaos engineering (pod failure, network delay, HTTP fault injection)
- **Gremlin:** Commercial platform for controlled chaos experiments

**API-specific chaos scenarios:**
- Downstream service returns 500 (tests circuit breaker activation)
- Downstream service returns correct response after 5s delay (tests timeout behavior)
- Database connection pool exhausted (tests queue saturation)
- Third-party API returns malformed JSON (tests response validation)

**Example: HTTP fault injection with Chaos Mesh:**
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: orders-service-latency
spec:
  mode: all
  selector:
    namespaces: [production]
    labelSelectors:
      app: orders-service
  target: Response
  port: 8080
  path: /orders*
  delay: "2s"       # Add 2 second delay to all order responses
  duration: "10m"
```

The test: observe that users of the orders service (the order details page, the checkout flow) degrade gracefully — showing loading states, using cached data, or serving a reduced experience — rather than cascading to a full outage.

---

## Key References

- [Schemathesis Documentation](https://schemathesis.readthedocs.io/)
- [k6 API Load Testing Guide — Grafana](https://k6.io/docs/testing-guides/api-load-testing/)
- [Pact Documentation](https://docs.pact.io/)
- [PactFlow Bi-Directional Contract Testing](https://pactflow.io/bi-directional-contract-testing/)
- [Prism — Stoplight](https://stoplight.io/open-source/prism)
- [WireMock Documentation](https://wiremock.org/docs/)
- [Mockoon](https://mockoon.com/)
- [OWASP ZAP API Scan GitHub Action](https://github.com/zaproxy/action-api-scan)
- [Chaos Mesh](https://chaos-mesh.org/docs/)
- [Artillery Load Testing](https://www.artillery.io/docs)
- [Gatling Documentation](https://gatling.io/docs/gatling/)

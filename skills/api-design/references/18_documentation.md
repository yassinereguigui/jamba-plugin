# API Documentation

## Summary

API documentation is a product. Its quality directly determines adoption — developers who can't understand how to use an API don't use it. Documentation has two components that require different approaches: reference documentation (what does each endpoint accept and return?) and conceptual documentation (how does this API work?). This file covers rendering tools, docs-as-code practices, code sample management, and documentation testing.

---

## Reference Documentation: Rendering OpenAPI

### The Major Renderers

| Tool | Model | Strengths | Weaknesses |
|------|-------|-----------|------------|
| Swagger UI | Open source | Universal recognition, "Try It" | Dated design, limited customization |
| Redoc | Open source | Beautiful, responsive, well-organized | "Try It" requires ReDoc Cloud (paid) |
| Scalar | Open source | Modern design, excellent DX, "Try It" | Newer, smaller ecosystem |
| Stoplight Elements | Open source component | Embeddable in any docs site | Requires Stoplight for full features |

**Scalar** has emerged as the leading open-source option in 2024–2025. It generates clean, modern documentation with a built-in "Try It" console, support for multiple authentication methods, and excellent response rendering.

```html
<!-- Scalar in an HTML page — zero build step -->
<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
<script>
  Scalar.createApiReference('#app', {
    url: '/openapi.json',
    theme: 'default',
    showSidebar: true,
    searchHotKey: 'k',
  });
</script>
<div id="app"></div>
```

**Redoc** remains the choice for APIs that prioritize documentation readability over interactive testing:

```yaml
# redocly.yaml
theme:
  logo:
    url: 'https://example.com/logo.svg'
  colors:
    primary:
      main: '#0070f3'
apis:
  main:
    root: ./openapi.yaml
```

### What Makes Reference Documentation Actually Good

Beyond rendering: the source OpenAPI spec quality determines documentation quality.

**Required for every operation:**

```yaml
paths:
  /orders/{id}:
    get:
      operationId: getOrder          # Required: enables SDK generation, deep links
      summary: Retrieve an order     # One line: what does this do?
      description: |
        Returns complete order details including status, line items, shipping information,
        and payment summary.
        
        Note: Cancelled orders are returned with status "cancelled" and include the
        cancellation reason and timestamp.
      tags: [Orders]                 # Required: grouping in sidebar
```

**Required for every parameter:**

```yaml
parameters:
  - name: id
    in: path
    required: true
    description: |
      The order's unique identifier. Use the ID returned when creating the order,
      or list orders to find IDs.
    schema:
      type: string
      format: uuid
      example: "123e4567-e89b-12d3-a456-426614174000"
```

**Required for every response:**

```yaml
responses:
  '200':
    description: Order found and returned successfully
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/Order'
        examples:
          pendingOrder:
            summary: A pending order with two items
            value:
              id: "o-123"
              status: "pending"
              total: 150.00
              items:
                - productId: "p-001"
                  quantity: 2
                  price: 75.00
```

Multiple named examples (not just `example`) are the most underused OpenAPI feature for documentation quality. They let documentation show different scenarios in the "Try It" console.

---

## AsyncAPI Documentation

### AsyncAPI Studio

The official web-based editor and documentation previewer for AsyncAPI specs:

```text
https://studio.asyncapi.com/?url=https://my-api.com/asyncapi.yaml
```

Renders channels, operations, messages, servers, and bindings in a human-readable format.

### EventCatalog

EventCatalog is an open-source documentation tool specifically for event-driven systems. Unlike AsyncAPI Studio, it's a full documentation site generator:

```bash
npx @eventcatalog/create-eventcatalog@latest my-event-catalog
cd my-event-catalog
npm run dev
```

EventCatalog supports:

- Visualizing event flows as dependency graphs
- Documenting which services own which events
- Versioned event schemas with diff comparison
- Markdown-based conceptual documentation alongside spec

---

## Docs-as-Code

Documentation stored in version control, reviewed via PRs, deployed via CI/CD.

**Benefits:**

- Docs change with code (same PR)
- Review process for documentation quality
- Documentation history via git log
- Same deployment pipeline as code

**Structure:**

```text
docs/
├── openapi.yaml              # API spec (docs source of truth)
├── guides/                   # Conceptual documentation
│   ├── getting-started.md
│   ├── authentication.md
│   └── webhooks.md
├── tutorials/
│   ├── process-a-payment.md
│   └── handle-subscriptions.md
├── changelogs/
│   └── 2024.md
└── mkdocs.yml               # Documentation site config
```

**Documentation site generators:**

- **MkDocs + Material:** Python-based, excellent for API docs, great search
- **Docusaurus:** React-based, used by Meta projects, excellent for large doc sites
- **Mintlify:** Commercial, specifically for API docs, used by OpenAI, Anthropic
- **ReadMe:** Commercial docs platform with analytics on documentation engagement

---

## Conceptual Documentation: Guides and Tutorials

Reference documentation answers "what?" Conceptual documentation answers "how?" and "why?".

### Documentation Types Hierarchy

```text
1. Tutorials (learning-oriented)
   "Send your first message in 5 minutes"
   → Goal: newcomer gets a win quickly
   
2. How-to Guides (task-oriented)
   "How to handle webhook retries"
   → Goal: experienced user accomplishes a specific task

3. Reference (information-oriented)
   "POST /messages endpoint reference"
   → Goal: lookup while building

4. Explanation (understanding-oriented)
   "How webhook delivery and retries work"
   → Goal: conceptual understanding
```

(Diátaxis Framework — Daniele Procida)

**The most common documentation mistake:** Writing explanation when developers need a tutorial, or writing a tutorial when they need reference. These serve different needs at different moments.

### Writing Good Conceptual Documentation

**Good:**

```markdown
## Handling Webhooks

Webhooks allow your application to receive real-time notifications when events occur
in your account. Instead of polling the API, we call your endpoint.

### Setting up a webhook endpoint

Your webhook endpoint must:
- Accept POST requests
- Return HTTP 200 within 30 seconds
- Verify the request signature (see below)

### Verifying signature

We sign every webhook with HMAC-SHA256 using your webhook secret. Always verify
signatures to ensure requests came from us:

```python
import hmac
import hashlib

def verify_signature(payload: str, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature.replace('v1=', ''))
```

**Bad:**

```markdown
## Webhooks

Webhooks are HTTP callbacks that are sent when events occur. They are useful for 
receiving notifications. The webhook endpoint should be configured to receive 
POST requests. The signature should be verified.
```

The difference: specific, actionable, with code. Not vague definitions.

---

## Code Samples

Code samples are the most valuable documentation artifact and the most often broken.

### Language Coverage

Support the languages your developers actually use. Track analytics on SDK downloads and documentation language tab preferences. Minimum coverage for most developer APIs:

- JavaScript/TypeScript
- Python
- Java or Kotlin
- Go
- Ruby (if applicable)
- cURL (always, for quick testing)

### Code Sample Quality Standards

**Every code sample must:**

1. Run without modification (copy-paste executable)
2. Use realistic, recognizable data (not `fooBarBaz`)
3. Show error handling (not just the happy path)
4. Be idiomatic in the target language

**Bad example (common in auto-generated docs):**

```javascript
const result = await apiClient.ordersCreate({
  customerId: 'string',  // Wrong: not a string literal
  items: [Object],       // Wrong: not useful
});
```

**Good example:**

```javascript
import { Client } from '@example/api-client';

const client = new Client({ apiKey: process.env.EXAMPLE_API_KEY });

const order = await client.orders.create({
  customerId: 'cus_1234567890',
  items: [
    { productId: 'prod_abc123', quantity: 2 },
    { productId: 'prod_def456', quantity: 1 },
  ],
  idempotencyKey: crypto.randomUUID(),
});

console.log(`Order created: ${order.id}`);
```

### Testing Code Samples

Code samples rot. Languages evolve, SDK versions change, API behavior changes. Automated testing:

```yaml
# pytest-based documentation testing
# docs/test_examples.py
import subprocess

def test_create_order_example():
    result = subprocess.run(
        ['python', 'docs/examples/python/create_order.py'],
        env={**os.environ, 'EXAMPLE_API_KEY': TEST_API_KEY},
        capture_output=True,
        timeout=30,
    )
    assert result.returncode == 0
    assert 'Order created' in result.stdout.decode()
```

Run code sample tests in CI against the sandbox environment. This catches broken examples before they reach production documentation.

---

## Documentation Testing

**Link checking (dead links):**

```yaml
# GitHub Action for link checking
- name: Check Links
  uses: lycheeverse/lychee-action@v1
  with:
    args: --verbose --no-progress './docs/**/*.md'
    fail: true
```

**OpenAPI spec validation:**

```bash
# Validate spec syntax and style
spectral lint openapi.yaml
redocly lint openapi.yaml
```

**Example request validation:**

```bash
# Schemathesis validates that documented examples are valid per schema
schemathesis run openapi.yaml \
  --base-url http://localhost:8000 \
  --validate-schema true
```

---

## Internal API Documentation

Internal APIs have different documentation needs:

- **Audience:** Engineers who can read code; they don't need hand-holding
- **Key concerns:** Why does this API exist? What are the operational characteristics? How does it fail?
- **Architecture Decision Records (ADRs):** More valuable than tutorials for internal APIs
- **Service runbooks:** What to do when this service is degraded?

**Internal API doc template:**

```markdown
# Orders Service API

## Purpose
Manages order lifecycle: creation, payment, fulfillment, cancellation.

## Owners
Team: Commerce Platform (@commerce-platform in Slack)
On-call: PagerDuty escalation policy: Commerce-Primary

## Dependencies
- Upstream: Customer Service (getCustomer), Payment Service (chargeCard)
- Downstream: Shipping Service (createShipment), Notification Service (sendEmail)

## SLOs
- Availability: 99.9% (monthly, excludes maintenance windows)
- Latency: p95 < 200ms for reads, p95 < 500ms for writes

## Data model
[Link to database schema in GitHub]

## Operational notes
- Heavy read workload; enable Redis caching before 9am on weekdays (traffic spike)
- Payment charge timeout is 30s; if Payment Service is slow, orders will queue
```

---

## Key References

- [Scalar API Reference](https://scalar.com/)
- [Redoc Documentation](https://redocly.com/docs/redoc/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [AsyncAPI Studio](https://studio.asyncapi.com/)
- [EventCatalog](https://eventcatalog.dev/)
- [Diátaxis Framework — Daniele Procida](https://diataxis.fr/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Mintlify](https://mintlify.com/)
- [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)
- [Docusaurus](https://docusaurus.io/)
- [Good Docs Project](https://www.thegooddocsproject.dev/)

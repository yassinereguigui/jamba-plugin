# API Specifications and Description Languages

## Summary

API specifications are machine-readable contracts that describe API structure, inputs, outputs, and behaviors. The ecosystem is richer — and more fragmented — than most engineers realize. OpenAPI dominates synchronous REST APIs; AsyncAPI covers event-driven systems; TypeSpec (Microsoft) and Smithy (AWS) approach the problem from a higher abstraction level. Understanding which tool to use, and its current version's trade-offs, is foundational to API tooling pipelines.

---

## OpenAPI Specification

### Version History

| Version | Key Event |
|---------|-----------|
| Swagger 1.x | Original Wordnik spec (2011) |
| Swagger 2.0 | Industry consolidation (2014) |
| OpenAPI 3.0.x | Renamed; major restructure (2017–2021) |
| OpenAPI 3.1.0 | JSON Schema alignment (2021) |
| OpenAPI 3.2.0 | Streaming, hierarchical tags, QUERY method (September 2025) |

### OpenAPI 3.1 vs 3.0: The Critical Differences

#### 1. Full JSON Schema 2020-12 Alignment

OpenAPI 3.0 used a modified subset of JSON Schema Draft 4/5 with custom extensions (`nullable`, modified `exclusiveMinimum`/`exclusiveMaximum`). This created a frustrating divergence: valid JSON Schema was not necessarily valid OpenAPI Schema.

OpenAPI 3.1 fixed this completely. Any valid JSON Schema 2020-12 document is now a valid OpenAPI 3.1 schema component.

**Breaking impact: `nullable` removed**

OpenAPI 3.0:
```yaml
# 3.0 pattern — custom extension
properties:
  middleName:
    type: string
    nullable: true
```

OpenAPI 3.1:
```yaml
# 3.1 pattern — standard JSON Schema union type
properties:
  middleName:
    type: [string, "null"]
# or equivalently:
  middleName:
    oneOf:
      - type: string
      - type: "null"
```

This is the most common migration pain point. Automated migration tools exist (`openapi-format`, `apimatic-transformer`) but manual review is advisable.

#### 2. Webhook Support

OpenAPI 3.1 introduces the `webhooks` keyword at the document level — a peer to `paths`. This allows documenting the shape of events your API sends to consumer-defined endpoints.

```yaml
openapi: 3.1.0
info:
  title: Order API
  version: 1.0.0
webhooks:
  orderShipped:
    post:
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/OrderShippedEvent'
      responses:
        '200':
          description: Webhook received
paths:
  /orders:
    post:
      # ... normal path operation
```

This does not replace AsyncAPI for complex event-driven systems but covers the common "webhook registration" pattern that previously required out-of-band documentation.

#### 3. New JSON Schema Keywords Available

| Keyword | Use Case |
|---------|----------|
| `if/then/else` | Conditional validation based on data shape |
| `patternProperties` | Validate properties matching a pattern |
| `$anchor` | Named reference points within schemas |
| `contentMediaType` / `contentEncoding` | Describe encoded content (e.g., base64) |
| `unevaluatedProperties` | Strict object validation closing open extension |
| `prefixItems` | Typed tuple validation |

#### 4. Licensing Field

```yaml
info:
  license:
    name: Apache 2.0
    identifier: Apache-2.0   # SPDX identifier — new in 3.1
```

#### 5. `$ref` Alongside Sibling Properties

OpenAPI 3.0 did not allow properties alongside `$ref`. OpenAPI 3.1 (following JSON Schema) allows:
```yaml
schema:
  $ref: '#/components/schemas/BaseUser'
  description: "User performing the action"
  example:
    id: "u-123"
    name: "Alice"
```

### OpenAPI 3.2: What Changed (September 2025)

OpenAPI 3.2.0 is a non-breaking upgrade from 3.1 (no removal of existing features).

**Hierarchical Tags**
```yaml
tags:
  - name: orders
    description: Order management
  - name: orders/shipping
    description: Shipping operations
    parent: orders
```
Enables documentation rendering with collapsible tag hierarchies. Previously required vendor extensions.

**First-Class Streaming Support**
```yaml
responses:
  '200':
    content:
      text/event-stream:
        schema:
          type: object
          x-stream:
            itemSchema:
              $ref: '#/components/schemas/StreamChunk'
```
Native description of SSE and streaming responses without hacks.

**QUERY Method**
A new HTTP method concept: `QUERY` (from the IETF HTTP Working Group draft). A semantically safe, idempotent method that accepts a request body — the long-sought "GET with body" solution.
```yaml
paths:
  /products/search:
    query:   # new method
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductFilter'
```

**OAuth 2.0 Device Authorization Flow**
```yaml
securitySchemes:
  deviceOAuth:
    type: oauth2
    flows:
      deviceAuthorization:
        deviceAuthorizationUrl: https://auth.example.com/device
        tokenUrl: https://auth.example.com/token
```

### OpenAPI Document Structure Reference

```yaml
openapi: 3.1.0
info:
  title: API Title
  version: 1.0.0
  contact:
    name: API Support
    email: api@example.com
  license:
    name: MIT
    identifier: MIT

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://sandbox.api.example.com/v1
    description: Sandbox

security:
  - bearerAuth: []  # Global security

paths:
  /users/{id}:
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    get:
      operationId: getUser
      summary: Get user by ID
      tags: [users]
      responses:
        '200':
          description: User found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFound'

components:
  schemas:
    User:
      type: object
      required: [id, email]
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        createdAt:
          type: string
          format: date-time

  responses:
    NotFound:
      description: Resource not found
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetails'

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## AsyncAPI 3.0

AsyncAPI describes event-driven and message-driven APIs — Kafka topics, AMQP queues, MQTT channels, WebSocket subscriptions, and more. Version 3.0 (October 2023) introduced breaking changes that resolve long-standing confusion.

### The Core Change: Channel/Operation Separation

**AsyncAPI v2 (confusing):**
```yaml
channels:
  user/created:
    subscribe:   # Does "subscribe" mean YOUR app subscribes, or others can?
      message:
        $ref: '#/components/messages/UserCreated'
```

The ambiguity: `subscribe` meant "applications can subscribe to this channel" — i.e., your app *publishes*. This consistently confused developers.

**AsyncAPI v3 (explicit):**
```yaml
channels:
  userCreated:           # Arbitrary ID, not the topic address
    address: user/created  # Actual topic address moved here
    messages:
      userCreatedMessage:
        $ref: '#/components/messages/UserCreated'

operations:
  onUserCreated:
    action: receive        # "receive" = your app consumes from this channel
    channel:
      $ref: '#/channels/userCreated'

  publishUserCreated:
    action: send           # "send" = your app produces to this channel
    channel:
      $ref: '#/channels/userCreated'
```

**Why this matters:** In v2, understanding whether the spec described producer or consumer behavior required contextual knowledge. In v3, `send` and `receive` are unambiguous from the perspective of the application being described.

### Request-Reply Pattern (New in v3)

```yaml
operations:
  sendOrder:
    action: send
    channel:
      $ref: '#/channels/orderChannel'
    reply:
      address:
        location: '$message.header#/replyTo'
      channel:
        $ref: '#/channels/orderReplyChannel'
```

### AsyncAPI v3 Document Structure

```yaml
asyncapi: 3.0.0
info:
  title: Order Events API
  version: 1.0.0

servers:
  production:
    host: kafka.example.com:9092
    protocol: kafka
    security:
      - saslScram: []

channels:
  orderPlaced:
    address: orders.placed
    messages:
      orderPlacedMessage:
        $ref: '#/components/messages/OrderPlaced'

operations:
  receiveOrderPlaced:
    action: receive
    channel:
      $ref: '#/channels/orderPlaced'
    bindings:
      kafka:
        groupId:
          type: string
          const: order-processing-service

components:
  messages:
    OrderPlaced:
      payload:
        type: object
        required: [orderId, customerId, totalAmount]
        properties:
          orderId:
            type: string
          customerId:
            type: string
          totalAmount:
            type: number
  
  securitySchemes:
    saslScram:
      type: scramSha256
```

### AsyncAPI vs. OpenAPI: When to Use Which

| Concern | OpenAPI | AsyncAPI |
|---------|---------|----------|
| REST endpoints | Yes | No |
| Webhooks (simple) | Yes (3.1+) | Overkill |
| Kafka topics | No | Yes |
| MQTT | No | Yes |
| WebSocket (message protocol) | No | Yes |
| SSE stream format | Partial (3.2) | Yes |
| gRPC | No | No (use protobuf) |

---

## TypeSpec

### What Problem TypeSpec Solves

TypeSpec (formerly TYPESPEC, earlier Cadl) is Microsoft's TypeScript-inspired API description language. Open-sourced in 2022, GA in April 2024.

**The problem:** OpenAPI YAML at scale is hard to author, review, and maintain. A single OpenAPI spec for a large API (e.g., Azure's REST APIs) becomes thousands of lines of repetitive YAML. It lacks abstraction, reuse, and code review ergonomics.

**TypeSpec's approach:** A higher-level language that *generates* OpenAPI (and other outputs). Instead of writing OpenAPI directly, you describe your API in TypeSpec and emit to OpenAPI, JSON Schema, Protobuf, or custom output.

```typespec
import "@typespec/http";
import "@typespec/rest";

using TypeSpec.Http;
using TypeSpec.Rest;

@service({ title: "Order Service" })
@server("https://api.example.com/v1", "Production")
namespace OrderService;

model Order {
  @key id: string;
  customerId: string;
  status: "pending" | "shipped" | "delivered";
  createdAt: utcDateTime;
}

@route("/orders")
interface Orders {
  @get list(): Order[];
  @get @route("/{id}") get(@path id: string): Order | NotFoundResponse;
  @post create(@body order: Omit<Order, "id" | "createdAt">): CreatedResponse<Order>;
}
```

This TypeSpec generates valid OpenAPI 3.1 YAML with proper schemas, paths, and components — roughly 10x more compact than hand-authored OpenAPI.

**Multi-target output:** The same TypeSpec can emit to:
- OpenAPI 3.0 / 3.1
- JSON Schema
- Protobuf (experimental)
- AsyncAPI (experimental)
- Custom emitters via TypeSpec's emitter API

### TypeSpec Adoption State

As of 2025, TypeSpec is:
- Used internally across all major Azure services and Microsoft Graph
- Open-source with a growing external community
- **Production-ready** for teams generating OpenAPI from it
- Emerging as an alternative to hand-authored OpenAPI for API-first teams with large surface areas

**TypeSpec vs. Smithy:**

| Criterion | TypeSpec | Smithy |
|-----------|----------|--------|
| Originator | Microsoft | AWS |
| Style | TypeScript-inspired | Custom IDL |
| Compactness | ~10% of generated OpenAPI | ~60% of generated OpenAPI |
| Ecosystem | Azure-heavy, growing | AWS-heavy |
| Maturity | GA (2024) | Mature (2019) |
| SDK generation | Via emitters | Native (Smithy builds SDKs) |

---

## Smithy

AWS's Interface Definition Language for modeling services and SDKs. Used internally at AWS for defining all service models.

```smithy
namespace com.example

service OrderService {
  version: "2024-01-01",
  operations: [GetOrder, CreateOrder]
}

operation GetOrder {
  input: GetOrderInput,
  output: Order,
  errors: [OrderNotFoundException]
}

@input
structure GetOrderInput {
  @required
  orderId: String
}

structure Order {
  @required
  orderId: String,
  @required
  status: OrderStatus
}

enum OrderStatus {
  PENDING,
  SHIPPED,
  DELIVERED
}
```

Smithy's `smithy-build.json` can emit to OpenAPI, SDK source code (multiple languages), and Smithy's own JSON representation.

**When to choose Smithy:** If you're building AWS-adjacent tooling, generating SDKs for multiple languages as a first-class concern, or working in an AWS ecosystem. Smithy's SDK generation is more mature than TypeSpec's.

---

## Protocol Buffers (Protobuf)

The serialization format and IDL used by gRPC. See `01_api_paradigms.md` for gRPC detail. Schema evolution rules summarized:

**Safe changes (backward and forward compatible):**
- Add new fields (new field numbers)
- Rename fields (field number is identity in wire format)
- Add new enum values
- Add new message types

**Unsafe changes (breaking):**
- Change a field's type
- Reuse a deleted field number
- Remove a field without `reserved`
- Change `optional` to `required`

**Best practice — always use reserved:**
```protobuf
message User {
  reserved 3, 5;             // Protect deleted field numbers
  reserved "deprecated_id";  // Protect deleted field names
  
  string id = 1;
  string email = 2;
  string displayName = 4;
}
```

**buf CLI** enforces breaking change detection:
```bash
buf breaking --against '.git#branch=main'
# Reports: FIELD_SAME_TYPE, FIELD_NO_DELETE, etc.
```

---

## JSON Schema (Draft 2020-12)

JSON Schema 2020-12 is the current stable version. Key features relevant to API design:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://api.example.com/schemas/order.json",
  "type": "object",
  "required": ["id", "status"],
  "properties": {
    "id": { "type": "string", "format": "uuid" },
    "status": {
      "enum": ["pending", "processing", "shipped", "delivered", "cancelled"]
    },
    "items": {
      "type": "array",
      "items": { "$ref": "#/$defs/LineItem" }
    },
    "discount": {
      "if": { "properties": { "status": { "const": "delivered" } } },
      "then": { "properties": { "discount": { "type": "number", "minimum": 0 } } }
    }
  },
  "$defs": {
    "LineItem": {
      "type": "object",
      "required": ["productId", "quantity"],
      "properties": {
        "productId": { "type": "string" },
        "quantity": { "type": "integer", "minimum": 1 }
      },
      "unevaluatedProperties": false
    }
  }
}
```

**`unevaluatedProperties: false`** is the strict object validation keyword — it prevents any property not defined in `properties`, `patternProperties`, or allOf/anyOf/oneOf sub-schemas. More powerful than `additionalProperties: false` because it accounts for schema composition.

### $ref and $defs

In JSON Schema 2020-12 and OpenAPI 3.1, `$defs` is the canonical location for reusable sub-schemas (replaces the informal `definitions` from earlier drafts):

```json
{
  "$defs": {
    "Address": {
      "type": "object",
      "properties": {
        "street": { "type": "string" },
        "city": { "type": "string" }
      }
    }
  },
  "properties": {
    "billingAddress": { "$ref": "#/$defs/Address" },
    "shippingAddress": { "$ref": "#/$defs/Address" }
  }
}
```

---

## API Linting: Spectral and vacuum

### Spectral

Spectral (Stoplight) is the de facto standard API linter. It validates OpenAPI, AsyncAPI, and arbitrary JSON/YAML against configurable rulesets.

**Built-in rulesets:**
- `spectral:oas` — OpenAPI best practices (30+ rules)
- `spectral:asyncapi` — AsyncAPI validation

**Custom ruleset example (`.spectral.yaml`):**
```yaml
extends:
  - spectral:oas

rules:
  require-operation-id:
    description: "All operations must have an operationId"
    severity: error
    given: "$.paths[*][get,post,put,patch,delete]"
    then:
      field: operationId
      function: truthy

  no-x-internal-paths:
    description: "x-internal operations must not appear in external specs"
    severity: warn
    given: "$.paths[*][*]"
    then:
      field: x-internal
      function: falsy

  require-error-response:
    description: "All operations must document a 4xx or 5xx response"
    severity: warn
    given: "$.paths[*][*]"
    then:
      function: schema
      functionOptions:
        schema:
          properties:
            responses:
              type: object
              patternProperties:
                "^[45]":
                  type: object
          required: [responses]
```

**CI integration:**
```bash
spectral lint openapi.yaml --ruleset .spectral.yaml --format junit > results.xml
# Non-zero exit on error-severity violations — fails the CI pipeline
```

**Custom TypeScript functions:**
```typescript
// spectral-functions/requireExamples.ts
export default (targetValue: unknown, options: unknown, context: any) => {
  if (!targetValue || typeof targetValue !== 'object') return;
  const obj = targetValue as Record<string, unknown>;
  if (!obj.example && !obj.examples) {
    return [{ message: 'Schema must have an example or examples property' }];
  }
};
```

### vacuum

vacuum is a high-performance Go-based linter, Spectral-compatible ruleset support, significantly faster for large specs (important for CI pipelines with many services):

```bash
vacuum lint -r .spectral.yaml openapi.yaml
vacuum report openapi.yaml --format html -o report.html
```

**Key difference:** vacuum is ~10–50x faster than Spectral for large specs (10k+ line OpenAPI files) because it's compiled Go vs. Node.js. For teams with many services or large specs, vacuum reduces CI lint step from seconds to milliseconds. Both support the same ruleset format.

### Redocly CLI

Redocly CLI combines linting, bundling, and documentation preview:
```bash
redocly lint openapi.yaml
redocly bundle openapi.yaml -o bundled.yaml  # Resolves all $refs into one file
redocly preview-docs openapi.yaml
```

Redocly's built-in ruleset (`@redocly/recommended`) enforces stricter documentation-quality rules (requiring summaries, descriptions, examples).

---

## GraphQL Schema Definition Language (SDL)

GraphQL's schema is defined in SDL:

```graphql
type Query {
  user(id: ID!): User
  users(filter: UserFilter, first: Int, after: String): UserConnection!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
}

type Subscription {
  orderStatusChanged(orderId: ID!): Order!
}

type User {
  id: ID!
  email: String!
  name: String!
  createdAt: DateTime!
  orders(first: Int, after: String): OrderConnection!
}

# Relay-style cursor pagination
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

input CreateUserInput {
  email: String!
  name: String!
}

scalar DateTime

directive @auth(requires: Role = USER) on FIELD_DEFINITION | OBJECT

enum Role {
  ADMIN
  USER
  GUEST
}
```

**SDL tooling:** GraphQL Code Generator generates TypeScript types, resolvers, and client hooks from SDL. This makes GraphQL specifications executable — the SDL is simultaneously the contract and the type source.

---

## RAML: Current Status

RAML (RESTful API Modeling Language) was a YAML-based OpenAPI competitor championed by MuleSoft. Current status (2025): **effectively deprecated for new projects.** MuleSoft/Salesforce still supports it for existing Anypoint Platform users, but tooling ecosystem has not grown. OpenAPI 3.1 subsumes nearly all RAML use cases. Teams on RAML should plan migration to OpenAPI.

---

## API Blueprint: Current Status

API Blueprint (Apiary/Oracle) is a Markdown-based API description format. Status (2025): **legacy/inactive.** The Apiary platform was sunset by Oracle. API Blueprint tooling (Dredd) still exists and some organizations use it but new adoption is essentially zero. Teams should migrate to OpenAPI.

---

## Specification Selection Guide

| Scenario | Recommended Spec |
|----------|-----------------|
| REST API, greenfield | OpenAPI 3.1 |
| REST API, team generates from TypeScript | tRPC (no spec needed) or OpenAPI via code-first |
| Large API surface, API-first team | TypeSpec → OpenAPI |
| AWS-native, SDK generation priority | Smithy |
| Kafka/RabbitMQ/MQTT event system | AsyncAPI 3.0 |
| gRPC service | Protobuf (.proto) |
| GraphQL API | GraphQL SDL |
| Webhooks (simple outbound) | OpenAPI 3.1 `webhooks` |
| Webhooks + full event-driven system | AsyncAPI 3.0 |

---

## Key References

- [OpenAPI 3.1.0 Specification](https://spec.openapis.org/oas/v3.1.0.html)
- [OpenAPI 3.2.0 Specification](https://spec.openapis.org/oas/v3.2.0.html)
- [Announcing OpenAPI v3.2 — OpenAPI Initiative](https://www.openapis.org/blog/2025/09/23/announcing-openapi-v3-2)
- [Upgrading from OpenAPI 3.0 to 3.1](https://learn.openapis.org/upgrading/v3.0-to-v3.1.html)
- [AsyncAPI 3.0 Release Notes](https://www.asyncapi.com/blog/release-notes-3.0.0)
- [AsyncAPI 3.0 Migration Guide](https://www.asyncapi.com/docs/migration/migrating-to-v3)
- [TypeSpec Documentation](https://typespec.io/docs)
- [TypeSpec on GitHub](https://github.com/microsoft/typespec)
- [Smithy Documentation](https://smithy.io/2.0/)
- [Spectral GitHub](https://github.com/stoplightio/spectral)
- [vacuum Linter](https://quobix.com/vacuum/)
- [JSON Schema 2020-12](https://json-schema.org/draft/2020-12)
- [buf CLI — Protobuf Breaking Change Detection](https://buf.build/docs/breaking/overview)
- [Redocly CLI](https://redocly.com/docs/cli/)

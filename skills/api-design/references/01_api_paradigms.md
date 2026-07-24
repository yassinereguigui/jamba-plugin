# API Paradigms and Styles

## Summary

API paradigms are architectural styles and protocols for communication between software systems. The industry offers REST, GraphQL, gRPC, WebSockets, SSE, tRPC, JSON-RPC, and emerging hypermedia approaches — each optimized for different constraints. No paradigm is universally best; choosing wrong costs significant rework. This file synthesizes the genuine trade-offs, real-world adoption patterns, and the gap between how each paradigm is marketed and how it performs in production.

---

## REST: What It Actually Means vs. What Industry Ships

### Roy Fielding's Original Constraints

REST (Representational State Transfer) was defined in Roy Fielding's 2000 dissertation, not as a protocol but as an architectural style for distributed hypermedia systems. The six constraints are:

1. **Client-Server** — separation of concerns between UI and data storage
2. **Stateless** — each request contains all information needed; no session state on server
3. **Cacheable** — responses must define themselves as cacheable or not
4. **Uniform Interface** — the defining feature; includes resource identification, manipulation through representations, self-descriptive messages, and HATEOAS
5. **Layered System** — client cannot tell whether it's connected to an end server or an intermediary
6. **Code on Demand** (optional) — servers can extend client functionality by transferring executable code

**What the industry ships instead:** HTTP APIs that use nouns as URL paths, JSON bodies, and four HTTP verbs. This satisfies constraints 1–3 and partially 4, ignoring HATEOAS entirely. Fielding has publicly criticized this usage, noting that what most people call "REST APIs" are not REST. The industry accepted his complaint and moved on — the term is now a shorthand for "JSON over HTTP with resource-oriented URLs."

### The Richardson Maturity Model

Leonard Richardson's model provides a practical ladder for evaluating "how RESTful" an API is:

| Level | Name | Description | Industry Prevalence |
|-------|------|-------------|---------------------|
| 0 | The Swamp of POX | Single endpoint, all operations via POST | Legacy SOAP replacements |
| 1 | Resources | Multiple URLs, one per resource | Common in poorly designed APIs |
| 2 | HTTP Verbs | Correct use of GET/POST/PUT/DELETE + status codes | **The practical industry standard** |
| 3 | Hypermedia Controls | HATEOAS; responses embed links to next actions | Rare in production; mostly theoretical |

**Consensus view:** Level 2 is the "good enough" target for nearly all public and internal APIs. It provides discoverability through documentation (not hypermedia), predictability, and excellent tooling support. Most REST API style guides (Stripe, GitHub, Twilio) effectively codify Level 2.

### What "Stateless" Actually Means in Practice

Statelessness means the server holds no client-session state between requests. Authentication tokens in headers satisfy this — the server reconstructs client context from the token each request. Database state is not "session state." Confusion here leads to incorrect REST criticism.

**Where statelessness creates genuine pain:**

- Multi-step wizards or workflows (must externalize state to client or cache)
- Streaming/real-time updates (requires SSE or WebSockets, which are stateful)
- Long-running operations (must poll or use async patterns)

---

## HATEOAS: Practical Reality

HATEOAS (Hypermedia As The Engine Of Application State) requires responses to contain links that guide clients to valid next actions. Example:

```json
{
  "id": "order-123",
  "status": "pending",
  "_links": {
    "self": { "href": "/orders/123" },
    "cancel": { "href": "/orders/123/cancel", "method": "DELETE" },
    "pay": { "href": "/payments", "method": "POST" }
  }
}
```

**Who actually implements it:** GitHub's API, PayPal's older API, Amazon Web Services (partially), HAL-using APIs in enterprise Java ecosystems.

**Why it rarely gets adopted:**

1. **No format standard:** HAL, Siren, JSON:API, JSON-LD, Ion — competing hypermedia formats with incompatible client libraries
2. **Client complexity:** Clients must traverse links rather than hardcode URLs, requiring a hypermedia-aware client library
3. **Documentation still required:** Even with HATEOAS, developers read docs to understand business context
4. **Test complexity:** Link validity must be tested alongside business logic
5. **Versioning paradox:** HATEOAS is supposed to allow server-side URL changes, but client code that constructs URLs from link templates still breaks when link structures change

**Honest assessment:** HATEOAS solves a real problem (server-side URL evolution) but the solution cost exceeds the benefit for most teams. The internet's actual REST APIs — including those from companies with world-class API design — function without it. The Richardson Level 2 + comprehensive versioning strategy is the pragmatic choice.

---

## GraphQL

### Core Mechanics

GraphQL is a query language for APIs and a server-side runtime for executing queries. Developed at Facebook (2012), open-sourced 2015. Clients specify exactly the data they need in a typed query language; the server fulfills it through resolvers.

```graphql
query {
  user(id: "u-123") {
    name
    email
    posts(last: 3) {
      title
      publishedAt
    }
  }
}
```

**Structural advantages:**

- **No over-fetching:** Client gets exactly the fields requested
- **No under-fetching:** One request can traverse the graph to get related data
- **Introspection:** Schema is queryable at runtime — enables tooling
- **Strong typing:** SDL (Schema Definition Language) enforced at query validation time

### The N+1 Problem

The most significant production hazard in GraphQL. When resolving a list of entities, each entity's sub-fields trigger individual resolver calls:

```graphql
query { posts { title author { name } } }
```

Without batching: `SELECT * FROM posts` (1 query) + `SELECT * FROM users WHERE id=?` × N (N queries). For 100 posts, this is 101 database queries.

**Solution: DataLoader** — Facebook's batching library. Collects `.load(key)` calls within a single event loop tick, deduplicates, then fires a single batch query. DataLoader is not optional in production GraphQL.

```javascript
const authorLoader = new DataLoader(async (authorIds) => {
  const authors = await db.users.findMany({ where: { id: { in: authorIds } } });
  return authorIds.map(id => authors.find(a => a.id === id));
});
```

**WunderGraph's DataLoader 3.0** (2024): A breadth-first loading algorithm that reduces concurrency complexity from O(N²) to O(1), reportedly 5x faster for deeply nested queries. Still emerging.

### Federation

GraphQL Federation allows a single GraphQL endpoint (the supergraph) to be backed by multiple services (subgraphs), each owning part of the schema. Apollo Federation 2.0 is the dominant implementation; Mercurius, Wundergraph, and Cosmo are alternatives.

**Architecture:**

```text
                    ┌──────────────┐
Client ──────────── │ Apollo Router │ ──── Users Subgraph
                    │  (Supergraph) │ ──── Products Subgraph
                    └──────────────┘ ──── Orders Subgraph
```

**Key Federation patterns:**

- **`@key` directive:** Defines primary key for an entity that can be resolved across subgraphs
- **`@external`/`@requires`:** A subgraph can extend another's type using fields from the original owner
- **Entity resolution (`__resolveReference`):** Must use DataLoader or performance degrades catastrophically

**Apollo Router vs. Apollo Gateway:** Router (Rust-based, 2022+) is 5–10x more efficient than Gateway (Node.js). All new Federation deployments should use Router.

### Persisted Queries

Instead of sending the full query document on every request, clients register queries with the server at build time and send only a hash. Benefits:

- **Security:** Servers can reject arbitrary queries (allowlist mode)
- **Performance:** Smaller payloads, HTTP GET caching becomes possible
- **Schema evolution:** Server knows exactly what queries exist in production

```http
POST /graphql HTTP/1.1
{ "extensions": { "persistedQuery": { "version": 1, "sha256Hash": "abc123..." } } }
```

### GraphQL Drawbacks at Scale

1. **Caching is hard:** REST's URL-based caching maps cleanly to HTTP/CDN caches. GraphQL's single endpoint + variable query bodies require application-level caching (Apollo Client, persisted queries + CDN hashing). This is solvable but adds complexity.

2. **Rate limiting is hard:** REST rate limits per endpoint. GraphQL queries vary in cost — one query might join 3 tables; another, 20. You need query complexity analysis (field cost weights, depth limits) rather than simple request counting.

3. **Authorization complexity:** Every field resolver can be a security boundary. Field-level authorization must be consistent. Libraries like `graphql-shield` help but add layers.

4. **Over-engineering risk:** "Why, after 6 years, I'm over GraphQL" (Bessey, 2024) — GraphQL is excellent for client-driven data fetching (Facebook's original use case: mobile clients with varying screen sizes and data needs). For server-to-server APIs, it adds indirection without proportional benefit.

**GraphQL is a strong fit when:**

- Multiple clients (web/mobile/third-party) with different data requirements consume the same backend
- Rapid iteration where clients frequently change their data needs
- Frontend teams own client queries independently of backend teams

**GraphQL is a poor fit when:**

- The API is primarily server-to-server (use gRPC or REST)
- Simple CRUD with consistent response shapes (REST is sufficient)
- Teams lack the DataLoader discipline or schema governance maturity

### Relay vs. Apollo Conventions

| Concern | Relay | Apollo |
|---------|-------|--------|
| Pagination | Cursor-based Connections spec (required) | Flexible; cursor/offset both common |
| Fragments | Co-location + auto-optimization (required) | Optional |
| Global IDs | Required (type:id encoding) | Optional |
| Cache updates | Store-based, normalized | Cache normalization optional |
| Learning curve | High; enforces specific patterns | Low; permissive |

Relay's opinionated conventions produce more consistent APIs but require teams to adopt its patterns wholesale. Apollo is more permissive and has broader ecosystem adoption.

---

## gRPC

### Core Architecture

gRPC (Google Remote Procedure Call) is an open-source RPC framework using HTTP/2 for transport and Protocol Buffers as the interface description language and serialization format.

```protobuf
service UserService {
  rpc GetUser (GetUserRequest) returns (UserResponse);
  rpc ListUsers (ListUsersRequest) returns (stream UserResponse);
  rpc BatchCreateUsers (stream CreateUserRequest) returns (BatchResult);
  rpc Chat (stream ChatMessage) returns (stream ChatMessage);
}
```

### Four Streaming Modes

1. **Unary RPC:** Single request → single response. Equivalent to a standard HTTP API call.

2. **Server-side streaming:** Client sends one request; server sends a stream of responses. Use case: log tailing, large dataset download, real-time data push.

   ```protobuf
   rpc WatchOrders (WatchRequest) returns (stream Order);
   ```

3. **Client-side streaming:** Client sends stream of requests; server sends one response. Use case: file upload, sensor data aggregation.

   ```protobuf
   rpc UploadChunks (stream FileChunk) returns (UploadResult);
   ```

4. **Bidirectional streaming:** Both sides stream independently. Use case: real-time collaboration, multiplayer game state, chat.

   ```protobuf
   rpc BidirectionalChat (stream Message) returns (stream Message);
   ```

### Protocol Buffers: Backward Compatibility Rules

Protobuf's evolution rules enable schema changes without breaking existing clients:

- **Safe:** Add new optional fields (new field numbers), add new enum values, rename fields (field numbers are what matter in binary encoding)
- **Unsafe (breaking):** Change a field's type, reuse a field number, change a field from optional to required, delete and reuse a field number without `reserved`

```protobuf
message User {
  reserved 3, 5;           // Never reuse these field numbers
  reserved "old_field";    // Never reuse this name
  
  string id = 1;
  string email = 2;
  string display_name = 4; // Added in v2 — backward compatible
}
```

**buf CLI** (from Buf Technologies) enforces protobuf breaking change detection in CI, replacing the fragile manual enforcement that caused production incidents at many companies.

### gRPC-Gateway

Generates a reverse proxy that translates REST/JSON requests to gRPC:

```protobuf
import "google/api/annotations.proto";

service UserService {
  rpc GetUser (GetUserRequest) returns (UserResponse) {
    option (google.api.http) = {
      get: "/v1/users/{id}"
    };
  }
}
```

Use case: expose an internal gRPC API externally as REST for browser clients or third-party consumers without maintaining two separate API implementations.

### When to Choose gRPC vs. REST vs. GraphQL

| Criterion | gRPC | REST | GraphQL |
|-----------|------|------|---------|
| Service-to-service (internal) | Best | Good | Overkill |
| Public API | Poor browser support without grpc-web | Best | Good |
| Multiple client types | Requires generated stubs | Good | Best |
| Streaming | Native, efficient | Limited (SSE/WS) | Subscriptions |
| Schema enforcement | Very strong (protobuf) | Optional (OpenAPI) | Strong (SDL) |
| Payload efficiency | Best (binary) | Good (JSON) | Variable |
| Ecosystem maturity | Good (server-side) | Excellent | Good |
| Learning curve | High | Low | Medium |
| Debugging | Hard (binary wire format) | Easy (human-readable) | Medium |

**Practical guidance:**

- Use gRPC for service-to-service communication in polyglot microservices environments where performance matters and teams control both client and server
- Use REST for public APIs, browser-facing APIs, or teams without protobuf toolchain discipline
- Use GraphQL when a product team owns both frontend and backend and builds for multiple client types with varying data requirements

---

## WebSockets

### Protocol and Use Cases

WebSocket (RFC 6455) provides full-duplex communication over a single TCP connection. The handshake upgrades HTTP:

```http
GET /ws HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: [base64]
Sec-WebSocket-Version: 13
```

**Appropriate use cases:**

- Real-time collaborative features (document editing, cursor sharing)
- Live data feeds (financial tickers, sports scores, live dashboards)
- Multiplayer game state
- Chat applications
- Pair programming tools

**Infrastructure implications:**

- WebSockets are stateful connections — horizontal scaling requires sticky sessions or a pub/sub broker (Redis Pub/Sub, Kafka) to fan out messages to the correct server holding a connection
- Load balancers must support WebSocket upgrades (most modern ones do, but check timeout settings)
- Connection count (not request count) determines server capacity
- Heartbeat/ping-pong frames prevent connection drops through firewalls with short idle timeouts

### Authentication Over WebSockets

HTTP headers are unavailable after the upgrade. Common patterns:

1. **Query parameter token (suboptimal):** `wss://api.example.com/ws?token=jwt123` — tokens appear in server logs
2. **First-message auth:** Connection accepted; first message must be `{"type":"auth","token":"..."}` within N seconds or connection is closed
3. **Ticket-based:** HTTP endpoint issues a short-lived single-use ticket; WebSocket connection presents ticket

Pattern 2 (first-message auth) is the most common production approach.

### Scaling WebSockets

```text
                    ┌─────────────────┐
Client A ─── WS ─── │  Server 1       │
Client B ─── WS ─── │  Server 1       │ ──── Redis Pub/Sub
Client C ─── WS ─── │  Server 2       │
Client D ─── WS ─── │  Server 2       │
                    └─────────────────┘
```

When Server 1 receives an event for Client C, it publishes to Redis; Server 2 receives the message and pushes to Client C's connection.

---

## Server-Sent Events (SSE)

SSE provides unidirectional server-to-client streaming over a persistent HTTP connection. Simpler than WebSockets for push-only use cases.

```http
GET /events HTTP/1.1
Accept: text/event-stream

HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"type": "order_update", "id": "123", "status": "shipped"}\n\n

event: inventory_alert
data: {"sku": "ABC-001", "quantity": 0}\n\n
```

**Advantages over WebSockets for push-only use cases:**

- Plain HTTP — works through all proxies, load balancers, and CDNs with zero special configuration
- Automatic reconnection built into the browser `EventSource` API
- Multiplexed over HTTP/2 (unlike HTTP/1.1 WebSockets which need a separate connection per stream)
- Significantly simpler server implementation

**Limitations:**

- Unidirectional (server → client only)
- No binary frames — only UTF-8 text (base64 encoding required for binary)
- Browser `EventSource` doesn't support custom headers (use query params or initial POST for auth)
- Max 6 concurrent connections per domain in HTTP/1.1 (non-issue with HTTP/2)

**SSE is the right choice for:** AI response streaming, live activity feeds, progress updates, notification systems — anywhere you need server push without bidirectional communication.

---

## tRPC

### What tRPC Solves

tRPC (TypeScript Remote Procedure Call) provides end-to-end type safety between a TypeScript server and TypeScript client without a build step or code generation. The server defines procedures; the client gets TypeScript types automatically through the TypeScript type system.

```typescript
// Server
const appRouter = router({
  getUser: procedure
    .input(z.object({ id: z.string() }))
    .query(async ({ input }) => {
      return db.user.findUnique({ where: { id: input.id } });
    }),
});

// Client — fully typed, no codegen
const user = await trpc.getUser.query({ id: "u-123" });
// user is typed as: { id: string; email: string; name: string } | null
```

**tRPC is optimal when:**

- Full-stack TypeScript monorepo (Next.js, SvelteKit, etc.)
- Internal API consumed only by TypeScript clients
- Team prioritizes rapid iteration over formal API contracts

**tRPC is inappropriate when:**

- Multiple language clients (types don't transfer)
- Third-party API consumers (you need an OpenAPI spec, not TypeScript types)
- Teams not using TypeScript

tRPC competes with direct Zod-validated REST or typed OpenAPI clients (Orval, Hey API). The type-safety benefit is real but only within a TypeScript-only ecosystem.

---

## JSON-RPC

A lightweight stateless remote procedure call protocol using JSON. Version 2.0 (2010) is current.

```json
// Request
{ "jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1 }

// Response
{ "jsonrpc": "2.0", "result": 19, "id": 1 }
```

**Batch requests** are a notable feature: multiple requests in a JSON array, responses returned as an array.

**Current adoption:** Ethereum/Web3 (the JSON-RPC spec dominates blockchain node APIs), Language Server Protocol (LSP) in editors, some internal tooling. Not a common choice for new green-field APIs — REST or gRPC are preferred for their ecosystem tooling.

---

## SOAP: Survival Knowledge

SOAP (Simple Object Access Protocol) is an XML-based messaging protocol. Relevant only for integration with legacy enterprise systems (SAP, Salesforce's older SOAP API, banking systems, healthcare).

Key characteristics:

- WSDL (Web Services Description Language) describes the API
- Messages wrapped in XML `<Envelope>` with `<Header>` and `<Body>`
- Supports WS-Security for message-level encryption and signing (not just transport)
- Has formal error handling (`<Fault>`)
- Stateful operations possible through WS-Addressing

If you encounter SOAP in a new project, it's almost certainly for integration with a system you cannot modify. Use a SOAP client library and do not design new SOAP APIs.

---

## OData

OData (Open Data Protocol) is an OASIS standard for REST APIs with a standardized query language:

```http
GET /api/Products?$filter=Price lt 10.00&$orderby=Name&$select=Name,Price&$top=5
```

**Adoption:** Microsoft's first-party APIs (Microsoft Graph, Dynamics 365), SAP, Salesforce.

**Strengths:** Ad-hoc filtering/sorting/paging defined by the protocol rather than each API.
**Weaknesses:** Complex client implementation, verbose query syntax, over-fetching still possible, poor fit for non-tabular data. Rarely chosen for new green-field APIs outside enterprise Microsoft ecosystems.

---

## HTTP/3 and QUIC: Implications for API Design

HTTP/3 uses QUIC (UDP-based) instead of TCP:

**Key differences affecting APIs:**

1. **Head-of-line blocking eliminated:** In HTTP/2, a lost packet blocks all multiplexed streams on that TCP connection. HTTP/3/QUIC gives each stream independent retransmission — critical for multiplexed APIs on lossy networks
2. **Faster connection establishment:** QUIC combines transport and TLS handshakes — 0-RTT reconnection for known servers
3. **Connection migration:** A connection can survive an IP address change (mobile clients moving between networks)

**Current state (2024–2025):**

- HTTP/3 is supported by Cloudflare, Fastly, Google, Nginx 1.25+, HAProxy, AWS CloudFront
- Browser support is ~95%+ (Chrome, Firefox, Safari all support it)
- Server-side library support is maturing but not universal
- gRPC-over-HTTP/3 is in development; most gRPC deployments still use HTTP/2

**API design impact:** HTTP/3 is transparent to API semantics — you don't change your endpoints. The benefit is infrastructure-level latency reduction. Deploy via CDN/edge providers; most APIs get HTTP/3 support for free if they're behind Cloudflare or similar.

---

## API Mesh / Federation Patterns

An API mesh (distinct from GraphQL federation) is an architectural approach where multiple APIs are composed into a unified access layer:

```text
┌────────────────────────────────────┐
│          API Mesh Layer            │
│  (WunderGraph / Hasura / Tyk)      │
├──────────┬──────────┬──────────────┤
│ REST API │ GraphQL  │ gRPC Service │
│  (Orders)│ (Products│ (Inventory)  │
└──────────┴──────────┴──────────────┘
```

Tools: WunderGraph (open-source, composes REST+GraphQL+gRPC into a single GraphQL API), Hasura (PostgreSQL + REST → GraphQL), StepZen (now defunct, acquired by IBM).

**When this pattern adds value:** When you have heterogeneous API backends and need to provide a consistent, typed interface to frontend clients. The mesh handles protocol translation, authentication, and schema unification.

**Trade-off:** The mesh layer is a single point of failure and a performance bottleneck. Latency stacks (client → mesh → service A + mesh → service B). Operational complexity increases. Only justified when the consistency benefit outweighs the overhead.

---

## Decision Framework: Choosing an API Paradigm

```text
Is your API consumed by browsers without a build step?
├── Yes → REST or GraphQL (not gRPC without grpc-web + envoy proxy)
└── No → All options available

Is your API public (third-party consumers)?
├── Yes → REST (best ecosystem) or GraphQL (if client data needs vary significantly)
└── No → gRPC viable for service-to-service

Do you have multiple client types with varying data needs?
├── Yes → GraphQL (federation if multiple backends)
└── No → REST sufficient

Do you need bidirectional real-time communication?
├── Yes → WebSockets
└── Do you need server-push only?
    ├── Yes → SSE (simpler, proxies-compatible)
    └── No → REST / gRPC (request-response)

Is your stack TypeScript-only, internal, monorepo?
└── Yes → tRPC is worth evaluating
```

---

## Key References

- [Roy Fielding's REST Dissertation (2000)](https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)
- [Richardson Maturity Model — Martin Fowler](https://martinfowler.com/articles/richardsonMaturityModel.html)
- [GraphQL Specification](https://spec.graphql.org/)
- [gRPC Documentation](https://grpc.io/docs/)
- [DataLoader](https://github.com/graphql/dataloader)
- [Apollo Federation 2.0](https://www.apollographql.com/docs/federation/)
- [tRPC Documentation](https://trpc.io/docs)
- [RFC 6455: WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
- [HTTP/3 and QUIC — Cloudflare Blog](https://blog.cloudflare.com/http3-the-past-present-and-future/)
- [Why, after 6 years, I'm over GraphQL (Bessey, 2024)](https://bessey.dev/blog/2024/05/24/why-im-over-graphql/)
- [WunderGraph DataLoader 3.0](https://wundergraph.com/blog/dataloader_3_0_breadth_first_data_loading)
- [REST vs GraphQL vs gRPC Performance (ResearchGate 2024)](https://www.researchgate.net/publication/381763921_Performance_evaluation_of_microservices_communication_with_REST_GraphQL_and_gRPC)

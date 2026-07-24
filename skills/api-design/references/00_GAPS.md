# Knowledge Base Gaps and Future Research

**Created:** 2026-06-25

This document records topics that were identified during research but not covered fully, with honest explanations of why and what future research would add.

---

## Gaps by Domain

### GraphQL In-Depth (Planned as 22_graphql_in_depth.md)

**What's missing:** A dedicated file on GraphQL was planned but the depth was covered within `01_api_paradigms.md` to avoid repetition. Missing:

- Schema stitching vs. Federation: detailed comparison of approaches for combining schemas
- Relay specification in full depth: connection cursor spec, Node interface, refetch containers
- GraphQL subscriptions: WebSocket transport, SSE transport (newer), scaling concerns
- Apollo Client caching details: normalize store, optimistic updates, cache invalidation
- Schema-first workflow tooling: Pothos, Nexus, TypeGraphQL — type-safe schema builders
- GraphQL persisted queries in production: APQ implementation with Apollo Router

**Priority:** Medium. Covered enough for architectural decisions; missing for practitioners building production GraphQL systems.

### gRPC In-Depth (Planned as 23_grpc_in_depth.md)

**What's missing:**

- grpc-web and Envoy proxy: serving gRPC to browsers
- Reflection API: runtime schema discovery
- Health checking: gRPC health checking protocol
- Load balancing in Kubernetes: headless services, gRPC-aware load balancing (client-side)
- gRPC transcoding: the full mapping between gRPC and REST HTTP/JSON
- Buf Schema Registry: centralized protobuf registry, BSR module system
- gRPC-Gateway: detailed implementation guide

**Priority:** Medium. Important for teams adopting gRPC service-to-service.

### API Contracts Deep Dive (Planned as 24_api_contracts.md)

**What's missing:**

- Pact internals: how the pact file format works, matchers in depth
- Contract testing for GraphQL: schemacheck vs. Pact for GraphQL, schema registry approach
- AsyncAPI contract testing with Microcks: step-by-step guide
- Schema compatibility rules in Confluent Schema Registry: BACKWARD, FORWARD, FULL transitive
- OpenAPI diff in practice: handling the "breaking change detected, what now?" workflow

**Priority:** High for teams building microservices with independent deployment.

### Financial and Regulated API Patterns

**What's missing:**

- PCI-DSS compliance for payment APIs: what the standard requires, scope reduction patterns
- HIPAA-compliant API design: audit logging, PHI handling, BAA requirements
- FAPI (Financial-grade API) profile: OAuth 2.0 extension for banking APIs, open banking
- FDX (Financial Data Exchange): US open banking standard
- PSD2 Strong Customer Authentication: European regulation impact on API design

**Priority:** High for fintech/healthcare practitioners; not broadly applicable.

### API Monetization

**What's missing:**

- Usage-based pricing models: per-call, per-token, per-resource
- API product management: rate plans, developer tiers, freemium design
- Billing integration: how Apigee, Kong Enterprise, and Zuplo handle billing
- Metering patterns: counting billable events accurately at scale
- Partner API programs: how Stripe, Twilio, Shopify structure partner ecosystems

**Priority:** Medium. Relevant to API platform builders more than API consumers.

### WebAssembly (WASM) at the API Edge

**What's missing:**

- Cloudflare Workers + WASM: running non-JavaScript code at edge
- WASI (WebAssembly System Interface): standardized system calls for WASM
- WASM for API gateway plugins: Envoy's WASM extension mechanism
- Fastly Compute@Edge: WASM-first edge computing platform

**Priority:** Low-medium. Emerging and primarily relevant for edge computing specialists.

### Quantum-Safe Cryptography Impact on APIs

**What's missing:**

- Post-quantum TLS: NIST-selected algorithms (ML-KEM, ML-DSA, SLH-DSA)
- Timeline for TLS 1.3 + post-quantum hybrids
- Impact on JWT signing: when RS256 and ES256 become insufficient
- API authentication migration path to post-quantum algorithms

**Priority:** Low for immediate use; high for long-lived systems (10+ year horizon). NIST finalized PQC algorithms in August 2024; TLS adoption will follow over 5-10 years.

### Multi-Tenant API Architecture

**What's missing:**

- Tenant isolation patterns: shared database, schema per tenant, database per tenant
- Tenant-aware rate limiting: per-tenant limits vs. per-account limits
- Cross-tenant data access control: ensuring tenant A cannot access tenant B's data
- Tenant lifecycle: provisioning, suspension, deletion, data export
- Subdomain routing: `tenant.api.example.com` vs. `api.example.com/tenants/{id}`

**Priority:** High for SaaS API builders; frequently underestimated in early design.

### API Analytics and Business Intelligence

**What's missing:**

- API usage analytics beyond RED metrics: consumer journey, conversion funnel
- Chargeback and showback for internal APIs
- Developer funnel analytics: signup → first call → integration → production → renewal
- API error analytics: categorizing errors by consumer, endpoint, and error type
- Building analytics dashboards: Moesif vs. custom Grafana vs. Amplitude for API analytics

**Priority:** Medium. Important for API-as-product teams.

### Temporal APIs and Time-Aware Design

**What's missing:**

- Bi-temporal data models in APIs: valid time vs. transaction time
- Event sourcing at the API level: exposing event history through APIs
- Temporal precision in API contracts: `date-time` format ambiguities (timezone assumptions)
- TTL headers and time-to-live in API responses beyond HTTP caching

**Priority:** Low. Applies to specific domains (financial, healthcare, compliance).

### AI Gateway Deep Dive

**What's missing:**

- LiteLLM configuration in production: routing rules, fallbacks, load balancing
- Portkey advanced features: semantic caching, request/response transforms
- Building a custom AI gateway: when and how
- AI gateway observability: token counting per model, cost attribution
- Rate limiting for AI APIs: token bucket by token count, not request count

**Priority:** High and rapidly evolving. The `15_api_for_ai_agentic.md` file covers this at a high level; a dedicated file would go deeper.

---

## Topics That Were Intentionally Excluded

### SOAP Deep Dive

Covered only as survival knowledge in `01_api_paradigms.md`. A full SOAP reference would add little value for new projects. Teams integrating with SOAP legacy systems should consult vendor-specific SOAP client documentation.

### API-Specific Frontend Frameworks

React Query, SWR, TanStack Query, Apollo Client — these are client-side data fetching libraries that consume APIs, not API design topics. Excluded as out of scope.

### Database Design for APIs

The N+1 problem, connection pooling, and pagination query optimization are covered in `12_performance_scaling.md`. Full database design (schema design, indexing strategy, normalization) is a separate domain.

### Cryptography Foundations

JWT signing algorithms, HMAC, TLS handshakes — covered at the implementation level in `05_security.md` and `06_authentication_authorization.md`. Deep cryptographic foundations (elliptic curves, RSA math) are out of scope for an API design knowledge base.

---

## Research Recency Caveats

The following topics are rapidly evolving and should be re-researched before making implementation decisions:

| Topic | Last Researched | Change Rate | Re-research Trigger |
|-------|----------------|-------------|---------------------|
| MCP specification | June 2026 | Monthly | New MCP spec release |
| AI API designs (tool calling) | June 2026 | Monthly | Major LLM provider updates |
| OpenAPI 3.2 tooling support | June 2026 | Quarterly | Tooling adoption announcements |
| OAuth 2.1 RFC publication | June 2026 | When published | IETF RFC publication |
| NIST PQC TLS integration | June 2026 | Annual | TLS 1.3 extension proposals |
| AWS/Azure/GCP API Gateway pricing | June 2026 | Annual | Pricing page changes |

---

## Methodology Limitations

**Primary limitation:** This knowledge base is based on primary sources (specifications, RFCs, vendor documentation, practitioner blogs) and synthesized by training. Real-world operational experience — knowing which tools fail at which scale, which vendor's documentation misleads, which architectural patterns create organizational problems — is not fully capturable from secondary sources.

**Recommendation:** Supplement this knowledge base with:

1. Post-mortems from your own production incidents
2. War stories from practitioners at similar-scale companies (conference talks, blogs)
3. Hands-on experimentation with tooling before committing in production

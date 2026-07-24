# API Research Knowledge Base — Master Plan

**Version:** 1.0 | **Created:** 2026-06-25 | **Status:** Living Document

---

## Research Mission

Produce an exhaustive, authoritative, practitioner-grade knowledge base on API design, implementation, and operations. Prioritize synthesis, nuance, trade-offs, and real-world caveats over surface documentation.

---

## Domain Inventory

### Tier 1 — High Complexity (Require deepest research + multiple sources)

| File | Domain | Depth | Interdependencies |
|------|---------|-------|-------------------|
| 01 | API Paradigms & Styles | High | feeds everything |
| 05 | Security | High | 06, 10, 12 |
| 06 | Authentication & Authorization | High | 05, 10, 15 |
| 15 | APIs for AI/Agentic Systems | High | 16, 06, 07 |
| 16 | Model Context Protocol (MCP) | High | 15, 01, 17 |
| 04 | Versioning Strategies | High | 02, 03, 09, 19 |
| 13 | Event-Driven APIs | High | 14 |

### Tier 2 — Medium-High Complexity

| File | Domain | Depth | Interdependencies |
|------|---------|-------|-------------------|
| 02 | OpenAPI & Specs | Medium-High | 03, 09, 17, 18 |
| 03 | Design Principles | Medium-High | 01, 02 |
| 07 | Error Handling | Medium-High | 01, 03 |
| 09 | CI/CD & APIOps | Medium-High | 02, 08, 10 |
| 10 | API Management & Gateways | Medium-High | 05, 06, 11, 12 |
| 11 | Observability | Medium-High | 10, 12 |
| 12 | Performance & Scaling | Medium-High | 10, 11 |

### Tier 3 — Medium Complexity

| File | Domain | Depth | Interdependencies |
|------|---------|-------|-------------------|
| 08 | Testing | Medium | 02, 09 |
| 14 | Async Messaging & AsyncAPI | Medium | 13 |
| 17 | Developer Experience | Medium | 02, 18 |
| 18 | Documentation | Medium | 02, 17 |
| 19 | API Lifecycle | Medium | all |
| 20 | Cloud & Deployment | Medium | 10, 12 |
| 21 | Tooling Ecosystem | Medium | all |

---

## Additional Files Identified During Planning

| File | Rationale |
|------|-----------|
| 22_graphql_in_depth.md | GraphQL deserves its own file beyond the paradigm overview |
| 23_grpc_in_depth.md | gRPC streaming patterns and ecosystem warrant dedicated coverage |
| 24_api_contracts.md | Contract testing and consumer-driven contracts is a substantial topic |
| 25_real_world_patterns.md | Stripe, Twilio, GitHub, Shopify, AWS patterns — practitioner learnings |

---

## Research Approach

### Primary Sources (by domain cluster)

**Specifications:**

- spec.openapis.org, json-schema.org, asyncapi.com, typespec.io, buf.build
- RFCs: RFC 9457 (Problem Details), RFC 8594 (Sunset), RFC 6749/6750 (OAuth), RFC 7519 (JWT)

**Security:**

- OWASP API Security Top 10 2023, NIST guidelines
- Practitioner blogs: Philippe De Ryck, Auth0 blog, Okta developer

**Paradigms:**

- Roy Fielding's dissertation (REST), GraphQL spec, gRPC documentation
- Martin Fowler's blog, Phil Sturgeon's blog

**Real-world patterns:**

- Stripe API docs and engineering blog
- Twilio blog
- GitHub API docs and REST conventions
- Netflix tech blog
- AWS Builder's Library

**AI/MCP:**

- MCP specification (modelcontextprotocol.io)
- Anthropic and OpenAI function calling documentation
- Emerging practitioner writing (2024–2025)

### Research Method Per Domain

1. Fetch primary spec/RFC where applicable
2. Search for practitioner critique/adoption reports
3. Search for 2024–2025 updates and emerging patterns
4. Cross-reference 2–3 sources before making claims
5. Flag contested areas explicitly

---

## Key Tensions to Track

1. **Design-first vs. code-first** — tooling maturity vs. team velocity
2. **REST vs. GraphQL vs. gRPC** — no universal winner; depends on context
3. **JWT self-contained vs. token introspection** — distributed perf vs. revocability
4. **Gateway-heavy vs. lean gateway** — centralized policy vs. complexity
5. **Versioning approaches** — URI path vs. header vs. no-version
6. **Specification coverage** — OpenAPI for sync, AsyncAPI for async, gap for agents
7. **MCP vs. function calling** — emerging tension in AI tooling
8. **Webhooks vs. streaming** — delivery guarantees vs. latency

---

## Execution Order

Phase 1 (Foundations): 01, 02, 03, 04
Phase 2 (Security/Auth): 05, 06, 07
Phase 3 (Operations): 08, 09, 10, 11, 12
Phase 4 (Event-Driven/Async): 13, 14
Phase 5 (AI/Emerging): 15, 16
Phase 6 (DX/Lifecycle): 17, 18, 19, 20, 21
Phase 7 (Synthesis): INDEX.md, 00_GAPS.md

---

## Updates Log

- 2026-06-25: Initial plan created, 22 base files + 4 additional identified

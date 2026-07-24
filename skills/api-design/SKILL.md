---
name: api-design
description: >-
  Use when designing, reviewing, or implementing any API or API-adjacent feature —
  REST, GraphQL, gRPC, webhooks, event-driven or async messaging, or MCP servers.
  Covers OpenAPI/AsyncAPI spec authoring, URL and resource design, versioning and
  breaking-change management, pagination, idempotency, authentication and authorization
  (API keys, OAuth2, JWT, scopes), security (OWASP API Top 10, CORS, input validation),
  RFC 9457 error responses, API gateways and management, APIOps and CI/CD for specs,
  observability, performance and scaling, developer experience, documentation, the API
  lifecycle, cloud deployment, tooling, and real-world patterns from Stripe, Twilio, and
  GitHub. A language-agnostic reference knowledge base — consult it before making an API
  design or tooling decision rather than relying on generic advice.
---

# API Design & Engineering

An extensive, language-agnostic knowledge base on designing and operating APIs. When a task
touches API design, specs, security, or tooling, **consult the relevant reference file below
before deciding** — cite the specific pattern you are following and why. Prefer these grounded
answers over generic advice.

## How to use this skill

1. Identify which topic(s) the task touches using the map below.
2. Read the matching file(s) in `references/`. Read `references/INDEX.md` first if the task
   spans several topics or you are unsure where something lives.
3. Apply the pattern and name the source (e.g. "per `05_security.md`, OWASP API1 …").

## Reference map (`references/`)

| Topic | File |
|---|---|
| Choosing a paradigm (REST/GraphQL/gRPC/webhooks) | `01_api_paradigms.md` |
| OpenAPI 3.1 spec authoring, schemas, examples | `02_openapi_and_specs.md` |
| URL design, resource modeling, pagination, idempotency | `03_design_principles.md` |
| Versioning & breaking-change management | `04_versioning.md` |
| Security — OWASP API Top 10, CORS, input validation | `05_security.md` |
| AuthN/AuthZ — API keys, OAuth2, JWT, scopes, fine-grained | `06_authentication_authorization.md` |
| Error handling — RFC 9457 `problem+json` | `07_error_handling.md` |
| Testing strategy (contract, conformance, mocks) | `08_testing.md` |
| CI/CD & APIOps pipelines | `09_ci_cd_apiops.md` |
| API gateways & management | `10_api_management_gateways.md` |
| Observability & logging | `11_observability_logging.md` |
| Performance & scaling | `12_performance_scaling.md` |
| Event-driven APIs | `13_event_driven_apis.md` |
| AsyncAPI & messaging | `14_async_api_and_messaging.md` |
| APIs for AI / agentic consumers | `15_api_for_ai_agentic.md` |
| Model Context Protocol (MCP) | `16_mcp_protocol.md` |
| Developer experience | `17_developer_experience.md` |
| Documentation | `18_documentation.md` |
| API lifecycle | `19_api_lifecycle.md` |
| Cloud & deployment patterns | `20_cloud_and_deployment.md` |
| Tooling ecosystem | `21_tooling_ecosystem.md` |
| Real-world patterns (Stripe/Twilio/GitHub) | `25_real_world_patterns.md` |
| Cross-topic index & navigation | `INDEX.md` |

## Notes

- These are point-in-time research notes. For anything version-sensitive (tool versions,
  product features, spec revisions), verify current docs before advising — see the global
  tooling rule (Context7 + web search).
- The files also include `00_PLAN.md` / `00_GAPS.md`, which document the knowledge base's own
  scope and known gaps.

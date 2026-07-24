# API Lifecycle Management

## Summary

The API lifecycle spans from ideation to retirement — not just development and deployment. Organizations that treat APIs as products (not just technical implementations) manage their full lifecycle deliberately: governance, design reviews, catalog management, deprecation, and retirement. This file covers API-first practices, governance models, the catalog as infrastructure, and the political dimensions of API lifecycle management.

---

## API Lifecycle Stages

```
Ideation → Design → Build → Test → Deploy → Operate → Evolve → Deprecate → Retire
    │           │        │       │        │         │         │           │
    │      Design Review  │      CI/CD    Monitoring│   Version bump  Sunset header
    │      Spec lint       │    Contract  SLO alerts│   Breaking     410 Gone
    │      Mock server     │    testing   Usage    │   change gate   Archive docs
    │                       │             analytics │
    └──────────── API-first cycle (design before code) ──────────────────────────┘
```

### Stage 1: Ideation

Before designing, establish:
- **Who is the consumer?** Internal team, public developers, partner, machine agent?
- **What problem does it solve?** Don't design an API for a problem that doesn't need an API.
- **What data/capabilities does it expose?** Bounded by what the backend system owns.
- **API style selection:** REST, GraphQL, gRPC, event-driven? (See `01_api_paradigms.md`)

**Anti-pattern:** Starting with "we need an API for X" without asking "does the API consumer need X, or do they need Y which X enables?"

### Stage 2: Design

The design stage produces an API specification (OpenAPI, AsyncAPI, protobuf). The specification is reviewed before implementation begins.

**Design review checklist:**
- [ ] Resource naming follows conventions (plural nouns, no verbs)
- [ ] Consistent with existing API patterns in the organization
- [ ] Authentication/authorization model documented
- [ ] Error responses follow RFC 9457
- [ ] Pagination strategy appropriate for expected data volume
- [ ] Breaking change analysis against existing related APIs
- [ ] SLO requirements documented
- [ ] Backward compatibility plan (can this evolve without breaking?)

### Stage 3: Build

Implementation against the specification. Two approaches:

**Design-first:** Spec written before implementation. Server validates against spec during development. The spec gates deployment.

**Code-first:** Implementation written; spec generated from code annotations. The spec is documentation-generated, not the source of truth.

Design-first produces better APIs; code-first is faster initially. See `03_design_principles.md` for the full trade-off analysis.

### Stage 4-5: Test and Deploy

Covered in `08_testing.md` and `09_ci_cd_apiops.md`.

### Stage 6: Operate

The operational lifecycle:
- Monitor SLIs against SLOs (`11_observability_logging.md`)
- Review consumer breakdown — who's calling what?
- Track deprecated endpoint usage (when can we safely remove?)
- Respond to security vulnerability reports

### Stage 7: Evolve

Adding features, fixing bugs, improving performance — without breaking existing consumers. Additive changes (new fields, new endpoints) are safe. Breaking changes require versioning (`04_versioning.md`).

### Stage 8: Deprecate

When a feature or version needs to be retired:
1. Announce via email, changelog, and dashboard notification
2. Add `Deprecation` and `Sunset` headers to deprecated endpoints
3. Monitor usage — don't sunset while usage > 0 from unknown consumers
4. Send usage reports to consuming teams ("Your service is calling deprecated endpoint X")
5. Support migration for known consumers

### Stage 9: Retire

The endpoint is removed. Return `410 Gone` with a body pointing to the replacement:
```json
HTTP/1.1 410 Gone
{
  "type": "https://api.example.com/problems/endpoint-retired",
  "title": "Endpoint Retired",
  "status": 410,
  "detail": "POST /v1/charges was retired on 2026-01-01. Use POST /v2/payments instead.",
  "migrationGuide": "https://docs.example.com/migration/charges-to-payments"
}
```

Keep the 410 response for at least 6 months after the sunset date.

---

## API-First as Organizational Practice

API-first means the API specification is written before implementation begins, and the spec drives everything: mocks, tests, documentation, and server validation.

**What makes API-first succeed:**
1. **Executive mandate:** API-first only works if it's required, not optional. Teams under deadline pressure will skip it without enforcement.
2. **Design tooling:** Developers need good tools to write specs. Stoplight Studio, Swagger Editor, or TypeSpec — the choice matters for adoption.
3. **Review gates in CI:** Spec lint and style guide enforcement must be automated; manual review doesn't scale.
4. **Mock server availability:** Without a mock server, frontend teams can't work in parallel. Prism from the spec = immediate mock.

**What makes API-first fail:**
1. Spec written after implementation ("we'll document it after the sprint") — defeats the purpose
2. Spec not kept in sync with implementation — creates a documentation lie
3. Treating the spec as a documentation artifact rather than a deployment gate

---

## API Governance

API governance is the organizational practice of ensuring API quality, consistency, and compliance across multiple teams.

### Governance Models

**Centralized (Empire model):**
A single platform team defines all API standards and reviews all API designs. Consistent; doesn't scale; bottleneck.

**Federated (Guild model):**
Teams are responsible for their own APIs; a governance guild defines standards, provides tooling, and reviews on request. More scalable; requires strong standards documentation.

**Automated (Tool-enforced):**
Style guide encoded in Spectral rulesets; CI gates enforce standards automatically. Most scalable; requires investment in tooling.

**Most successful organizations use the federated + automated combination:** Automated CI gates enforce non-negotiable standards (auth on all endpoints, RFC 9457 errors, operationId present); design reviews for new APIs are voluntary but available.

### API Style Guide

A documented set of conventions that all APIs in the organization follow:

```markdown
# Example Corp API Style Guide

## URL Conventions
- All paths use kebab-case for multi-word segments
- Resource names are plural nouns: /orders, /payment-methods
- No verbs in paths except for action sub-resources: /orders/{id}/ship

## Versioning
- All APIs use URI path versioning: /v1/, /v2/
- Version increment required for breaking changes (see breaking change taxonomy)

## Error Responses
- All errors use RFC 9457 Problem Details
- Content-Type: application/problem+json
- Include X-Correlation-ID from request in response

## Authentication
- All endpoints require authentication unless documented as public
- Bearer tokens (JWT) for external APIs
- mTLS + service account tokens for internal service-to-service

## Pagination
- Default page size: 20 items
- Maximum page size: 100 items
- Use cursor-based pagination for collections > 1000 items
```

The style guide is encoded in Spectral rules and enforced in CI.

---

## API Catalog and Service Registry

An API catalog provides internal discoverability — developers can find APIs without asking around.

### What a Catalog Contains

For each API:
- Name, description, version
- OpenAPI spec (link or embedded)
- Owner team and contact
- Lifecycle stage (beta, stable, deprecated)
- SLOs and operational runbook
- Consumer list (who's using this?)
- Dependencies (what does this API depend on?)

### Backstage

Spotify's Backstage is the dominant open-source internal developer platform. Its software catalog lists APIs, services, and libraries:

```yaml
# catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-api
  title: Orders API
  description: Order lifecycle management
  tags: [commerce, core-platform]
  annotations:
    github.com/project-slug: example-corp/orders-service
    pagerduty.com/integration-key: "abc123"
spec:
  type: openapi
  lifecycle: production
  owner: group:team-commerce
  system: commerce-platform
  definition:
    $text: ./openapi.yaml
```

Backstage auto-discovers service catalog entries and builds dependency graphs showing which services depend on which APIs.

---

## Platform Engineering for APIs

Platform engineering creates "golden paths" — opinionated, pre-configured ways for development teams to build and ship services.

**What a golden path for APIs provides:**
- Service template (repository scaffold with OpenAPI template, CI pipeline, Dockerfile)
- Pre-integrated observability (OTel configured out of the box)
- Pre-integrated authentication (JWT validation middleware pre-configured)
- Pre-configured linting and breaking change detection in CI
- Deployment templates (Kubernetes manifests, Terraform modules)

**The goal:** A developer creates a new service from a template and gets all of these for free — they only write business logic.

**Tools:**
- Backstage Software Templates (scaffolding)
- Cookiecutter / CopierProject (repository templates)
- Terraform modules (infrastructure templates)
- GitHub Actions reusable workflows (pipeline templates)

---

## Backward Compatibility Tooling

### oasdiff (OpenAPI)

See `04_versioning.md` for detailed oasdiff coverage.

### buf (Protocol Buffers)

```bash
# Check for breaking changes in protobuf schemas
buf breaking --against '.git#branch=main'

# Breaking change types checked:
# FILE_SAME_PACKAGE: Package changed
# FIELD_SAME_TYPE: Field type changed  
# FIELD_NO_DELETE: Field removed
# ENUM_NO_DELETE: Enum value removed
# MESSAGE_NO_DELETE: Message type removed
# SERVICE_NO_DELETE: RPC service removed
# METHOD_NO_DELETE: RPC method removed
```

**buf lint:** Also enforces protobuf style:
```yaml
# buf.yaml
version: v1
lint:
  use:
    - DEFAULT
    - COMMENTS
  ignore:
    - vendor
breaking:
  use:
    - FILE
```

---

## Key References

- [API-First Development — Swagger](https://swagger.io/resources/articles/adopting-an-api-first-approach/)
- [API Governance — Gartner](https://www.gartner.com/en/information-technology/glossary/api-management)
- [Backstage Software Catalog](https://backstage.io/docs/features/software-catalog/)
- [Diátaxis Framework for API Documentation](https://diataxis.fr/)
- [RFC 8594: The Sunset HTTP Header Field](https://datatracker.ietf.org/doc/html/rfc8594)
- [buf Breaking Change Detection](https://buf.build/docs/breaking/overview)
- [oasdiff](https://github.com/tufin/oasdiff)
- [API Lifecycle Management — Nordic APIs](https://nordicapis.com/the-api-lifecycle-managing-an-apis-state/)
- [Zalando API Principles](https://opensource.zalando.com/restful-api-guidelines/)
- [Microsoft API Guidelines](https://github.com/microsoft/api-guidelines)

---
name: continuous-delivery
description: >-
  Use when working on how software is delivered, not just written — build/deploy pipelines,
  release process, trunk-based development, test strategy for delivery, deployment frequency
  and DORA metrics, work decomposition and small batches, greenfield or brownfield CD adoption,
  continuous deployment / progressive rollout, or diagnosing slow, risky, or painful delivery.
  Also for AI/agent-generated changes in a delivery pipeline (agentic CD). A language-agnostic
  reference on continuous delivery: symptoms, anti-patterns, a phased migration path, improvement
  plays, DORA metrics, testing, and pipeline architecture. Consult it before advising on delivery,
  deployment, branching, or pipeline decisions.
---

# Continuous Delivery

A language-agnostic reference on delivering software with confidence: making every change
deployable, integrating daily, working in small batches, and shipping on demand. When a task
touches delivery, deployment, branching, pipelines, or release process, **consult the relevant
section below and cite the practice you are following.**

Driving question throughout: *"Why can't I deliver today's work to production today?"*

## How to use this skill

1. If diagnosing a problem, start from `references/symptoms/` or `references/triage/`.
2. If improving delivery, use `references/migrate-to-cd/` (the phased path) or a standalone
   `references/playbook/` play.
3. If the issue is a specific bad practice, look it up in `references/anti-patterns/`.
4. For definitions, metrics, and pipeline design, use `references/reference/`.
5. Read the `_index.md` in any section folder first — it summarizes and links that section.

## Section map (`references/`)

| Section | What's there |
|---|---|
| `start-here.md`, `learning-paths.md` | Orientation and guided reading sequences |
| `migrate-to-cd/` | The phased adoption path: Assess → Foundations → Pipeline → Optimize → Deliver on Demand, plus dedicated `greenfield/` and `brownfield/` guides |
| `migrate-to-cd/foundations/` | Trunk-based development, testing fundamentals, build automation, work decomposition (vertical slicing), everything-as-code |
| `migrate-to-cd/pipeline/` | Single path to production, deterministic pipeline, deployable definition, immutable artifacts, rollback |
| `migrate-to-cd/continuous-deployment/` | Progressive rollout, delivering on demand |
| `anti-patterns/` | Practices that undermine delivery (testing, pipeline, branching, org/cultural, team-workflow), each with a fix |
| `playbook/` | Standalone improvement plays runnable in isolation |
| `reference/` | DORA & CI-health metrics, MinimumCD practices, glossary, defect sources, pipeline reference architecture |
| `testing/` | Test types and applied testing strategies for delivery |
| `symptoms/` | Observable delivery problems (testing, deployment, flow, visibility) |
| `triage/` | Health-check and multi-symptom diagnosis to find where to start |
| `agentic-cd/` | Constraints and practices for AI/agent-generated changes in a CD pipeline |

## Core principles (quick reference)

- Every change stays in a deployable state; one automated path to production, no side doors.
- Integrate to trunk at least daily; short-lived branches only.
- Small batches, thin **vertical slices** that deliver observable behavior through the interface
  your team owns (for an API team, that interface is the API contract).
- For greenfield: pipeline is feature zero; deploy a walking skeleton to production before the
  first feature.
- Measure outcomes with DORA (deployment frequency, lead time, change-failure rate, MTTR), not
  output.

## Attribution

Content adapted from **beyond.minimumcd.org** (Bryan Finster / the Dojo Consortium), which
expands on **MinimumCD.org**. Hugo templating has been stripped for plain-text reference; for
the canonical, updated source, see the upstream site. Verify anything version-sensitive against
current sources.

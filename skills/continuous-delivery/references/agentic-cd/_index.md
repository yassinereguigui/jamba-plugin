---
title: "Agentic Continuous Delivery (ACD)"
linkTitle: "Agentic CD"
weight: 9
description: >
  Extend continuous delivery with constraints, delivery artifacts, and practices for AI agent-generated changes.
---

Agentic continuous delivery (ACD) defines the additional constraints and artifacts needed when AI agents contribute to the delivery pipeline. The pipeline must handle agent-generated work with the same rigor applied to human-generated work, and in some cases, more rigor. These constraints assume the team already practices continuous delivery. Without that foundation, the agentic extensions have nothing to extend.

## What Is ACD?

**An agent-generated change must meet or exceed the same quality bar as a human-generated change.** The pipeline does not care who wrote the code. It cares whether the code is correct, tested, and safe to deploy.

ACD is the application of continuous delivery in environments where software changes are proposed by agents. It exists to reliably constrain agent autonomy without slowing delivery.

Without additional artifacts beyond what human-driven CD requires, agent-generated code accumulates drift and technical debt faster than teams can detect it. The delivery artifacts and constraints in the agent delivery contract address this.

Agents introduce unique challenges that require these additional constraints:

- Agents can generate changes faster than humans can review them
- Agents cannot read unstated context: business rules, organizational norms, and long-term architectural intent that human developers carry implicitly
- Agents may introduce subtle correctness issues that pass automated tests but violate intent

Before jumping into agentic workflows, ensure your team has the prerequisite delivery practices in place. The AI Adoption Roadmap provides a step-by-step sequence: quality tools, clear requirements, hardened guardrails, and reduced delivery friction, all before accelerating with AI coding. The Learning Curve describes how developers naturally progress from autocomplete to a multi-agent architecture and what drives each transition.

### Prerequisites

ACD extends continuous delivery. These practices must be working before agents can safely contribute:

- **Continuous Integration** - all work integrates to trunk at least daily with automated build and test
- **Testing Fundamentals** - a test architecture that properly stress tests every change to ensure it's deliverable on demand.
- **Build Automation** - a single command builds, tests, and packages the application
- **Work Decomposition** - features broken into increments deliverable in two days or less
- **Code Review** - fast feedback without blocking flow
- **Everything as Code** - infrastructure, pipelines, configuration, and schemas in version control
- **Single Path to Production** - all changes reach production through the same automated pipeline
- **Deterministic Pipeline** - same inputs always produce the same outputs

Without these foundations, adding agents amplifies existing problems rather than accelerating delivery.

## What You'll Find in This Section

### Getting Started

- **Configuration Quick Start** - where to put what: project context file, rules, skills, and hooks mapped to their purpose and time horizon
- **The Agentic Development Learning Curve** - how developers progress from autocomplete to multi-agent architecture and what bottleneck drives each transition
- **Repository Readiness** - how to assess and upgrade a repository so agents can clone, build, test, and iterate without human intervention
- **The Four Prompting Disciplines** - the four layers of skill developers must master as AI moves from chat partner to long-running worker
- **AI Adoption Roadmap** - covers organizational prerequisites before adopting agentic workflows

### Specification & Contracts

- **Agent Delivery Contract** - defines the artifacts that anchor the ACD workflow and their authority hierarchy
- **Agent-Assisted Specification** - how agents help sharpen intent, draft BDD scenarios, and surface gaps before any code is written

### Agent Architecture

- **Agentic Architecture Patterns** - how to structure skills, agents, commands, and hooks in multi-agent systems
- **Coding & Review Setup** - provides a concrete orchestrator, coder, and reviewer agent configuration
- **Small-Batch Sessions** - how to structure agent sessions so context stays manageable and commits stay small

### Operations & Governance

- **Pipeline Enforcement and Expert Agents** - how quality gates and expert validation agents enforce ACD constraints automatically
- **Tokenomics** - how to architect agents and code to minimize unnecessary token consumption without sacrificing quality
- **Pitfalls and Metrics** - covers common failure modes and how to measure whether ACD is working

## ACD Extensions to MinimumCD

ACD *extends* MinimumCD by the following constraints:

1. Explicit, human-owned intent exists for every change
2. Intent and architecture are represented as delivery artifacts
3. All delivery artifacts are versioned and delivered together with the change
4. Intended behavior is represented independently of implementation
5. Consistency between intent, tests, implementation, and architecture is enforced
6. Agent-generated changes must comply with all documented constraints
7. Agents implementing changes must not be able to promote those changes to production
8. While the pipeline is red, agents may only generate changes restoring pipeline health

These constraints are **not mandatory practices.** They describe the *minimum conditions required to sustain delivery pace once agents are making changes* to the system.

## Agent Delivery Contract

Every ACD change is anchored by agent delivery contract - structured documents that define intent, behavior, constraints, acceptance criteria, and system-level rules. Agents may read and generate artifacts. Agents may **not** redefine the authority of any artifact. Humans own the accountability.

See Agent Delivery Contract for the authority hierarchy, detailed definitions, and examples.

## The ACD Workflow

Humans own the specifications. Agents collaborate during specification and own test generation and implementation. The pipeline enforces correctness. At every specification stage, the four-step cycle applies: human drafts, agent critiques, human decides, agent refines.

| Stage | Human | Agent | Pipeline |
|-------|-------|-------|----------|
| Intent Description | Draft and own the problem statement and hypothesis | Find ambiguity, suggest edge cases, sharpen hypothesis | |
| User-Facing Behavior | Define and approve BDD scenarios | Generate scenario drafts, find gaps and weak scenarios | |
| Feature Description | Set constraints and architectural boundaries | Suggest architectural considerations and integration points | |
| Acceptance Criteria | Define thresholds and evaluation design | Draft non-functional criteria, check cross-artifact consistency | |
| Specification Validation | Gate before implementation begins | Review all four artifacts for conflicts, gaps, and ambiguity | |
| Test Generation | | Generate test code from BDD scenarios, feature description, and acceptance criteria | |
| Test Validation | Review (interim) | Expert validation agents progressively replace human review | |
| Implementation | | Generate production code within one small-batch session per scenario | |
| Pipeline Verification | | | Run all tests; all scenarios implemented so far must pass |
| Code Review | Review (interim) | Expert validation agents progressively replace human review | |
| Deployment | | | Deploy through the same pipeline as any other change |

Human review at Test Validation and Code Review is an interim state. Replace it using the same replacement cycle used throughout the CD migration. See Pipeline Enforcement for the full set of expert agents and how to adopt them.

## Related Content

- Pipeline Reference Architecture - quality gates sequenced by defect detection priority
- Replacing Manual Validations - the replacement cycle for adopting expert validation agents
- Defect Sources - where defects originate, informing acceptance criteria and system constraints
- Small Batches - limiting change size, with extra rigor for agent-generated changes
- Code Coverage Mandates - an anti-pattern especially dangerous when agents optimize for coverage rather than intent
- Pressure to Skip Testing - an anti-pattern that ACD counters by making test-first workflow mandatory
- High Coverage but Ineffective Tests - a testing symptom that undermines the acceptance criteria agents depend on

---

Content contributed by  and . Image contributed by .

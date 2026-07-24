---
title: "Agentic CD Glossary"
linkTitle: "Glossary"
weight: 90
description: >
  Terms and definitions specific to agentic continuous delivery, AI agents, and LLMs.
---

This glossary defines terms specific to agentic continuous delivery (ACD). For general
continuous delivery terms, see the main glossary.

## A

### ACD (Agentic Continuous Delivery)

The application of continuous delivery in environments where software changes are proposed by
AI agents. ACD extends CD with additional constraints, delivery artifacts, and pipeline
enforcement to reliably constrain agent autonomy without slowing delivery. ACD assumes the
team already practices continuous delivery. Without that foundation, the agentic extensions
have nothing to extend. See Agentic Continuous Delivery.

Referenced in:
Agentic Continuous Delivery (ACD),
AI Adoption Roadmap,
Getting Started: Where to Put What,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics,
The Agentic Development Learning Curve,
The Four Prompting Disciplines,
Agent Delivery Contract,
Tokenomics: Optimizing Token Usage in Agent Architecture,
Your Migration Journey

### Agent (AI)

An AI system that uses tool calls in a loop to complete multi-step tasks autonomously. Unlike a
single LLM call that returns a response, an agent can invoke tools, observe results, and decide
what to do next until a goal is met or a stopping condition is reached. An agent's behavior is
shaped by its prompt - the complete set of instructions, context, and constraints it receives at
the start of a session. See Agentic CD.

Referenced in:
Agent-Assisted Specification,
Agentic Architecture Patterns,
Agentic Continuous Delivery (ACD),
AI Adoption Roadmap,
AI Tooling Slows You Down Instead of Speeding You Up,
Coding and Review Agent Configuration,
Experience Reports,
Getting Started: Where to Put What,
Learning Paths,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics,
Small-Batch Agent Sessions,
The Agentic Development Learning Curve,
Agent Delivery Contract,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Agent Loop

The iterative cycle an [agent](#agent-ai) follows during execution: receive a goal, invoke a
tool, observe the result, decide the next action, repeat until done or a stopping condition is
reached. Each iteration consumes [tokens](#token) for both the accumulated context and the new
output. Long agent loops increase cost and latency, which is why [small-batch sessions](#agent-session)
bound each loop to a single
BDD
scenario. See Small-Batch Agent Sessions.

Referenced in:
Small-Batch Agent Sessions,
The Agentic Development Learning Curve,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Agent Session

A bounded [agent](#agent-ai) invocation scoped to a single, well-defined task. Each session
starts with a curated context load, produces a tested change, and closes with a context summary
that replaces the full conversation for future sessions. The task might be a
BDD scenario, a bug
fix, a refactoring step, or any other change small enough to review in one pass. Bounding
sessions to small batches keeps context focused, costs predictable, and commits reviewable.
See Small-Batch Agent Sessions.

Referenced in:
Coding and Review Agent Configuration,
Small-Batch Agent Sessions,
The Agentic Development Learning Curve,
Tokenomics: Optimizing Token Usage in Agent Architecture

## C

### Context (LLM)

The complete assembled input provided to an LLM for a single inference call. Context includes
the system prompt, tool definitions, any reference material or documents, conversation history,
and the current user request. "Context" and "prompt" are often used interchangeably; the
distinction is that "context" emphasizes what information is present, while "prompt" emphasizes
the structured input as a whole. Context is measured in [tokens](#token). As context grows, costs
and latency increase and performance can degrade when relevant information is buried far from
the end of the context. See Tokenomics.

Referenced in:
Agentic Architecture Patterns,
Agentic Continuous Delivery (ACD),
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
Pitfalls and Metrics,
Small-Batch Agent Sessions,
The Agentic Development Learning Curve,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Context Window

The maximum number of tokens an LLM can process in a single call, spanning both input and
output. The context window is a hard limit; exceeding it requires truncation or a redesigned
approach. Large context windows (150,000+ tokens) create false confidence - more available
space does not mean better performance, and filling the window increases both latency and cost.
See Tokenomics.

Referenced in:
Experience Reports,
Agentic Architecture Patterns,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Context Engineering

The practice of curating the complete information environment an [agent](#agent-ai) operates
within. Context engineering goes beyond writing better [prompts](#prompt) - it means assembling
the right project files, conventions, constraints, and prior session state so
the agent starts each [session](#agent-session) with everything it needs and nothing it does
not. See
The Four Prompting Disciplines.

Referenced in:
Coding and Review Agent Configuration,
Small-Batch Agent Sessions,
The Four Prompting Disciplines,
Tokenomics: Optimizing Token Usage in Agent Architecture

## D

### Declarative Agent

An [agent](#agent-ai) defined entirely as markdown documents - [skills](#skill-agent),
[system prompts](#system-prompt), and rules files - that runs inside an existing agent runtime
(Claude Code, Cursor, or similar). The runtime provides the [agent loop](#agent-loop), tool
execution, and context management. Use declarative agents when a developer is present and the
runtime provides the tools needed. See
Agentic Architecture Patterns.

Referenced in:
Agentic Architecture Patterns,
Coding and Review Agent Configuration,
Getting Started: Where to Put What

### Delivery Contract

The set of structured specification documents that anchor an [ACD](#acd-agentic-continuous-delivery)
workflow. A delivery contract typically includes four artifacts arranged in an authority hierarchy:
an intent description (what and why), user-facing behavior expressed as
BDD scenarios (observable
outcomes), a feature description (architectural constraints, musts, must-nots), and
acceptance criteria (done definition and evaluation design). When an
[agent](#agent-ai) detects a conflict between artifacts, the higher-authority artifact wins.
See Agent Delivery Contract.

Referenced in:
Agent-Assisted Specification,
Agent Delivery Contract,
Coding and Review Agent Configuration,
The Four Prompting Disciplines

### Done Definition

See Reference Glossary.

## E

### Evaluation Design

The test-cases-with-known-good-outputs portion of acceptance criteria.
An evaluation design specifies concrete inputs and their expected outputs so that both humans
and [agents](#agent-ai) can verify whether code satisfies the done definition.
Shallow evaluation designs (few cases, no edge coverage) allow code that passes tests but
violates intent. Thorough evaluation designs catch model regressions before they reach
production. See
Agent Delivery Contract.

Referenced in:
Agent Delivery Contract,
Agent-Assisted Specification,
The Four Prompting Disciplines

### Expert Agent

A specialized [agent](#agent-ai) that runs as a pipeline gate to validate a
specific concern such as test fidelity, security patterns, architectural compliance, or intent
alignment. Expert agents extend traditional pipeline tooling by catching semantic defects that
linters and static analyzers cannot detect. They are adopted in parallel with human review and
replace the human gate only after demonstrating a low false-positive rate.
See Pipeline Enforcement and Expert Agents.

Referenced in:
AI Adoption Roadmap,
Coding and Review Agent Configuration,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics

## H

### Hallucination

A predictable defect mode - not a rare failure - where an LLM generates plausible-looking but
incorrect output: code that references APIs that do not exist, tests that assert the wrong
behavior, or architectural claims that contradict the actual codebase. Hallucinations are more
likely when the [agent](#agent-ai) lacks sufficient [context](#context-llm) about the project,
which is why [context engineering](#context-engineering) and
[repository readiness](#repository-readiness) reduce hallucination rates. Pipeline
guardrails and [review sub-agents](#sub-agent) catch hallucinations that slip
past the implementation agent. See
Pitfalls and Metrics.

Referenced in:
AI Adoption Roadmap,
AI-Generated Code Ships Without Developer Understanding,
Pitfalls and Metrics,
The Agentic Development Learning Curve

### Hook (Agent)

A deterministic, automated action that runs in response to a specific event during an
[agent session](#agent-session). Pre-hooks validate inputs before the agent acts (e.g., lint,
type-check, secret scan). Post-hooks validate outputs after the agent finishes (e.g., SAST,
test execution). Hooks execute standard tooling - fast, free of AI cost, and repeatable. They
run before the [review orchestrator](#orchestrator), so AI review tokens are spent only on
changes that already pass mechanical checks. See
Coding and Review Agent Configuration.

Referenced in:
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
Pipeline Enforcement and Expert Agents

## I

### Intent Engineering

The practice of encoding organizational purpose, values, and trade-off hierarchies into an
[agent's](#agent-ai) operating environment. An agent given [context](#context-llm) but no intent
will make technically defensible decisions that miss the point. Intent engineering defines the
decision boundaries the agent operates within - what to optimize for, when to escalate to a
human, and which trade-offs are acceptable. The formalized output of intent engineering is
the intent description in the [delivery contract](#delivery-contract). See
The Four Prompting Disciplines.

Referenced in:
Agent Delivery Contract,
Agent-Assisted Specification,
The Four Prompting Disciplines

## M

### Model Routing

Assigning tasks to appropriately-sized LLMs based on task complexity rather than using a single
frontier model for everything. Routing, context assembly, and aggregation tasks require minimal
reasoning and run cheaply on small models. Code generation and semantic review require strong
reasoning and justify frontier model costs. Model routing treats [token](#token) cost as a
first-class design constraint alongside latency and reliability. See
Tokenomics.

Referenced in:
Coding and Review Agent Configuration,
Tokenomics: Optimizing Token Usage in Agent Architecture

## O

### Orchestrator

An agent that coordinates the work of other agents. The orchestrator receives a high-level goal,
breaks it into sub-tasks, delegates those sub-tasks to specialized [sub-agents](#sub-agent), and
assembles the results. Because orchestrators accumulate context across multiple steps, context
hygiene at agent boundaries is especially important - what the orchestrator passes to each
sub-agent is a cost and quality decision. See Tokenomics.

Referenced in:
Agentic Architecture Patterns,
Agentic Continuous Delivery (ACD),
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
The Agentic Development Learning Curve,
Tokenomics: Optimizing Token Usage in Agent Architecture

## P

### Prompt

The complete structured input provided to an LLM for a single inference call. A prompt is not
a one- or two-sentence question. In production agentic systems, a prompt is a composed document
that typically includes: a system instruction block (role definition, constraints, output format
requirements), tool definitions, relevant context (documents, code, conversation history), and
the user's request or task description. The system instruction block and tool definitions alone
can consume thousands of tokens before any user content is included. Understanding what a prompt
actually contains is a prerequisite for effective tokenomics. See
Tokenomics.

Referenced in:
Agent-Assisted Specification,
Agentic Architecture Patterns,
Agent Delivery Contract,
Pitfalls and Metrics,
Rubber-Stamping AI-Generated Code,
Small-Batch Agent Sessions,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Prompt Caching

A server-side optimization where stable portions of a prompt are stored and reused across
repeated calls instead of being processed as new input each time. Effective caching requires
placing static content (system instructions, tool definitions, reference documents) at the
beginning of the prompt so cache hits cover the maximum token span. Dynamic content (user
request, current state) goes at the end where it does not invalidate the cached prefix.
See Tokenomics.

Referenced in:
Coding and Review Agent Configuration,
Agentic Architecture Patterns,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Prompt Craft

Synchronous, session-based instruction writing in a chat window. Prompt craft is the foundation
of the four [prompting disciplines](#prompting-discipline) - writing clear, structured
instructions with examples, counter-examples, explicit output formats, and rules for resolving
ambiguity. It is now considered table stakes, equivalent to fluent typing. Every developer
using AI tools reaches baseline proficiency here. The skill is necessary but insufficient for
agentic workflows, which require [context engineering](#context-engineering),
[intent engineering](#intent-engineering), and
[specification engineering](#specification-engineering). See
The Four Prompting Disciplines.

Referenced in:
The Agentic Development Learning Curve,
The Four Prompting Disciplines

### Prompting Discipline

The four-layer skill framework developers master as AI moves from a chat partner to a
long-running worker. The four disciplines, in order from foundation to ceiling:
[prompt craft](#prompt-craft), [context engineering](#context-engineering),
[intent engineering](#intent-engineering), and
[specification engineering](#specification-engineering). Each layer builds on the one below it.
Developers at Stage 5-6 of the agentic learning curve operate across all four simultaneously.
See The Four Prompting Disciplines.

Referenced in:
AI Adoption Roadmap,
The Agentic Development Learning Curve,
The Four Prompting Disciplines

### Programmatic Agent

An [agent](#agent-ai) implemented as a standalone program (typically JavaScript or Java) that
calls the LLM API directly and manages its own [agent loop](#agent-loop), tool definitions,
error handling, and context assembly. Unlike a [declarative agent](#declarative-agent), a
programmatic agent does not depend on an interactive runtime. Use programmatic agents when the
agent must run without a developer present: CI/CD pipeline gates, scheduled audits, event-driven
triggers, or parallel fan-out across repositories. The model-agnostic abstraction layer
is the minimum infrastructure a programmatic agent system needs. See
Agentic Architecture Patterns.

Referenced in:
Agentic Architecture Patterns,
Pipeline Enforcement and Expert Agents

## R

### Repository Readiness

The degree to which a repository is prepared for [agent](#agent-ai)-driven development. A
repository scores high on readiness when an agent can clone it, install dependencies, build,
run tests, and iterate without human intervention. Key factors include deterministic builds,
fast test suites, clear naming conventions, consistent project structure, and machine-readable
documentation. Low repository readiness is the most common reason agents produce poor results,
because the agent spends its [context](#context-llm) and [tokens](#token) navigating ambiguity
instead of solving the problem. See
Repository Readiness.

Referenced in:
AI Adoption Roadmap,
Getting Started: Where to Put What,
Repository Readiness

## S

### Skill (Agent)

A reusable, named session procedure defined as a markdown document that an [agent](#agent-ai)
or [orchestrator](#orchestrator) invokes by name (e.g., `/start-session`, `/review`,
`/end-session`). Skills encode the session discipline from
[agent sessions](#agent-session) so the orchestrator does not re-derive the workflow each time.
Skills are not executable code; they are structured instructions. See
Coding and Review Agent Configuration.

Referenced in:
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
Small-Batch Agent Sessions

### Specification Engineering

The practice of writing structured documents that [agents](#agent-ai) can execute against over
extended timelines. Specification engineering is the skill that separates developers at Stage
5-6 of the agentic learning curve from everyone else. When agents run autonomously for hours,
you cannot course-correct in real time - the specification must be complete enough that an
independent executor reaches the right outcome without asking questions. Key skills include
writing self-contained problem statements, acceptance criteria with
done definitions, [evaluation designs](#evaluation-design), and
decomposing large projects into small, bounded subtasks. The output of specification
engineering is the [delivery contract](#delivery-contract). See
The Four Prompting Disciplines.

Referenced in:
Agent-Assisted Specification,
Agent Delivery Contract,
The Four Prompting Disciplines

### Sub-agent

A specialized agent invoked by an [orchestrator](#orchestrator) to perform a specific,
well-defined task. Sub-agents should receive only the context relevant to their task - not
the orchestrator's full accumulated context. Passing oversized context bundles to sub-agents
is a common source of unnecessary token consumption and can degrade performance by burying
relevant information. See Tokenomics.

Referenced in:
Coding and Review Agent Configuration,
Agentic Architecture Patterns,
Tokenomics: Optimizing Token Usage in Agent Architecture

### System Prompt

The static, stable instruction block placed at the start of a [prompt](#prompt) that establishes
the model's role, constraints, output format requirements, and tool definitions. Unlike the
user-provided portion of the prompt, system prompts change rarely between calls and are the
primary candidates for [prompt caching](#prompt-caching). Keeping the system prompt concise and
placing it first maximizes cache effectiveness and reduces per-call input costs.
See Tokenomics.

Referenced in:
Agentic Architecture Patterns,
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
Pitfalls and Metrics,
Tokenomics: Optimizing Token Usage in Agent Architecture

## T

### Token

The billing and capacity unit for LLMs. A token is roughly three-quarters of an English word.
All LLM costs, latency, and context limits are measured in tokens, not words, sentences, or
API calls. Input and output tokens are priced and counted separately. Output tokens typically
cost 2-5x more than input tokens because generating tokens is computationally more expensive
than reading them. Frontier models cost 10-20x more per token than smaller alternatives.
See Tokenomics.

Referenced in:
Agentic Architecture Patterns,
Agentic Continuous Delivery (ACD),
AI Is Generating Technical Debt Faster Than the Team Can Absorb It,
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
The Agentic Development Learning Curve,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Tokenomics

The architectural discipline of treating [token](#token) cost as a first-class design constraint
alongside latency and reliability. Tokenomics applies five strategies:

- **Context hygiene:** strip what does not change [agent](#agent-ai) behavior
- **[Model routing](#model-routing):** match model tier to task complexity
- **Structured output:** JSON between agents, not prose
- **[Prompt caching](#prompt-caching):** stable content first, dynamic content last
- **Batch-size control:** bound [sessions](#agent-session) to limit accumulated context

Tokenomics is not about spending less - it is about spending tokens where they produce value
and cutting waste where they do not. See
Tokenomics.

Referenced in:
Agentic Continuous Delivery (ACD),
Coding and Review Agent Configuration,
Small-Batch Agent Sessions,
Tokenomics: Optimizing Token Usage in Agent Architecture

### Tool Use

The mechanism by which an [agent](#agent-ai) interacts with external systems during its
[agent loop](#agent-loop). On each iteration, the agent can invoke a tool (read a file, run a
test, execute a shell command, call an API), observe the result, and decide its next action.
Tool use is what distinguishes an agent from a single LLM call - the ability to act on the
environment, not just generate text. Each tool call adds [tokens](#token) to the context
(the call itself plus the result), which is why [context engineering](#context-engineering)
and [tokenomics](#tokenomics) account for tool-call overhead.

Referenced in:
Agentic Architecture Patterns,
Coding and Review Agent Configuration,
The Agentic Development Learning Curve

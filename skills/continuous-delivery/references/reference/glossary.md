---
title: "Glossary"
linkTitle: "Glossary"
weight: 15
description: >
  Key terms and definitions used throughout this guide.
---

This glossary defines the terms used across every phase of the CD migration guide. Where a term
has a specific meaning within a migration phase, the relevant phase is noted.

For terms related to agentic continuous delivery, AI agents, and LLMs, see the
Agentic CD Glossary.

## A

### Acceptance Criteria

Concrete expectations for a change, expressed as observable outcomes that can be used as fitness
functions - executed as deterministic tests or evaluated by review [agents](#agent-ai). In
[ACD](#acd-agentic-continuous-delivery), acceptance criteria include a done definition (what
"done" looks like from an observer's perspective) and an evaluation design (test cases with
known-good outputs). They constrain the agent: comprehensive criteria prevent incorrect code
from passing, while shallow criteria allow code that passes tests but violates intent. See
Acceptance Criteria.

Referenced in:
Agent-Assisted Specification,
Agent Delivery Contract,
AI Adoption Roadmap,
AI-Generated Code Ships Without Developer Understanding,
AI Is Generating Technical Debt Faster Than the Team Can Absorb It,
AI Tooling Slows You Down Instead of Speeding You Up,
CD Dependency Tree,
Find Your Symptom,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics,
Rubber-Stamping AI-Generated Code,
Small-Batch Agent Sessions,
Testing Fundamentals,
The Four Prompting Disciplines,
Tokenomics: Optimizing Token Usage in Agent Architecture,
Work Decomposition,
Working Agreements

### ACD (Agentic Continuous Delivery)

See Agentic CD Glossary.

### Agent (AI)

See Agentic CD Glossary.

### Agent Loop

See Agentic CD Glossary.

### Agent Session

See Agentic CD Glossary.

### Artifact

A packaged, versioned output of a build process (e.g., a container image, JAR file, or binary).
In a CD pipeline, artifacts are built once and promoted through environments without
modification. See Immutable Artifacts.

Referenced in:
Agent-Assisted Specification,
Agentic Architecture Patterns,
Agentic Continuous Delivery (ACD),
Build Automation,
Build Duration,
CD for Greenfield Projects,
Coding and Review Agent Configuration,
Data Pipelines and ML Models Have No Deployment Automation,
Deployable Definition,
Deployments Are One-Way Doors,
Deterministic Pipeline,
Developers Cannot Run the Pipeline Locally,
DORA Recommended Practices,
End-to-End Tests,
Every Change Requires a Ticket and Approval Chain,
Experience Reports,
Component Tests,
Independent Teams, Independent Deployables,
Merge Freezes Before Deployments,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
Multiple Teams, Single Deployable,
No Contract Testing Between Services,
No Evidence of What Was Deployed or When,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics,
Rollback,
Single Team, Single Deployable,
Small-Batch Agent Sessions,
The Agentic Development Learning Curve,
The Build Runs Again for Every Environment,
Agent Delivery Contract,
The Team Ignores Alerts Because There Are Too Many,
The Team Is Afraid to Deploy,
Tightly Coupled Monolith,
Tokenomics: Optimizing Token Usage in Agent Architecture,
Working Agreements

## B

### Black Box Testing

See Testing Glossary.

### Baseline Metrics

The set of delivery measurements taken before beginning a migration, used as the benchmark
against which improvement is tracked. See Phase 0 - Baseline Metrics.

Referenced in:
Phase 0: Assess

### Batch Size

The amount of change included in a single deployment. Smaller batches reduce risk, simplify
debugging, and shorten feedback loops. Reducing batch size is a core focus of
Phase 3 - Small Batches.

Referenced in:
CD Dependency Tree,
DORA Recommended Practices,
FAQ,
Hardening Sprints Are Needed Before Every Release,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
New Releases Introduce Regressions in Previously Working Functionality,
Phase 2: Pipeline,
Releases Are Infrequent and Painful,
Small Batches

### BDD (Behavior-Driven Development)

A collaboration practice where developers, testers, and product representatives define expected
behavior using structured examples before code is written. BDD produces executable
specifications that serve as both documentation and automated tests. BDD supports effective
work decomposition by forcing clarity about what a
story actually means before development begins.

Referenced in:
Agent-Assisted Specification,
Agentic Continuous Delivery (ACD),
AI Tooling Slows You Down Instead of Speeding You Up,
CD Dependency Tree,
Coding and Review Agent Configuration,
Getting Started: Where to Put What,
Knowledge & Communication Defects,
Pipeline Enforcement and Expert Agents,
Pitfalls and Metrics,
Small Batches,
Small-Batch Agent Sessions,
TBD Migration Guide,
Agent Delivery Contract,
Work Decomposition

### Blue-Green Deployment

A deployment strategy that maintains two identical production environments. New code is deployed
to the inactive environment, verified, and then traffic is switched. See
Progressive Rollout.

Referenced in:
Every Deployment Is Immediately Visible to All Users,
Process & Deployment Defects

### Branch Lifetime

The elapsed time between creating a branch and merging it to trunk. CD requires branch lifetimes
measured in hours, not days or weeks. Long branch lifetimes are a symptom of poor work
decomposition or slow code review. See Trunk-Based Development.

Referenced in:
AI Adoption Roadmap,
FAQ,
Feedback Takes Hours Instead of Minutes,
Long-Lived Feature Branches,
Merging Is Painful and Time-Consuming,
Metrics-Driven Improvement,
TBD Migration Guide

## C

### Canary Deployment

A deployment strategy where a new version is rolled out to a small subset of users or servers
before full rollout. If the canary shows no issues, the deployment proceeds to 100%. See
Progressive Rollout.

Referenced in:
Change & Complexity Defects,
Pipeline Enforcement and Expert Agents,
Process & Deployment Defects,
Progressive Rollout

### CD (Continuous Delivery)

The practice of ensuring that every change to the codebase is always in a deployable state and
can be released to production at any time through a fully automated pipeline. Continuous
delivery does not require that every change is deployed automatically, but it requires that
every change *could be* deployed automatically. This is the primary goal of this migration
guide.

Referenced in:
Agent-Assisted Specification,
AI Adoption Roadmap,
Agentic Continuous Delivery (ACD),
CD Dependency Tree,
CD for Greenfield Projects,
Change Advisory Board Gates,
Data Pipelines and ML Models Have No Deployment Automation,
Deterministic Pipeline,
DORA Recommended Practices,
Experience Reports,
FAQ,
Feature Flags,
Horizontal Slicing,
Independent Teams, Independent Deployables,
Inverted Test Pyramid,
Knowledge Silos,
Leadership Sees CD as a Technical Nice-to-Have,
Learning Paths,
Long-Lived Feature Branches,
Manual Testing Only,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
Phase 0: Assess,
Phase 1: Foundations,
Phase 2: Pipeline,
Phase 3: Optimize,
Pipeline Enforcement and Expert Agents,
Pipeline Reference Architecture,
Process & Deployment Defects,
Push-Based Work Assignment,
Retrospectives,
Rubber-Stamping AI-Generated Code,
Small Batches,
Team Membership Changes Constantly,
Test Doubles,
Testing Fundamentals,
The Deployment Target Does Not Support Modern CI/CD Tooling,
Thin-Spread Teams,
Tightly Coupled Monolith,
Unit Tests,
Work Decomposition

### Change Failure Rate (CFR)

The percentage of deployments to production that result in a degraded service and require
remediation (e.g., rollback, hotfix, or patch). One of the four DORA metrics. See
Metrics - Change Fail Rate.

Referenced in:
Architecture Decoupling,
CD for Greenfield Projects,
Change Advisory Board Gates,
Experience Reports,
FAQ,
Metrics-Driven Improvement,
Phase 0: Assess,
Pitfalls and Metrics,
Retrospectives

### CI (Continuous Integration)

The practice of integrating code changes to a shared trunk at least once per day, where each
integration is verified by an automated build and test suite. CI is a prerequisite for CD, not
a synonym. A team that runs automated builds on feature branches but merges weekly is not doing
CI. See Build Automation.

Referenced in:
Architecture Decoupling,
CD Dependency Tree,
CD for Greenfield Projects,
Change & Complexity Defects,
Data & State Defects,
Data Pipelines and ML Models Have No Deployment Automation,
Dependency & Infrastructure Defects,
Deterministic Pipeline,
Developers Cannot Run the Pipeline Locally,
Experience Reports,
FAQ,
Feedback Takes Hours Instead of Minutes,
Component Tests,
Integration & Boundaries Defects,
Inverted Test Pyramid,
It Works on My Machine,
Long-Lived Feature Branches,
Manual Testing Only,
Merge Freezes Before Deployments,
Merging Is Painful and Time-Consuming,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
No Evidence of What Was Deployed or When,
Performance & Resilience Defects,
Pipeline Enforcement and Expert Agents,
Pipeline Reference Architecture,
Process & Deployment Defects,
Coding and Review Agent Configuration,
Agentic Architecture Patterns,
Security & Compliance Defects,
Security Review Is a Gate, Not a Guardrail,
Services Reach Production with No Health Checks or Alerting,
Small-Batch Agent Sessions,
Symptoms for Developers,
Test Suite Is Too Slow to Run,
Testing & Observability Gap Defects,
Tests Pass in One Environment but Fail in Another,
Tests Randomly Pass or Fail,
The Development Workflow Has Friction at Every Step,
Unit Tests

### Constraint

In the Theory of Constraints, the single factor most limiting the throughput of a system.
During a CD migration, your job is to find and fix constraints in order of impact. See
Identify Constraints.

Referenced in:
Agent-Assisted Specification,
Agent Delivery Contract,
AI Is Generating Technical Debt Faster Than the Team Can Absorb It,
Baseline Metrics,
Build Automation,
Current State Checklist,
DORA Recommended Practices,
Experience Reports,
FAQ,
Identify Constraints,
Knowledge Silos,
Learning Paths,
Migrate to CD,
Migrating Brownfield to CD,
Multiple Services Must Be Deployed Together,
Phase 0: Assess,
Push-Based Work Assignment,
Releases Are Infrequent and Painful,
Releases Depend on One Person,
Security Review Is a Gate, Not a Guardrail,
Sprint Planning Is Dominated by Dependency Negotiation,
The Agentic Development Learning Curve,
The Four Prompting Disciplines,
Untestable Architecture,
Value Stream Mapping

### Context (LLM)

See Agentic CD Glossary.

### Context Window

See Agentic CD Glossary.

### Context Engineering

See Agentic CD Glossary.

### Continuous Deployment

An extension of continuous delivery where every change that passes the automated pipeline is
deployed to production without manual intervention. Continuous delivery ensures every change
*can* be deployed; continuous deployment ensures every change *is* deployed. See
Phase 4 - Deliver on Demand.

Referenced in:
AI Adoption Roadmap,
Architecture Decoupling,
Change Advisory Board Gates,
DORA Recommended Practices,
Experience Reports,
FAQ,
Feature Flags,
Tightly Coupled Monolith

## D

### Deployable

A change that has passed all automated quality gates defined by the team and is ready for
production deployment. The definition of deployable is codified in the pipeline, not decided
by a person at deployment time. See Deployable Definition.

Referenced in:
CD for Greenfield Projects,
DORA Recommended Practices,
Deployable Definition,
Everything Started, Nothing Finished,
Experience Reports,
FAQ,
Component Tests,
Horizontal Slicing,
Independent Teams, Independent Deployables,
Long-Lived Feature Branches,
Merge Freezes Before Deployments,
Monolithic Work Items,
Multiple Services Must Be Deployed Together,
Multiple Teams, Single Deployable,
Releases Are Infrequent and Painful,
Rubber-Stamping AI-Generated Code,
Small Batches,
Team Alignment to Code,
Trunk-Based Development,
Work Decomposition,
Work Items Take Days or Weeks to Complete,
Working Agreements

### Deployment Frequency

How often an organization successfully deploys to production. One of the four DORA metrics.
See Metrics - Release Frequency.

Referenced in:
Architecture Decoupling,
CD for Greenfield Projects,
Change Advisory Board Gates,
DORA Recommended Practices,
Experience Reports,
Integration Frequency,
Leadership Sees CD as a Technical Nice-to-Have,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
No Contract Testing Between Services,
Phase 0: Assess,
Process & Deployment Defects,
Release Frequency,
Retrospectives,
Single Path to Production,
TBD Migration Guide,
The Team Is Caught Between Shipping Fast and Not Breaking Things,
Tightly Coupled Monolith,
Untestable Architecture

### Development Cycle Time

The elapsed time from the first commit on a change to that change being deployable. This
measures the efficiency of your development and pipeline process, excluding upstream wait times.
See Metrics - Development Cycle Time.

### Dependency

Code, service, or resource whose behavior is not defined in the current module. Dependencies
vary by location and ownership:

- **Internal dependency** - code in another file or module within the same repository, or in
  another repository your team controls. Internal dependencies share your release cycle and
  your team can change them directly.
- **[External dependency](#external-dependency)** - a third-party library, external API, or
  managed service outside your team's direct control.

The distinction matters for testing. Internal dependencies are part of your own codebase and
should be exercised through real code paths in tests. Replacing them with
test doubles couples your tests to
implementation details and causes rippling failures during routine refactoring. Reserve test
doubles for [external dependencies](#external-dependency) and runtime connections where real
invocation is impractical or non-deterministic.

See also: [Hard Dependency](#hard-dependency), [Soft Dependency](#soft-dependency).

Referenced in:
Defect Feedback Loop,
Testing Fundamentals,
The Agentic Development Learning Curve,
Work Decomposition

### Declarative Agent

See Agentic CD Glossary.

### Delivery Contract

See Agentic CD Glossary.

### Done Definition

The observable outcomes portion of [acceptance criteria](#acceptance-criteria). A done definition
describes what "done" looks like from an independent observer's perspective - someone who was
not involved in the implementation. Combined with an evaluation design,
done definitions form the testable boundary of a delivery contract. See
Agent Delivery Contract.

Referenced in:
Agent Delivery Contract,
Agent-Assisted Specification

### DORA Metrics

The four key metrics identified by the DORA (DevOps Research and Assessment) research program
as predictive of software delivery performance: deployment frequency, lead time for changes,
change failure rate, and mean time to restore service. See DORA Recommended Practices.

Referenced in:
CD for Greenfield Projects,
Change Fail Rate,
Development Cycle Time,
DORA Recommended Practices,
Experience Reports,
FAQ,
Lead Time,
Mean Time to Repair,
Metrics-Driven Improvement,
Phase 3: Optimize,
Product & Discovery Defects,
Release Frequency,
Retrospectives,
Small Batches,
Work Decomposition

## E

### External Dependency

A [dependency](#dependency) on code or services outside your team's direct control. External
dependencies include third-party libraries, public APIs, managed cloud services, and any
resource whose release cycle and availability your team cannot influence.

External dependencies are the primary case where test doubles add value. A test double for an
external API verifies your integration logic without relying on network availability or
third-party rate limits. By contrast, mocking internal code - another class in the same
repository or a module your team owns - creates fragile tests that break whenever the internal
implementation changes, even when the behavior is correct.

When evaluating whether to mock something, ask: "Can my team change this code and release it
in our pipeline?" If yes, it is an internal dependency and should be tested through real code
paths. If no, it is an external dependency and a test double is appropriate.

See also: [Dependency](#dependency), [Hard Dependency](#hard-dependency).

Referenced in:
Testing Fundamentals

### Evaluation Design

See Agentic CD Glossary.

### Expert Agent

See Agentic CD Glossary.

## F

### Feature Team

A team organized around user-facing features or customer journeys rather than owned product
subdomains. A feature team is cross-functional - it contains the skills to deliver a feature
end-to-end - but it does not own a stable domain of code. Multiple feature teams may modify
the same components, with no single team accountable for quality or consistency within them.

In practice: feature teams must re-orient on code they do not continuously maintain each time
a feature requires it; quality agreements cannot be enforced within the team because other
teams also modify the same code; and while feature teams appear to minimize inter-team
dependencies, they produce the opposite - everyone who can change a component is effectively
on the same large, loosely communicating team. Feature teams are structurally equivalent to
long-lived project teams.

Contrast with [full-stack product team](#full-stack-product-team) and
[subdomain product team](#subdomain-product-team), which achieve cross-functional delivery
through stable domain ownership rather than feature-by-feature assembly.

Referenced in:
Team Alignment to Code

### Feature Flag

A mechanism that allows code to be deployed to production with new functionality disabled,
then selectively enabled for specific users, percentages of traffic, or environments. Feature
flags decouple deployment from release. See Feature Flags.

Referenced in:
Architecture Decoupling,
CD Dependency Tree,
CD for Greenfield Projects,
Change & Complexity Defects,
Change Advisory Board Gates,
Change Fail Rate,
Database Migrations Block or Break Deployments,
Deploying Stateful Services Causes Outages,
Every Change Requires a Ticket and Approval Chain,
Every Deployment Is Immediately Visible to All Users,
Experience Reports,
FAQ,
Feature Flags,
Hard-Coded Environment Assumptions,
Horizontal Slicing,
Integration Frequency,
Long-Lived Feature Branches,
Mean Time to Repair,
Monolithic Work Items,
Phase 3: Optimize,
Pipeline Enforcement and Expert Agents,
Product & Discovery Defects,
Progressive Rollout,
Rollback,
Single Path to Production,
Small Batches,
TBD Migration Guide,
Teams Cannot Change Their Own Pipeline Without Another Team,
The Team Resists Merging to the Main Branch,
Trunk-Based Development,
Vendor Release Cycles Constrain the Team's Deployment Frequency,
Work Decomposition,
Work Requires Sign-Off from Teams Not Involved in Delivery,
Working Agreements

### Flow Efficiency

The ratio of active work time to total elapsed time in a delivery process. A flow efficiency of
15% means that for every hour of actual work, roughly 5.7 hours are spent waiting. Value stream
mapping reveals your flow efficiency. See Value Stream Mapping.

Referenced in:
Value Stream Mapping

### Full-Stack Product Team

A team that owns every layer of a user-facing capability - UI, API, and data store - and whose
public interface is designed for human users. A vertical slice for a full-stack product team
delivers one observable behavior from the user interface through to the database. The slice is
done when a user can observe the behavior through that interface. Contrast with
[subdomain product team](#subdomain-product-team).

Referenced in:
Horizontal Slicing,
Small Batches,
Work Decomposition

## G

### Guardrail

A safety constraint encoded in a [pipeline](#pipeline), [system prompt](#system-prompt), or
[hook](#hook-agent) that limits what an [agent](#agent-ai) can do. Guardrails are deterministic
boundaries, not suggestions. Examples include pre-commit hooks that block secrets from being
committed, pipeline gates that reject changes exceeding a complexity threshold, and system
prompt rules that prevent an agent from modifying test specifications. Guardrails protect
against both agent errors and [hallucinations](#hallucination) without requiring human
intervention on every change. See
Pipeline Enforcement and Expert Agents.

Referenced in:
AI Adoption Roadmap,
Coding and Review Agent Configuration,
Pipeline Enforcement and Expert Agents,
The Four Prompting Disciplines

### GitFlow

A branching model created by Vincent Driessen in 2010 that uses multiple long-lived branches
(`main`, `develop`, `release/*`, `hotfix/*`, `feature/*`) with specific merge rules and
directions. GitFlow was designed for infrequent, scheduled releases and is fundamentally
incompatible with continuous delivery because it defers integration, creates multiple paths
to production, and adds merge complexity. See the
TBD Migration Guide
for a step-by-step path from GitFlow to trunk-based development.

Referenced in:
Single Path to Production,
TBD Migration Guide,
Trunk-Based Development

## H

### Hard Dependency

A dependency that must be resolved before work can proceed. In delivery, hard dependencies
include things like waiting for another team's API, a shared database migration, or an
infrastructure provisioning request. Hard dependencies create queues and increase lead time.
Eliminating hard dependencies is a focus of
Architecture Decoupling.

Referenced in:
Team Alignment to Code

### Hallucination

See Agentic CD Glossary.

### Hardening Sprint

A sprint dedicated to stabilizing and fixing defects before a release. The existence of
hardening sprints is a strong signal that quality is not being built in during regular
development. Teams practicing CD do not need hardening sprints because every commit is
deployable. See Testing Fundamentals.

Referenced in:
Hardening Sprints Are Needed Before Every Release

### Hook (Agent)

See Agentic CD Glossary.

### Hypothesis-Driven Development

An approach that frames every change as an experiment with a predicted outcome. Instead of
specifying a change as a requirement to implement, the team states a hypothesis: "We believe
[this change] will produce [this outcome] because [this reason]." After deployment, the team
validates whether the predicted outcome occurred. Changes that confirm the hypothesis build
confidence. Changes that refute it produce learning that informs the next hypothesis. This
creates a feedback loop where every deployed change generates a signal, whether it "succeeds"
or not. See Hypothesis-Driven Development
for the full lifecycle and
Agent Delivery Contract
for how hypotheses integrate with specification artifacts.

Referenced in:
Metrics-Driven Improvement,
Agent Delivery Contract,
Agent-Assisted Specification

## I

### Immutable Artifact

A build artifact that is never modified after creation. The same artifact that is tested in the
pipeline is the exact artifact that is deployed to production. Configuration differences between
environments are handled externally. See Immutable Artifacts.

Referenced in:
CD Dependency Tree,
FAQ,
Merge Freezes Before Deployments

### Intent Engineering

See Agentic CD Glossary.

### Integration Frequency

How often a developer integrates code to the shared trunk. CD requires at least daily
integration. See Metrics - Integration Frequency.

Referenced in:
The Team Has No Shared Agreements About How to Work

## L

### Lead Time for Changes

The elapsed time from when a commit is made to when it is successfully running in production.
One of the four DORA metrics. See Metrics - Lead Time.

Referenced in:
Architecture Decoupling,
CD for Greenfield Projects,
Development Cycle Time,
FAQ,
Lead Time,
Leadership Sees CD as a Technical Nice-to-Have,
Manual Testing Only,
Metrics-Driven Improvement,
Phase 0: Assess,
Retrospectives,
Security Review Is a Gate, Not a Guardrail,
Working Agreements

## M

### Mean Time to Restore (MTTR)

The elapsed time from when a production incident is detected to when service is restored. One
of the four DORA metrics. Teams practicing CD have short MTTR because deployments are small,
rollback is automated, and the cause of failure is easy to identify. See
Metrics - Mean Time to Repair.

Referenced in:
Architecture Decoupling,
CD for Greenfield Projects,
Metrics-Driven Improvement,
Retrospectives

### Model Routing

See Agentic CD Glossary.

### Modular Monolith

A single deployable application whose codebase is organized into well-defined modules with
explicit boundaries. Each module encapsulates a bounded domain and communicates with other
modules through defined interfaces, not by reaching into shared database tables or calling
internal methods directly. The application deploys as one unit, but its internal structure
allows teams to reason about, test, and change one module independently. See
Pipeline Reference Architecture and
Premature Microservices.

Referenced in:
Multiple Teams, Single Deployable,
Pipeline Reference Architecture,
Single Team, Single Deployable,
Team Alignment to Code

## O

### Orchestrator

See Agentic CD Glossary.

## P

### Pipeline

The automated sequence of build, test, and deployment stages that every change passes through
on its way to production. See Phase 2 - Pipeline.

Referenced in:
Agentic Continuous Delivery (ACD),
AI Adoption Roadmap,
CD Dependency Tree,
CD for Greenfield Projects,
Change Advisory Board Gates,
Data Pipelines and ML Models Have No Deployment Automation,
Database Migrations Block or Break Deployments,
Deploying Stateful Services Causes Outages,
Deployments Are One-Way Doors,
Deterministic Pipeline,
Developers Cannot Run the Pipeline Locally,
DORA Recommended Practices,
Each Language Has Its Own Ad Hoc Pipeline,
Every Change Rebuilds the Entire Repository,
Every Change Requires a Ticket and Approval Chain,
Every Deployment Is Immediately Visible to All Users,
Experience Reports,
Feedback Takes Hours Instead of Minutes,
Component Tests,
Getting a Test Environment Requires Filing a Ticket,
Getting Started: Where to Put What,
High Coverage but Tests Miss Defects,
Horizontal Slicing,
Independent Teams, Independent Deployables,
Inverted Test Pyramid,
Leadership Sees CD as a Technical Nice-to-Have,
Long-Lived Feature Branches,
Manual Testing Only,
Merge Freezes Before Deployments,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
No Evidence of What Was Deployed or When,
Phase 1: Foundations,
Phase 2: Pipeline,
Phase 3: Optimize,
Pipeline Enforcement and Expert Agents,
Pipeline Reference Architecture,
Pipelines Take Too Long,
Pitfalls and Metrics,
Process & Deployment Defects,
Product & Discovery Defects,
Production Issues Discovered by Customers,
Production Problems Are Discovered Hours or Days Late,
Push-Based Work Assignment,
Retrospectives,
Rubber-Stamping AI-Generated Code,
Coding and Review Agent Configuration,
Agentic Architecture Patterns,
Recommended Patterns for Agentic Workflow Architecture,
Releases Are Infrequent and Painful,
Releases Depend on One Person,
Security Review Is a Gate, Not a Guardrail,
Services in the Same Portfolio Have Wildly Different Maturity Levels,
Services Reach Production with No Health Checks or Alerting,
Small-Batch Agent Sessions,
Testing Fundamentals,
Staging Passes but Production Fails,
Symptoms for Developers,
TBD Migration Guide,
Team Alignment to Code,
Teams Cannot Change Their Own Pipeline Without Another Team,
Test Doubles,
Test Environments Take Too Long to Reset Between Runs,
Test Suite Is Too Slow to Run,
Tests Pass in One Environment but Fail in Another,
Tests Randomly Pass or Fail,
The Agentic Development Learning Curve,
The Build Runs Again for Every Environment,
The Deployment Target Does Not Support Modern CI/CD Tooling,
The Development Workflow Has Friction at Every Step,
Agent Delivery Contract,
The Team Ignores Alerts Because There Are Too Many,
The Team Is Afraid to Deploy,
The Team Is Caught Between Shipping Fast and Not Breaking Things,
The Team Resists Merging to the Main Branch,
Thin-Spread Teams,
Tightly Coupled Monolith,
Tokenomics: Optimizing Token Usage in Agent Architecture,
Vendor Release Cycles Constrain the Team's Deployment Frequency,
Work Requires Sign-Off from Teams Not Involved in Delivery,
Your Migration Journey

### Production-Like Environment

A test or staging environment that matches production in configuration, infrastructure, and
data characteristics. Testing in environments that differ from production is a common source
of deployment failures. See Production-Like Environments.

Referenced in:
CD for Greenfield Projects,
DORA Recommended Practices,
FAQ,
Hard-Coded Environment Assumptions,
Pipeline Enforcement and Expert Agents,
Pipeline Reference Architecture,
Progressive Rollout,
Stakeholders See Working Software Only at Release Time,
TBD Migration Guide

### Prompt

See Agentic CD Glossary.

### Prompt Caching

See Agentic CD Glossary.

### Prompt Craft

See Agentic CD Glossary.

### Prompting Discipline

See Agentic CD Glossary.

### Programmatic Agent

See Agentic CD Glossary.

## R

### Rollback

The ability to revert a production deployment to a previous known-good state. CD requires
automated rollback that takes minutes, not hours. See Rollback.

Referenced in:
CD Dependency Tree,
CD for Greenfield Projects,
Change Advisory Board Gates,
Change Fail Rate,
Data Pipelines and ML Models Have No Deployment Automation,
Database Migrations Block or Break Deployments,
Deployable Definition,
Deployments Are One-Way Doors,
Every Change Requires a Ticket and Approval Chain,
Experience Reports,
Feature Flags,
Horizontal Slicing,
Mean Time to Repair,
Metrics-Driven Improvement,
Missing Deployment Pipeline,
No Deployment Health Checks,
Phase 2: Pipeline,
Pipeline Reference Architecture,
Pitfalls and Metrics,
Process & Deployment Defects,
Production Problems Are Discovered Hours or Days Late,
Progressive Rollout,
Release Frequency,
Releases Depend on One Person,
Single Path to Production,
Symptoms for Developers,
Systemic Defect Fixes,
TBD Migration Guide,
The Team Is Caught Between Shipping Fast and Not Breaking Things,
Tightly Coupled Monolith,
Work Decomposition

### Repository Readiness

See Agentic CD Glossary.

## S

### Skill (Agent)

See Agentic CD Glossary.

### Soft Dependency

A dependency that can be worked around or deferred. Unlike hard dependencies, soft dependencies
do not block work but may influence sequencing or design decisions. Feature flags can turn many
hard dependencies into soft dependencies by allowing incomplete integrations to be deployed in
a disabled state.

### Specification Engineering

See Agentic CD Glossary.

### Story Points

A relative estimation unit used by some teams to forecast effort. Story points are frequently
misused as a productivity metric, which creates perverse incentives to inflate estimates and
discourages the small work decomposition that CD requires. If your organization uses story
points as a velocity target, see Metrics-Driven Improvement.

Referenced in:
Leadership Sees CD as a Technical Nice-to-Have,
Some Developers Are Overloaded While Others Wait for Work,
Team Burnout and Unsustainable Pace,
Velocity as Individual Metric

### Sub-agent

See Agentic CD Glossary.

### Subdomain Product Team

A team that owns a bounded subdomain within a larger distributed system - full-stack within
their service (API, business logic, data store) but not directly user-facing. Their public
interface is designed for machines: other services or teams consume it through a defined API
contract. A vertical slice for a subdomain product team delivers one observable behavior
through that contract. The slice is done when the API satisfies the agreed behavior for its
service consumers. Contrast with [full-stack product team](#full-stack-product-team).

Referenced in:
Horizontal Slicing,
Small Batches,
Work Decomposition

### System Prompt

See Agentic CD Glossary.

## T

### TBD (Trunk-Based Development)

A source-control branching model where all developers integrate to a single shared branch
(trunk) at least once per day. Short-lived feature branches (less than a day) are acceptable.
Long-lived feature branches are not. TBD is a prerequisite for CI, which is in turn a
prerequisite for CD. See Trunk-Based Development.

Referenced in:
Build Automation,
CD Dependency Tree,
CD for Greenfield Projects,
Change & Complexity Defects,
DORA Recommended Practices,
FAQ,
Feature Flags,
Integration Frequency,
Long-Lived Feature Branches,
Metrics-Driven Improvement,
Multiple Teams, Single Deployable,
Phase 1: Foundations,
Process & Deployment Defects,
Retrospectives,
Single Team, Single Deployable,
TBD Migration Guide,
Team Membership Changes Constantly,
The Team Resists Merging to the Main Branch,
Trunk-Based Development,
Work Decomposition,
Work in Progress,
Work Items Take Days or Weeks to Complete,
Working Agreements

### TDD (Test-Driven Development)

See Testing Glossary.

Referenced in:
Testing Fundamentals

### Token

See Agentic CD Glossary.

### Tokenomics

See Agentic CD Glossary.

### Tool Use

See Agentic CD Glossary.

### Toil

Repetitive, manual work related to maintaining a production service that is automatable, has
no lasting value, and scales linearly with service size. Examples include manual deployments,
manual environment provisioning, and manual test execution. Eliminating toil is a primary
benefit of building a CD pipeline.

Referenced in:
AI Adoption Roadmap,
Architecture Decoupling,
Build Duration,
CD Dependency Tree,
Change Advisory Board Gates,
Deployable Definition,
DORA Recommended Practices,
Experience Reports,
Feature Flags,
Lead Time,
Progressive Rollout,
Tightly Coupled Monolith,
Your Migration Journey

## U

### Unplanned Work

Work that arrives outside the planned backlog - production incidents, urgent bug fixes,
ad hoc requests. High levels of unplanned work indicate systemic quality or operational
problems. Teams with high change failure rates generate their own unplanned work through
failed deployments. Reducing unplanned work is a natural outcome of improving change failure
rate through CD practices.

Referenced in:
Team Burnout and Unsustainable Pace,
Thin-Spread Teams

## V

### Virtual Service

See Testing Glossary.

Referenced in:
Test Environments Take Too Long to Reset Between Runs

### Value Stream Map

A visual representation of every step required to deliver a change from request to production,
showing process time, wait time, and percent complete and accurate at each step. The
foundational tool for Phase 0 - Assess.

Referenced in:
FAQ,
Phase 0: Assess

### Vertical Sliced Story

A user story that delivers a thin slice of functionality across all layers of the system
(UI, API, database, etc.) rather than a horizontal slice that implements one layer completely.
Vertical slices are independently deployable and testable, which is essential for CD. Vertical
slicing is a core technique in Work Decomposition.

Referenced in:
Agent-Assisted Specification,
CD Dependency Tree,
CD for Greenfield Projects,
Horizontal Slicing,
Long-Lived Feature Branches,
Monolithic Work Items,
Small Batches,
Small-Batch Agent Sessions,
Sprint Planning Is Dominated by Dependency Negotiation,
Stakeholders See Working Software Only at Release Time

## W

### WIP (Work in Progress)

The number of work items that have been started but not yet completed. High WIP increases lead
time, reduces focus, and increases context-switching overhead. Limiting WIP is a key practice
in Phase 3 - Limiting WIP.

Referenced in:
Architecture Decoupling,
CD Dependency Tree,
Development Cycle Time,
DORA Recommended Practices,
Everything Started, Nothing Finished,
Experience Reports,
Feature Flags,
Metrics-Driven Improvement,
Phase 3: Optimize,
Pitfalls and Metrics,
Push-Based Work Assignment,
Retrospectives,
Retrospectives Produce No Real Change,
Small Batches,
Symptoms for Managers,
TBD Migration Guide,
Team Burnout and Unsustainable Pace,
Team Membership Changes Constantly,
The Team Has No Shared Agreements About How to Work,
Tokenomics: Optimizing Token Usage in Agent Architecture,
Work Decomposition,
Work in Progress,
Working Agreements

### White Box Testing

See Testing Glossary.

### Working Agreement

An explicit, documented set of team norms covering how work is defined, reviewed, tested, and
deployed. Working agreements create shared expectations and reduce friction. See
Working Agreements.

Referenced in:
AI Tooling Slows You Down Instead of Speeding You Up,
Pull Requests Sit for Days Waiting for Review,
Rubber-Stamping AI-Generated Code,
The Team Has No Shared Agreements About How to Work

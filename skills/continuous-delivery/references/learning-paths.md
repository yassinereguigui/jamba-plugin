---
title: "Learning Paths"
description: >
  Curated reading paths through the CD Migration Guide, organized by role and goal.
  Follow a path end-to-end or jump in at the step that matches where your team is today.
weight: 16
---

The CD Migration Guide covers a lot of ground. These paths cut through it by role and goal,
giving you a sequenced route from your current pain to a concrete improvement. Each path is
self-contained - you do not need to read the whole guide to follow one.

---

## Path 1: Fix our testing strategy

**Audience:** Developer | **Time investment:** 4-6 weeks of reading and practice

Your test suite is costing you more than it helps. Runs are slow, failures are random, and bugs
still reach production despite high coverage. This path takes you from recognizing the symptoms
to understanding the root causes, then gives you the fix guide and the structural changes that
prevent recurrence.

1. Tests Randomly Pass or Fail - confirm the symptom
2. Slow Test Suites - related pain
3. Inverted Test Pyramid - root cause
4. Manual Testing Only - root cause
5. Testing Fundamentals - fix guide
6. Testing and Observability Gaps - prevent recurrence
7. Pipeline Reference Architecture - quality gate placement

---

## Path 2: Build the case for CD adoption

**Audience:** Manager | **Time investment:** 1-2 hours

You suspect the team has a delivery problem but need to name it clearly and connect it to
evidence before proposing changes. This path helps you identify which symptoms apply to your
situation, attach a cost to them, find the root cause in your process, and then point to
research-backed capabilities and a concrete starting step.

1. For Managers - identify your team's symptoms
2. Infrequent Releases - quantify the cost
3. Missing Deployment Pipeline - name the root cause
4. CAB Approval Gates - address the process gap
5. DORA Recommended Practices - the research backing
6. Phase 0 - Assess - start here with your team
7. Baseline Metrics - measure before you change

---

## Path 3: Migrate a struggling brownfield team

**Audience:** Tech Lead | **Time investment:** Ongoing over the migration

Your team has an existing system, existing habits, and real constraints. A greenfield guide
will not help you here. This path starts with diagnostic framing, walks through the full
phased migration from assess through optimize, and closes with the defect source catalog so
you understand what you are structurally preventing as you build each capability.

1. Start Here - diagnostic framing
2. Triage Your Symptoms - interactive diagnostic
3. Brownfield Migration - context for existing systems
4. Phase 0 - Assess - value stream and baselines
5. Phase 1 - Foundations - trunk, tests, build
6. Phase 2 - Pipeline - automation path
7. Phase 3 - Optimize - flow and metrics
8. Systemic Defect Sources - understand what you are preventing

---

## Path 4: Adopt agentic CD practices

**Audience:** Developer or Tech Lead | **Time investment:** 2-4 hours of reading, then ongoing practice

AI agents writing and submitting code are a new kind of contributor with a different failure
profile. This path explains what changes with agents in the loop, walks through the constraint
model and workflow architecture, and then covers the concrete setup, session discipline, and
quality gates needed to keep agent output safe to ship.

1. Agentic CD Overview - what changes with AI agents
2. Agent Delivery Contract - the constraint model
3. Agentic Architecture - skills, agents, hooks
4. Agent Configuration - concrete setup
5. Small-Batch Sessions - discipline for agent work
6. Pipeline Enforcement - quality gates for agent output
7. Pitfalls and Metrics - what goes wrong and how to measure

---

## Already in progress?

If your team is partway through a migration, jump in at the relevant phase:

- Phase 0 - Assess - you know something is wrong but have not measured it yet
- Phase 1 - Foundations - you have committed to CD but lack the basics
- Phase 2 - Pipeline - you have basics in place and need a reliable automated path
- Phase 3 - Optimize - your pipeline works but flow is still slow or unreliable
- Phase 4 - Continuous Deployment - you deploy frequently and want to remove the last manual gates

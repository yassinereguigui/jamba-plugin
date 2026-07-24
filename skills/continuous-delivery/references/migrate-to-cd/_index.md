---
title: "Migrate to CD"
linkTitle: "Migrate to CD"
weight: 6
sidebar_divider_above: true
description: >
  A phased approach to adopting continuous delivery, from assessing your current state through delivering on demand.
---

Continuous delivery gives teams low-risk releases, faster time to market, higher quality, and
reduced burnout. Choose the path that matches your situation. Brownfield teams migrating
existing systems and greenfield teams building from scratch each have a dedicated guide. The
phases below provide the roadmap both approaches follow. CD adoption involves the whole
team: product, development, operations, and leadership.

## The Phases

| Phase | Focus | Key Question |
|-------|-------|-------------|
| 0 - Assess | Understand your current state | How far are we from CD? |
| 1 - Foundations | Daily integration, testing, small batches, stop on red | Can we integrate safely every day? |
| 2 - Pipeline | Automated path from commit to production, security scanning | Can we deploy any commit automatically? |
| 3 - Optimize | Reduce batch size, limit WIP, observability, measure | Can we deliver small changes quickly? |
| 4 - Deliver on Demand | Deploy any change when the business needs it | Can we deliver any change to production when needed? |

These phases are a starting framework, not a finish line. Teams that reach Phase 4 continue
improving by revisiting practices, tightening feedback loops, and adapting to new constraints.
Most teams work across multiple phases at once - beginning Phase 2 pipeline work while still
maturing Phase 1 foundations is normal and expected. The phases describe what to prioritize, not
a strict sequence to complete before advancing.

## Why CD Adoption Stalls

The most important thing to understand before starting: infrequent deployment is self-reinforcing.
When teams deploy rarely, each deployment is large. Large deployments are risky. Risky deployments
fail more often. Failures reinforce the belief that deployment is dangerous. So teams deploy even
less often.

This is a feedback loop, not a fact about your system. CD breaks it by making each change smaller
and the deployment path more reliable. But the loop explains why the early phases feel hard: you
are working against the momentum of a system that has been running in the opposite direction.
Expect friction. It is evidence you are changing the right thing.

## Conditions for Success

Technical practices alone are not enough. CD adoption succeeds when leaders understand that the
practices in this guide are the investment, not the delay. Specifically:

- **Approval processes and change windows** are often the last constraint in Phase 4. These are
  organizational structures, not technical ones. Leadership needs to own removing them.
- **Success metrics matter.** If teams are measured on feature throughput, they will consistently
  deprioritize foundational work. Leaders who want CD outcomes need to measure delivery stability
  alongside delivery speed - from the start.
- **One team first.** CD adoption works best when a single team can experiment and demonstrate
  results without waiting for organizational consensus. Give that team cover to move slower on
  features while building the capability.

## Where to Start

If you are unsure where to begin, start with Phase 0: Assess to understand your
current state and identify the constraints holding you back.

---

## Related Content

- For Developers - Common pain points developers face before CD adoption
- For Managers - How delivery problems appear from a management perspective
- Brownfield CD - Migrating an existing system
- Greenfield CD - Building CD from day one
- FAQ - Frequently asked questions about continuous delivery
- DORA Recommended Practices - The research-backed capabilities that drive delivery performance

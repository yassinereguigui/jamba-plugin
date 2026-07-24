---
title: "Trunk-Based Development"
linkTitle: "Trunk-Based Development"
weight: 1
description: >
  Integrate all work to the trunk at least once per day to enable continuous integration.
---

**Phase 1 - Foundations** | 

Trunk-based development is the first foundation to establish. Without daily integration to a shared trunk, the rest of the CD migration cannot succeed. This page covers the core practice, two migration paths, and a tactical guide for getting started.

## What Is Trunk-Based Development?

Trunk-based development (TBD) is a branching strategy where all developers integrate their work into a single shared branch - the trunk - at least once per day. The trunk is always kept in a releasable state.

This is a **non-negotiable prerequisite for continuous delivery**. If your team is not integrating to trunk daily, you are not doing CI, and you cannot do CD. There is no workaround.

> "If it hurts, do it more often, and bring the pain forward."
>
> - Jez Humble, *Continuous Delivery*

### What TBD Is Not

- It is **not** "everyone commits directly to `main` with no guardrails." You still test, review, and validate work - you just do it in small increments.
- It is **not** incompatible with code review. It requires review to happen quickly.
- It is **not** reckless. It is the opposite: small, frequent integrations are far safer than large, infrequent merges.

## What Trunk-Based Development Improves

| Problem | How TBD Helps |
|---------|---------------|
| Merge conflicts | Small changes integrated frequently rarely conflict |
| Integration risk | Bugs are caught within hours, not weeks |
| Long-lived branches diverge from reality | The trunk always reflects the current state of the codebase |
| "Works on my branch" syndrome | Everyone shares the same integration point |
| Slow feedback | CI runs on every integration, giving immediate signal |
| Large batch deployments | Small changes are individually deployable |
| Fear of deployment | Each change is small enough to reason about |

## Two Migration Paths

There are two valid approaches to trunk-based development. Both satisfy the minimum CD requirement of daily integration. Choose the one that fits your team's current maturity and constraints.

### Path 1: Short-Lived Branches

Developers create branches that live for **less than 24 hours**. Work is done on the branch, reviewed quickly, and merged to trunk within a single day.

**How it works:**

1. Pull the latest trunk
2. Create a short-lived branch
3. Make small, focused changes
4. Open a pull request (or use pair programming as the review)
5. Merge to trunk before end of day
6. The branch is deleted after merge

**Best for teams that:**

- Currently use long-lived feature branches and need a stepping stone
- Have regulatory requirements for traceable review records
- Use pull request workflows they want to keep (but make faster)
- Are new to TBD and want a gradual transition

**Key constraint:** The branch must merge to trunk within 24 hours. If it does not, you have a long-lived branch and you have lost the benefit of TBD.

### Path 2: Direct Trunk Commits

Developers commit directly to trunk. Quality is ensured through pre-commit checks, pair programming, and strong automated testing.

**How it works:**

1. Pull the latest trunk
2. Make a small, tested change locally
3. Run the local build and test suite
4. Push directly to trunk
5. CI validates the commit immediately

**Best for teams that:**

- Have strong automated test coverage
- Practice pair or mob programming (which provides real-time review)
- Want maximum integration frequency
- Have high trust and shared code ownership

**Key constraint:** This requires excellent test coverage and a culture where the team owns quality collectively. Without these, direct trunk commits become reckless.

## How to Choose Your Path

Ask these questions:

1. **Do you have automated tests that catch real defects?** If no, start with Path 1 and invest in testing fundamentals in parallel.
2. **Does your organization require documented review approvals?** If yes, use Path 1 with rapid pull requests.
3. **Does your team practice pair programming?** If yes, Path 2 may work immediately - pairing is a continuous review process.
4. **How large is your team?** Teams of 2-4 can adopt Path 2 more easily. Larger teams may start with Path 1 and transition later.

Both paths are valid. The important thing is **daily integration to trunk**. Do not spend weeks debating which path to use. Pick one, start today, and adjust.

## Essential Supporting Practices

Trunk-based development does not work in isolation. These practices make daily integration safe:

- **Feature flags:** Merge incomplete work without exposing it to users.
- **Branch by abstraction:** Replace implementations behind stable interfaces without long-lived branches.
- **Connect last:** Build new code paths without wiring them in until they are complete.
- **Small, atomic commits:** Each commit is a single logical change that leaves trunk releasable.
- **TDD/ATDD:** Tests written before code provide the safety net for frequent integration.

The TBD Migration Guide covers each practice in detail with code examples.

## Getting Started

Start by shortening branch lifetimes, then tighten to daily integration. The TBD Migration Guide walks through each step with team agreements, metrics, and retrospective checkpoints.

## Common Pitfalls

Teams migrating to TBD commonly stumble on slow CI builds, incomplete feature flags, and treating branch renaming as real integration. See Common Pitfalls to Avoid for detailed guidance and fixes.

## Measuring Success

Track these metrics to verify your TBD adoption:

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| Integration frequency | At least 1 per developer per day | Confirms daily integration is happening |
| Branch age | < 24 hours | Catches long-lived branches |
| Build duration | < 10 minutes | Enables frequent integration without frustration |
| Merge conflict frequency | Decreasing over time | Confirms small changes reduce conflicts |

## Next Step

Once your team is integrating to trunk daily, build the test suite that makes that integration trustworthy. Continue to Testing Fundamentals.

## Related Content

- TBD Migration Guide - Detailed scenarios including regulated environments, multi-team environments, and advanced pitfalls
- Trunk-Based Development - Practice definition and minimum criteria
- [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com) - Comprehensive reference by Paul Hammant
- Painful Merges - Symptom eliminated by integrating to trunk daily
- Merge Freeze - Symptom caused by long-lived branches and infrequent integration
- No Fast Feedback - Symptom that daily integration and CI address directly
- Long-Lived Feature Branches - Anti-pattern that TBD replaces
- Integration Deferred - Anti-pattern where integration is postponed until late in development
- Integration Frequency - Key metric for tracking TBD adoption

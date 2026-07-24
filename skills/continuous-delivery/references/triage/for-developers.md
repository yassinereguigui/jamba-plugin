---
title: "Symptoms for Developers"
linkTitle: "For Developers"
weight: 3
aliases:
  - /docs/symptoms/for-developers/
description: >
  Dysfunction symptoms grouped by the friction developers and tech leads experience - from daily
  coding pain to team-level delivery patterns.
---

These are the symptoms you experience while writing, testing, and shipping code. Some you feel
personally. Others you see as patterns across the team. If something on this list sounds
familiar, follow the link to find what is causing it and how to fix it.

## Pushing code and getting feedback

- **Pipelines Take Too Long** - You push a change, then wait 30 minutes or more to find out if it passed. Pipeline duration limits how often the team can integrate.
- **Feedback Takes Hours Instead of Minutes** - You do not learn whether a change works until long after you wrote it. Developers batch changes to avoid the wait.
- **Pull Requests Sit for Days Waiting for Review** - Your PR is ready, but no one reviews it for days. You start another branch. Now you have two things in flight and neither is done.

## Tests getting in the way

- **Tests Randomly Pass or Fail** - You click rerun without investigating because flaky failures are so common. The team ignores failures by default, which masks real regressions.
- **Refactoring Breaks Tests** - You rename a method or restructure a class and 15 tests fail, even though the behavior is correct. Technical debt accumulates because cleanup is too expensive.
- **Test Suite Is Too Slow to Run** - Running tests locally is so slow that you skip it and push to CI instead, trading fast feedback for a longer loop.
- **High Coverage but Tests Miss Defects** - Coverage is above 80% but bugs still make it to production. The tests check that code runs, not that it works correctly.
- **A Large Codebase Has No Automated Tests** - No automated tests means every change is risky and slow. Manual testing cannot keep up with delivery pace.
- **Tests Interfere with Each Other Through Shared Data** - Shared test data causes tests to fail unpredictably. You cannot trust the results without re-running.
- **Test Environments Take Too Long to Reset** - Resetting takes so long that you skip local runs or batch changes to avoid the wait.

## Integrating and merging

- **Merging Is Painful and Time-Consuming** - Your branch has diverged so far from main that merging takes hours of conflict resolution.
- **Everything Started, Nothing Finished** - The board is full of in-progress items but the done column is empty. The team is busy but throughput is low.
- **Work Items Take Days or Weeks to Complete** - Cycle time is long and unpredictable. Items sit in progress for days because they are too large or blocked by dependencies.

## Deploying and releasing

- **The Team Is Afraid to Deploy** - Deployments are treated as high-risk events requiring full-team attention. The team deploys less often, which makes each deployment larger and riskier.
- **Releases Are Infrequent and Painful** - Releases happen monthly or quarterly and require significant coordination, manual testing, and rollback plans.
- **Merge Freezes Before Deployments** - The team stops merging to stabilize before each release, creating artificial bottlenecks and deferred work.
- **Hardening Sprints Are Needed Before Every Release** - A dedicated stabilization period is needed before every release because the normal process does not produce releasable code.
- **Multiple Services Must Be Deployed Together** - Services are coupled so that deploying one requires deploying others at the same time.
- **Database Migrations Block or Break Deployments** - Schema changes couple deployments to manual coordination and downtime windows.
- **API Changes Break Consumers Without Warning** - Changing an API breaks downstream services because there are no contracts or versioning.
- **Deployments Are One-Way Doors** - There is no fast rollback, so every deployment carries irreversible risk.

## Environment and production surprises

- **It Works on My Machine** - Code passes all your local tests but fails in CI or production. You cannot reproduce the problem locally.
- **Tests Pass in One Environment but Fail in Another** - The same test produces different results depending on where it runs.
- **Staging Passes but Production Fails** - The staging environment gives false confidence. Problems that staging should catch reach production.
- **Production Issues Discovered by Customers** - The team learns about production problems from customer reports instead of monitoring.
- **Production Problems Are Discovered Hours or Days Late** - Incidents are not detected until the impact has already accumulated.
- **Setting Up a Development Environment Takes Days** - Onboarding friction and undocumented setup steps waste developer time before any code is written.
- **Getting a Test Environment Requires Filing a Ticket** - Developers cannot self-serve environments, creating wait time before any testing.
- **When Something Breaks, Nobody Knows What to Do** - Incident response is chaotic because there are no runbooks or clear ownership.
- **The Team Ignores Alerts Because There Are Too Many** - Alert noise trains developers to ignore monitoring, masking real incidents.

See Learning Paths for a structured reading sequence if you want a guided path through diagnosis and fixes.

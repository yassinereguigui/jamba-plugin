---
title: "Phase 1: Foundations"
linkTitle: "1 - Foundations"
weight: 2
description: >
  Establish the essential practices for daily integration, testing, and small work decomposition.
---

**Key question:** "Can we integrate safely every day?"

This phase establishes the development practices that make continuous delivery possible.
Without these foundations, pipeline automation just speeds up a broken process.

## What You'll Do

1. **Adopt trunk-based development** - Integrate to trunk at least daily
2. **Build testing fundamentals** - Create a fast, reliable test suite
3. **Automate your build** - One command to build, test, and package
4. **Decompose work** - Break features into small, deliverable increments
5. **Streamline code review** - Fast, effective review that doesn't block flow
6. **Establish working agreements** - Shared definitions of done and ready
7. **Everything as code** - Version-control everything that defines your system: infrastructure, pipelines, schemas, monitoring, and security policies

## Why This Phase Matters

Teams that skip these foundations end up automating a broken process. A pipeline that deploys untested code from long-lived branches does not improve delivery. It amplifies risk. These practices ensure that what enters the pipeline is already safe to ship.

## When You're Ready to Move On

Start investing in Phase 2: Pipeline when you are making
consistent progress toward these - don't wait for every criterion to be perfect:

- All developers integrate to trunk at least once per day
- Your test suite catches real defects and runs in under 10 minutes
- You can build and package your application with a single command
- Most work items can be completed within 2 days

**Next:** Phase 2 - Pipeline - build a single automated path from commit to production.

---

## Related Content

- Phase 0: Assess - The assessment phase that precedes Foundations
- Phase 2: Pipeline - The next phase after establishing foundations
- DORA Recommended Practices - Research-backed capabilities that drive delivery performance
- No Fast Feedback - Symptom that foundational practices address
- Works on My Machine - Symptom eliminated by build automation and testing foundations
- Deployment Frequency - Key metric that improves as foundations mature

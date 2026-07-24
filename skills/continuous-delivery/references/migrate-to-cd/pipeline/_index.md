---
title: "Phase 2: Pipeline"
linkTitle: "2 - Pipeline"
weight: 3
description: >
  Build the automated path from commit to production: a single, deterministic pipeline that deploys immutable artifacts.
---

**Key question:** "Can we deploy any commit automatically?"

This phase creates the delivery pipeline - the automated path that takes every commit
through build, test, and deployment stages. When done right, the pipeline is the only
way changes reach production.

## What You'll Do

1. **Establish a single path to production** - One pipeline for all changes
2. **Make the pipeline deterministic** - Same inputs always produce same outputs
3. **Define "deployable"** - Clear criteria for what's ready to ship
4. **Use immutable artifacts** - Build once, deploy everywhere
5. **Externalize application config** - Separate config from code
6. **Use production-like environments** - Test in environments that match production
7. **Design your pipeline architecture** - Efficient quality gates for your context
8. **Enable rollback** - Fast recovery from any deployment
9. **Integrate security scanning** - Dependency checks, secret detection, and static analysis as pipeline quality gates

## Why This Phase Matters

The pipeline is the backbone of continuous delivery. It replaces manual handoffs with
automated quality gates, ensures every change goes through the same validation process,
and makes deployment a routine, low-risk event.

## When You're Ready to Move On

Start investing in Phase 3: Optimize when you are making
consistent progress toward these - don't wait for every criterion to be perfect:

- Every change reaches production through the same automated pipeline
- The pipeline produces the same result for the same inputs
- You can deploy any green build to production with confidence
- Rollback takes minutes, not hours

**Next:** Phase 3 - Optimize - reduce batch size, improve flow, and make deployment routine.

---

## Related Content

- Phase 1: Foundations - prerequisites to complete before starting the Pipeline phase
- Phase 3: Optimize - the next phase after Pipeline is established
- Slow Pipelines - a common symptom that pipeline architecture improvements address
- Fear of Deploying - a cultural symptom that reliable rollback and automated pipelines help resolve
- Missing Deployment Pipeline - the anti-pattern this entire phase eliminates
- DORA Recommended Practices - industry-recognized capabilities that pipeline practices support
- Pipeline Reference Architecture - concrete quality gate patterns organized by defect detection priority.

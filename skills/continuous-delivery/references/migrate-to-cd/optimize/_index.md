---
title: "Phase 3: Optimize"
linkTitle: "3 - Optimize"
weight: 4
description: >
  Improve flow by reducing batch size, limiting work in progress, and using metrics to drive improvement.
---

**Key question:** "Can we deliver small changes quickly?"

With a working pipeline in place, this phase focuses on optimizing the flow of changes
through it. Smaller batches, feature flags, and WIP limits reduce risk and increase
delivery frequency.

## What You'll Do

1. **Reduce batch size** - Deliver smaller, more frequent changes
2. **Use feature flags** - Decouple deployment from release
3. **Limit work in progress** - Focus on finishing over starting
4. **Drive improvement with metrics** - Use the DORA metrics you baselined in Phase 0 to measure improvement and run improvement kata
5. **Run effective retrospectives** - Continuously improve the delivery process
6. **Decouple architecture** - Enable independent deployment of components
7. **Align teams to code** - Match team ownership to code boundaries for independent deployment
8. **Build observability** - Structured logging, monitoring, and alerting so you can detect problems and recover quickly

## Why This Phase Matters

Having a pipeline isn't enough. You need to optimize the flow through it. Teams that
deploy weekly with a CD pipeline are missing most of the benefits. Small batches reduce
risk, feature flags enable testing in production, and metrics-driven improvement creates
a virtuous cycle of getting better at getting better.

## When You're Ready to Move On

Start investing in Phase 4: Deliver on Demand when
you are making consistent progress toward these - don't wait for every criterion to be perfect:

- Most changes are small enough to deploy independently
- Feature flags let you deploy incomplete features safely
- Your WIP limits keep work flowing without bottlenecks
- You're reviewing and acting on your DORA metrics regularly

**Next:** Phase 4 - Deliver on Demand - remove the last manual gates and deploy on demand.

---

## Related Content

- Phase 2: Pipeline - the previous phase that establishes the deployment pipeline this phase optimizes
- Phase 4: Deliver on Demand - the next phase after flow is optimized
- Infrequent Releases - a key symptom that the Optimize phase addresses
- Too Much WIP - a flow symptom targeted by WIP limits and small batches
- DORA Recommended Practices - the research-backed capabilities that drive delivery performance
- Deployment Frequency - the primary metric that improves as optimization takes hold

---
title: "CD Practices"
linkTitle: "Practices"
weight: 10
description: >
  Concise definitions of the core continuous delivery practices from MinimumCD.
---

These pages define the minimum practices required for [continuous delivery](../glossary/#cd-continuous-delivery). Each page covers
what the practice is, why it matters, and what the minimum criteria are. For migration
guidance and tactical how-to content, follow the links to the corresponding phase pages.

## Core Practices

- **Continuous Integration** - Integrate work to trunk at least daily with automated testing
- **Trunk-Based Development** - All changes integrate into a single shared trunk
- **Single Path to Production** - One automated [pipeline](../glossary/#pipeline) for all changes to reach any environment
- **Deterministic Pipeline** - Same inputs always produce the same outputs
- **Definition of Deployable** - Automated criteria that determine production readiness
- **Immutable Artifacts** - Build once, deploy everywhere without modification
- **Production-Like Environments** - Test in environments that mirror production
- **Rollback** - Fast, automated recovery from any deployment
- **Application Configuration** - Separate what varies between environments from what does not

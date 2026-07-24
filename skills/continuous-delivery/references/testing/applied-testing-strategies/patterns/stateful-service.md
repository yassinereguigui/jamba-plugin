---
title: "Stateful Service"
linkTitle: "Stateful Service"
weight: 8
description: >
  A service that maintains long-lived in-memory state: caches, in-memory aggregates, leader-elected coordinators, websocket gateways, real-time engines. Brief sketch.
---

A service that maintains long-lived in-memory state: caches, in-memory aggregates, leader-elected coordinators, websocket gateways, real-time engines, sticky-session servers.

The hard problems are concurrency, recovery, and unbounded growth. Stateful services fail in ways stateless services do not.

## What needs covered

| Layer | Concern | Test type |
| --- | --- | --- |
| State machine logic | Pure transitions | Solitary unit tests |
| Persistence and checkpointing | State survives restart or rebuilds correctly | Component tests with real persistence |
| Recovery from crash | Restart converges to a consistent state | Component tests that simulate crash mid-write |
| Leader election | Only one leader; transitions are observable; split-brain is impossible | Cluster tests with real consensus library |
| Replication | Followers stay in sync; backpressure is documented | Cluster tests |
| Memory bounds | State doesn't grow unbounded; eviction policy holds | Long-running soak tests |
| Connection lifecycle | Sessions clean up on disconnect; reconnect is documented | Component tests |

## Positive test cases

Common cases to consider, not an exhaustive list. Drop items that don't apply and add ones the pattern doesn't mention but your component needs.

- **State transitions**: follow the documented machine.
- **Restart**: state rebuilds and behavior matches pre-restart.
- **Replication lag under expected load**: stays within budget.

## Negative test cases

Common cases to consider, not an exhaustive list. Drop items that don't apply and add ones the pattern doesn't mention but your component needs.

- **Crash mid-write**: consistent state on restart. No torn writes.
- **Network partition**: minority replicas step down with documented reconciliation on heal.
- **Slow replication**: applies backpressure rather than silent divergence.
- **Memory pressure**: evicts oldest entries per policy without OOM.
- **Idle long-running connections**: close cleanly with documented reconnect behavior.
- **Concurrent state mutations**: serialize without lost updates.

## Test double validation

Persistence doubles validated by adapter integration tests against the real production engine. Consensus library doubles validated by cluster tests against a multi-node testcontainer setup. Soak tests run out of pipeline against a deployed instance to catch slow leaks and unbounded growth.

## Pipeline placement

State machine unit tests, recovery component tests, and single-node concurrency tests run in CI Stage 1; cluster tests with real consensus library in CI Stage 2; soak and chaos tests out of pipeline.

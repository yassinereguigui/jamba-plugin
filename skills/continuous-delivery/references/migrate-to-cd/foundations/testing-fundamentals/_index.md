---
title: "Testing Fundamentals"
linkTitle: "Testing Fundamentals"
weight: 2
description: >
  Build a test architecture that gives your pipeline the confidence to deploy any change, even when dependencies outside your control are unavailable.
---

**Phase 1 - Foundations** | 

Continuous delivery requires that trunk always be releasable, which means testing it automatically on every change. A collection of tests is not enough. You need a **test architecture**: different test types working together so the pipeline can confidently deploy any change, even when external systems are unavailable.

## Testing Goals for CD

Your test suite must meet these goals before it can support continuous delivery.

| Goal | Target | How to Measure |
|------|--------|----------------|
| **Fast** | CI gating tests < 10 minutes; full acceptance suite < 1 hour | CI gating suite duration; full acceptance suite duration |
| **Deterministic** | Same code always produces the same result | Flaky test count: 0 in the gating suite |
| **Catches real bugs** | Tests fail when behavior is wrong, not when implementation changes | Defect escape rate trending down |
| **Independent of external systems** | Pipeline can determine deployability without any dependency being available | External dependencies in gating tests: 0 |
| **Test doubles stay current** | Contract tests confirm test doubles match reality | All contract tests passing within last 24 hours |
| **Coverage trends up** | Every new change gets a test | Coverage percentage increasing over time |

## In This Section

| Page | What You'll Learn |
|------|-------------------|
| What to Test | Which boundaries matter and how to eliminate external dependencies from your pipeline |
| Pipeline Test Strategy | What tests run where in a CD pipeline and how contract tests validate test doubles |
| Getting Started | Audit your current suite, fix flaky tests, and decouple from external systems |
| Defect Feedback Loop | Trace defects to their origin and prevent entire categories of bugs |

## The Ice Cream Cone: What to Avoid

An inverted test distribution, with too many slow end-to-end tests and too few fast unit tests, is the most common testing barrier to CD.

The ice cream cone makes CD impossible. Manual testing gates block every release. End-to-end tests
take hours, fail randomly, and depend on external systems being healthy. For the test architecture
that replaces this, see Pipeline Test Strategy
and the Testing reference.

## Next Step

Automate your build process so that building, testing, and packaging happen with a single command. Continue to Build Automation.

---

Content contributed by [Dojo Consortium](https://dojoconsortium.org), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Additional concepts drawn from Ham Vocke, [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html), and Toby Clemson, [Testing Strategies in a Microservice Architecture](https://martinfowler.com/articles/microservice-testing/).

---

## Related Content

- Flaky Tests - Symptom of non-deterministic tests that destroy pipeline trust
- High Coverage, Ineffective Tests - Symptom where coverage metrics mask poor test quality
- Refactoring Breaks Tests - Symptom of white-box tests that assert on implementation details
- Slow Test Suites - Symptom caused by an inverted test pyramid or missing test doubles
- Environment-Dependent Failures - Symptom of tests coupled to external systems
- Inverted Test Pyramid - Anti-pattern where too many slow E2E tests replace fast unit tests
- Pressure to Skip Testing - Anti-pattern where testing is treated as optional under deadline pressure

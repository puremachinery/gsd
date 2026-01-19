# Testing Template

Template for `.planning/codebase/TESTING.md` - captures how tests are structured and run.

**Purpose:** Document how testing works in this codebase.

---

## File Template

```markdown
# Testing

**Analysis Date:** [YYYY-MM-DD]

## Test Frameworks

**Unit Tests:**
- [Framework] [Version]
- [Command: e.g., "run-tests"]

**Integration Tests:**
- [Framework] [Version]
- [Command]

**E2E Tests:**
- [Framework] [Version]
- [Command]

## Test Locations

- Unit tests: [paths]
- Integration tests: [paths]
- E2E tests: [paths]
- Fixtures: [paths]

## Test Conventions

- Naming: [e.g., "*.test.ext", "*_test.ext"]
- Structure: [arrange/act/assert]
- Setup/Teardown: [beforeEach/afterEach equivalents]

## Mocking

- Tooling: [mocking library or built-in]
- Patterns: [how mocks are created]
- What to mock: [external services, file system, time]
- What NOT to mock: [pure functions, core logic]

## Coverage & CI

- Coverage target: [if any]
- CI gates: [tests required for merge]
- Flaky tests: [known issues]

---

*Testing analysis: [date]*
*Update when testing strategy changes*
```

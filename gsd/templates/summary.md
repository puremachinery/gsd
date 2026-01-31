# Summary Template

The gsd-executor agent creates summaries after completing plans.

## Structure

```markdown
---
phase: [NN]-[name]
plan: [NN]
subsystem: [category]      # e.g., auth, ui, data
tags: [tech keywords]

# Dependency graph
requires: []               # prior phases this built upon
provides: []               # what was delivered
affects: []                # future phases that need this

# Tech tracking
tech-stack:
  added: []                # new libraries
  patterns: []             # architectural patterns established

# File tracking
key-files:
  created: []
  modified: []

# Decisions
decisions:
  - id: [DEC-NN]
    choice: [what was decided]
    rationale: [why]

# Metrics
metrics:
  duration: [time]
  completed: [YYYY-MM-DD]
---

# Phase [NN] Plan [MM]: [Name] Summary

**One-liner:** [Substantive description of what shipped]

## What Shipped

- [Accomplishment 1]
- [Accomplishment 2]

## Decisions Made

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| [Choice] | [Why] | [Result] |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule N - Type] [Description]**
- Found during: Task [N]
- Issue: [what was wrong]
- Fix: [what was done]
- Files: [affected files]
- Commit: [hash]

Or: "None — plan executed as written."

## Authentication Gates

(If any occurred during execution)

1. Task [N]: [Service] required authentication
   - Paused for [auth command]
   - Resumed after authentication

## Follow-ups

- [Item for future work]

## Next Phase Readiness

- [ ] [Prerequisite for next phase]
```

## Guidelines

- One-liner must be substantive: "Token auth with refresh rotation" not "Auth done"
- Document all deviations with rule number and category
- Frontmatter enables dependency graph queries across phases

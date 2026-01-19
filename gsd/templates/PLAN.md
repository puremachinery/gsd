# Plan Template

Plans are executable prompts. The gsd-planner agent creates plans following this structure.

## Structure

```markdown
---
phase: [NN]-[name]
plan: [NN]
type: execute              # or "tdd" for test-driven plans
wave: [N]                  # execution wave (1, 2, 3...)
depends_on: []             # plan IDs this requires
files_modified: []         # files this plan touches
autonomous: true           # false if has checkpoints

must_haves:
  truths: []               # observable behaviors
  artifacts: []            # files that must exist
  key_links: []            # critical connections
---

<objective>
[What this plan accomplishes]

Purpose: [Why this matters]
Output: [Artifacts created]
</objective>

<execution_context>
@~/.claude/gsd/workflows/execute-plan.md
@~/.claude/gsd/templates/SUMMARY.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: [Action-oriented name]</name>
  <files>[exact file paths]</files>
  <action>[Specific implementation instructions]</action>
  <verify>[Command or check to prove completion]</verify>
  <done>[Acceptance criteria]</done>
</task>

<task type="auto">
  <name>Task 2: [Name]</name>
  <files></files>
  <action></action>
  <verify></verify>
  <done></done>
</task>

</tasks>

<verification>
[Overall checks after all tasks complete]
</verification>

<success_criteria>
- [ ] [Measurable completion criteria]
- [ ] [Another criteria]
</success_criteria>

<output>
After completion, create `.planning/phases/[NN]-[name]/[phase]-[plan]-SUMMARY.md`
</output>
```

## Task Types

| Type | Use |
|------|-----|
| `auto` | Fully autonomous execution |
| `checkpoint:human-verify` | Pause for user verification |
| `checkpoint:decision` | Pause for user decision |
| `checkpoint:human-action` | Rare: unavoidable manual step |

## Guidelines

- 2-3 tasks per plan maximum
- Target ~50% context budget
- Tasks should take 15-60 minutes each
- Be specific: files, actions, verification commands

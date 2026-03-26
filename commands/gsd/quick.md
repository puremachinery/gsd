---
name: gsd:quick
description: Execute a small task directly without planning overhead
argument-hint: "<task description>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Execute a small, self-contained task directly. No planning artifacts, no subagents, no phase overhead.

**When to use:**
- Bug fixes (typo, logic error, missing null check)
- Config changes (update a setting, add an env var)
- Small features (add a field, rename a function, add a log line)
- Doc updates (fix README, update comments)
- Refactors (extract method, rename variable across files)

**When NOT to use (redirect to full workflow):**
- Task touches more than ~5 files
- Task requires new architecture or design patterns
- Task has unclear scope ("improve performance")
- Task is part of an active phase plan

**Output:** Code changes committed atomically. STATE.md updated if project exists.
</objective>

<context>
Task: $ARGUMENTS

Load if present (do not error if missing):
@.planning/STATE.md
</context>

<process>

<step name="validate_input">
If `$ARGUMENTS` is empty:

```
Usage: /gsd:quick <task description>

Examples:
  /gsd:quick "Fix the null check in login handler"
  /gsd:quick "Add CORS header for staging domain"
  /gsd:quick "Update README installation section"
  /gsd:quick "Rename getUserData to fetchUserProfile"
```

STOP here if no arguments.
</step>

<step name="complexity_gate">
Assess the task. If it is clearly small and well-scoped, **skip this gate** — do not add friction to simple tasks.

If the task seems complex (multi-system, vague, architectural, or investigation-heavy), use AskUserQuestion:

- header: "This task may be too large for /gsd:quick"
- question: "[Explain why it seems complex]"
- options:
  - "Proceed anyway" — execute as quick task
  - "Plan it properly" — redirect to `/gsd:plan-phase`
  - "Capture as todo" — redirect to `/gsd:add-todo`
  - "Let me refine" — user rephrases the task
  - "Open debug session" — redirect to `/gsd:debug` (if investigation-heavy)
</step>

<step name="check_git">
```bash
git rev-parse --is-inside-work-tree 2>/dev/null && echo "GIT_OK" || echo "NO_GIT"
```

If no git repo: note this — changes will not be committed. Continue execution.

If git repo exists:
```bash
git status --porcelain
```

If dirty working tree: warn "Working tree has uncommitted changes. Only files modified by this task will be staged."
</step>

<step name="execute">
Execute the task:

1. Read the relevant files to understand current state
2. Make the changes
3. Stage only files you modified (individually, never `git add .` or `git add -A`)

**Deviation rules still apply:**
- Auto-fix bugs introduced by the change (document in confirmation)
- Auto-add obviously missing code (null checks, imports)
- If you encounter an architectural decision, pause and ask the user

**Scope discipline:** Only change what the task asks for. Do not refactor surrounding code, add comments to unchanged files, or "improve" things beyond the stated task.

If the task cannot be completed (e.g., tests fail, missing dependency):
- Do NOT commit broken code
- Report what was attempted and what failed
- Use AskUserQuestion:
  - "Revert changes" — undo all modifications
  - "Keep changes uncommitted" — leave for user to fix
  - "Open debug session" — redirect to `/gsd:debug`
</step>

<step name="commit">
**Skip if no git repo.**

Determine the appropriate commit type from the change:

| Type | When |
|------|------|
| `fix` | Bug fix, error correction |
| `feat` | New capability, new field |
| `docs` | Documentation, comments |
| `refactor` | Rename, restructure, extract |
| `chore` | Config, tooling, dependencies |
| `test` | Add or fix tests |

Commit format:
```
{type}(quick): {concise description of what changed}
```

Examples:
- `fix(quick): correct off-by-one in pagination offset`
- `feat(quick): add created_at timestamp to User model`
- `docs(quick): update README with new API endpoint`
- `refactor(quick): rename getUserData to fetchUserProfile`
</step>

<step name="update_state">
**If `.planning/STATE.md` exists:**

Update the `Last activity` line (or equivalent recent activity section):
```
Last activity: [YYYY-MM-DD] — quick: {commit message one-liner}
```

Stage the updated STATE.md and amend the commit (or create a separate `docs(quick): update state` commit).

**If `.planning/` does not exist:** Skip. Do not create `.planning/` or STATE.md.
</step>

<step name="confirm">
Display confirmation:

```
Done: {type}(quick): {description}

  Files: {list of modified files}
  Commit: {short hash}

Continue working, or run another /gsd:quick.
```

If no git repo, show:
```
Done: {description}

  Files: {list of modified files}
  (No git repo — changes not committed)
```
</step>

</process>

<anti_patterns>
- Don't create PLAN.md, SUMMARY.md, CONTEXT.md, or phase directories
- Don't spawn subagents — execute inline in current context
- Don't use `git add .` or `git add -A` — stage files individually
- Don't expand scope beyond what was asked
- Don't create `.planning/` directory if it doesn't exist
- Don't add unnecessary ceremony — this is the fast path
</anti_patterns>

<success_criteria>
- [ ] Task description provided
- [ ] Complexity assessed (redirected if too large)
- [ ] Changes implemented correctly
- [ ] Files staged individually
- [ ] Atomic commit created with `{type}(quick):` format
- [ ] STATE.md updated if present
- [ ] Confirmation shown with commit hash and files changed
</success_criteria>

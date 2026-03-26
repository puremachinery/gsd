---
name: gsd:next
description: Auto-detect and execute the next workflow step
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - SlashCommand
  - AskUserQuestion
---

<objective>
Determine the next logical workflow step and execute it. Action-first alternative to `/gsd:progress` — skips the status report and goes straight to doing.

In **interactive mode** (default): shows what it will do and confirms before executing.
In **YOLO mode** (`.planning/config.json`): executes immediately.
</objective>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/config.json
</context>

<process>

<step name="check_project">
If no `.planning/` directory:

```
No project found. Start one:

  /gsd:new-project    Initialize a new project
  /gsd:quick "..."    Execute a one-off task without project setup
```

STOP here.

If `.planning/` exists but ROADMAP.md is missing and PROJECT.md exists:
→ Milestone was archived. **Route: `/gsd:new-milestone`**

If both ROADMAP.md and PROJECT.md missing:
→ **Route: `/gsd:new-project`**
</step>

<step name="detect_mode">
Read `.planning/config.json` if it exists. Check `workflow_mode` field.

- `"yolo"` → auto-execute without confirmation
- `"interactive"` or missing → confirm before executing

Also check for `.continue-here` or `.continue-here.md` in project root:
- If found → **Route: `/gsd:resume-work`** (takes priority over normal routing)
</step>

<step name="determine_next">
**Read current phase state:**

Parse STATE.md for current phase number. Find the current phase directory.

```bash
ls -1 .planning/phases/[current-phase-dir]/*-PLAN.md 2>/dev/null | wc -l
ls -1 .planning/phases/[current-phase-dir]/*-SUMMARY.md 2>/dev/null | wc -l
ls -1 .planning/phases/[current-phase-dir]/*-UAT.md 2>/dev/null | grep -l "status: diagnosed" 2>/dev/null | wc -l
```

**Routing table (first match wins):**

| Condition | Next action | Command |
|-----------|-------------|---------|
| `.continue-here` exists | Resume paused work | `/gsd:resume-work` |
| UAT gaps diagnosed | Plan fixes for UAT gaps | `/gsd:plan-phase {N} --gaps` |
| Plans exist, some unexecuted | Execute the phase | `/gsd:execute-phase {N}` |
| No plans exist, CONTEXT.md exists | Plan the phase | `/gsd:plan-phase {N}` |
| No plans exist, no CONTEXT.md | Discuss the phase first | `/gsd:discuss-phase {N}` |
| All plans executed, more phases remain | Move to next phase | `/gsd:discuss-phase {N+1}` |
| All phases complete | Complete the milestone | `/gsd:complete-milestone` |
| Between milestones (no ROADMAP) | Start next milestone | `/gsd:new-milestone` |
</step>

<step name="execute_or_confirm">
**YOLO mode:**

```
▶ /gsd:{command} {args}
```

Execute the command directly via SlashCommand.

**Interactive mode:**

```
## Next Step

{command description — one line explaining why this is next}

  /{command} {args}

Proceed?
```

Use AskUserQuestion:
- header: "Next step"
- question: "{description}"
- options:
  - "Go" — execute the command
  - "Skip" — skip to the step after (e.g., skip discuss, go to plan)
  - "Show progress" — run `/gsd:progress` for full status instead
  - "Cancel" — do nothing

If "Go": execute via SlashCommand.
If "Skip": re-evaluate routing with the skipped step removed (e.g., if discuss was skipped, route to plan-phase instead).
If "Show progress": execute `/gsd:progress`.
</step>

</process>

<anti_patterns>
- Don't show a full status report — that's what `/gsd:progress` is for
- Don't ask the user which command to run — the whole point is auto-detection
- Don't create files or make changes — just route to the right command
- Don't confirm in YOLO mode (except for milestone completion, which is always confirmed)
</anti_patterns>

<success_criteria>
- [ ] Project state correctly detected
- [ ] Next logical step identified
- [ ] User confirmed (interactive) or auto-executed (YOLO)
- [ ] Command dispatched via SlashCommand
- [ ] Edge cases handled (no project, between milestones, paused work)
</success_criteria>

<required_reading>

**Read these files NOW:**

1. `.planning/STATE.md`
2. `.planning/PROJECT.md`
3. `.planning/ROADMAP.md`
4. Current phase plan files (`*-PLAN.md`)
5. Current phase summary files (`*-SUMMARY.md`)

</required_reading>

<purpose>

Mark current phase complete and advance to next. This is the natural point where progress tracking and PROJECT.md evolution happen.

"Planning next phase" = "current phase is done"

</purpose>

<process>

<step name="load_project_state" priority="first">

Before transition, read project state:

```bash
cat .planning/STATE.md 2>/dev/null
cat .planning/PROJECT.md 2>/dev/null
```

Parse current position to verify we're transitioning the right phase.
Note accumulated context that may need updating after transition.

</step>

<step name="verify_completion">

Check current phase has all plan summaries:

```bash
ls .planning/phases/XX-current/*-PLAN.md 2>/dev/null | sort
ls .planning/phases/XX-current/*-SUMMARY.md 2>/dev/null | sort
```

**Verification logic:**

- Count PLAN files
- Count SUMMARY files
- If counts match: all plans complete
- If counts don't match: incomplete

**If all plans complete:**

- In auto mode: proceed to cleanup_handoff
- In interactive mode: confirm transition

**If plans incomplete:**

Skipping incomplete plans is destructive. ALWAYS prompt regardless of mode.

Present:

```
Phase [X] has incomplete plans:
- {phase}-01-SUMMARY.md ✓ Complete
- {phase}-02-SUMMARY.md ✗ Missing
- {phase}-03-SUMMARY.md ✗ Missing

Options:
1. Continue current phase (execute remaining plans)
2. Mark complete anyway (skip remaining plans)
3. Review what's left
```

Wait for user decision.

</step>

<step name="cleanup_handoff">

Check for lingering handoffs:

```bash
ls .planning/phases/XX-current/.continue-here*.md 2>/dev/null
```

If found, delete them — phase is complete, handoffs are stale.

</step>

<step name="update_roadmap">

Update the roadmap file:

```bash
ROADMAP_FILE=".planning/ROADMAP.md"
```

Update the file:

- Mark current phase: `[x] Complete`
- Add completion date
- Update plan count to final (e.g., "3/3 plans complete")
- Update Progress table
- Keep next phase as `[ ] Not started`

**Example:**

```markdown
## Phases

- [x] Phase 1: Foundation (completed 2025-01-15)
- [ ] Phase 2: Authentication <- Next
- [ ] Phase 3: Core Features

## Progress

| Phase             | Plans Complete | Status      | Completed  |
| ----------------- | -------------- | ----------- | ---------- |
| 1. Foundation     | 3/3            | Complete    | 2025-01-15 |
| 2. Authentication | 0/2            | Not started | -          |
| 3. Core Features  | 0/1            | Not started | -          |
```

</step>

<step name="evolve_project">

Evolve PROJECT.md to reflect learnings from completed phase.

**Read phase summaries:**

```bash
cat .planning/phases/XX-current/*-SUMMARY.md
```

**Assess requirement changes:**

1. **Requirements validated?**
   - Any Active requirements shipped in this phase?
   - Move to Validated with phase reference: `- ✓ [Requirement] — Phase X`

2. **Requirements invalidated?**
   - Any Active requirements discovered to be unnecessary or wrong?
   - Move to Out of Scope with reason: `- [Requirement] — [why invalidated]`

3. **Requirements emerged?**
   - Any new requirements discovered during building?
   - Add to Active: `- [ ] [New requirement]`

4. **Decisions to log?**
   - Extract decisions from SUMMARY.md files
   - Add to Key Decisions table with outcome if known

5. **"What This Is" still accurate?**
   - If the product has meaningfully changed, update the description
   - Keep it current and accurate

**Update PROJECT.md:**

Make the edits inline. Update "Last updated" footer:

```markdown
---
*Last updated: [date] after Phase [X]*
```

**Step complete when:**

- [ ] Phase summaries reviewed for learnings
- [ ] Validated requirements moved from Active
- [ ] Invalidated requirements moved to Out of Scope with reason
- [ ] Emerged requirements added to Active
- [ ] New decisions logged with rationale
- [ ] "What This Is" updated if product changed
- [ ] "Last updated" footer reflects this transition

</step>

<step name="update_state">

Update STATE.md to reflect phase completion and transition.

**Current Position format:**

```markdown
Phase: [next] of [total] ([Next phase name])
Plan: Not started
Status: Ready to plan
Last activity: [today] — Phase [X] complete, transitioned to Phase [X+1]

Progress: [updated progress bar]
```

**Project Reference format:**

```markdown
## Project Reference

See: .planning/PROJECT.md (updated [today])

**Core value:** [Current core value from PROJECT.md]
**Current focus:** [Next phase name]
```

**Accumulated Context:**

- Note recent decisions from this phase (3-5 max)
- Remove resolved blockers, keep unresolved with phase prefix
- Add any new concerns from completed phase's summaries

**Session Continuity:**

```markdown
Last session: [today]
Stopped at: Phase [X] complete, ready to plan Phase [X+1]
Resume file: None
```

</step>

<step name="offer_next_phase">

**Verify milestone status before presenting next steps.**

**Step 1: Read ROADMAP.md and identify phases in current milestone**

Read ROADMAP.md and extract:
1. Current phase number (the phase just transitioned from)
2. All phase numbers in the current milestone section

Count total phases and identify the highest phase number in the milestone.

**Step 2: Route based on milestone status**

| Condition | Meaning | Action |
|-----------|---------|--------|
| current phase < highest phase | More phases remain | Offer next phase planning | 
| current phase = highest phase | Milestone complete | Offer milestone completion | 

**Route A: More phases remain in milestone**

- Present next phase name and goal
- Offer to plan, discuss, or research next phase

**Route B: Milestone complete (all phases done)**

- Announce milestone completion
- Offer to archive and prepare next milestone

</step>

</process>

<implicit_tracking>

Progress tracking is implicit:

- "Plan phase 2" -> Phase 1 must be done (or ask)
- "Plan phase 3" -> Phases 1-2 must be done (or ask)
- Transition workflow makes it explicit in ROADMAP.md

No separate "update progress" step. Forward motion IS progress.

</implicit_tracking>

<partial_completion>

If user wants to move on but phase isn't fully complete:

```
Phase [X] has incomplete plans:
- {phase}-02-PLAN.md (not executed)
- {phase}-03-PLAN.md (not executed)

Options:
1. Mark complete anyway (plans weren't needed)
2. Defer work to later phase
3. Stay and finish current phase
```

Respect user judgment — they know if work matters.

**If marking complete with incomplete plans:**

- Update ROADMAP: "2/3 plans complete" (not "3/3")
- Note in transition message which plans were skipped

</partial_completion>

<success_criteria>

Transition is complete when:

- [ ] Current phase plan summaries verified (all exist or user chose to skip)
- [ ] Any stale handoffs deleted
- [ ] ROADMAP.md updated with completion status and plan count
- [ ] PROJECT.md evolved (requirements, decisions, description if needed)
- [ ] STATE.md updated (position, reference, context, session)
- [ ] Progress table updated
- [ ] User knows next steps

</success_criteria>

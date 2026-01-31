<purpose>
Execute a phase plan (PLAN.md) and create the outcome summary (SUMMARY.md).
</purpose>

<required_reading>
Read STATE.md before any operation to load project context.
</required_reading>

<process>

<step name="load_project_state" priority="first">
Before any operation, read project state:

```bash
cat .planning/STATE.md 2>/dev/null
```

**If file exists:** Parse and internalize:

- Current position (phase, plan, status)
- Accumulated decisions (constraints on this execution)
- Blockers/concerns (things to watch for)
- Brief alignment status

**If file missing but .planning/ exists:**

```
STATE.md missing but planning artifacts exist.
Options:
1. Reconstruct from existing artifacts
2. Continue without project state (may lose accumulated context)
```

**If .planning/ doesn't exist:** Error - project not initialized.

This ensures every execution has full project context.
</step>

<step name="identify_plan">
Find the next plan to execute:
- Check roadmap for "In progress" phase
- Find plans in that phase directory
- Identify first plan without corresponding SUMMARY

```bash
cat .planning/ROADMAP.md
# Look for phase with "In progress" status
# Then find plans in that phase
ls .planning/phases/XX-name/*-PLAN.md 2>/dev/null | sort
ls .planning/phases/XX-name/*-SUMMARY.md 2>/dev/null | sort
```

**Logic:**

- If `01-01-PLAN.md` exists but `01-01-SUMMARY.md` doesn't -> execute 01-01
- If `01-01-SUMMARY.md` exists but `01-02-SUMMARY.md` doesn't -> execute 01-02
- Pattern: Find first PLAN file without matching SUMMARY file

Confirm with user if ambiguous.
</step>

<step name="record_start_time">
Record execution start time for performance tracking:

```bash
PLAN_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PLAN_START_EPOCH=$(date +%s)
```

Store in shell variables for duration calculation at completion.
</step>

<step name="parse_segments">
**Intelligent segmentation: Parse plan into execution segments.**

Plans are divided into segments by checkpoints. Each segment is routed to optimal execution context (worker or main).

**1. Check for checkpoints:**

```bash
# Find all checkpoints and their types
grep -n "type="checkpoint" .planning/phases/XX-name/{phase}-{plan}-PLAN.md
```

**2. Analyze execution strategy:**

**If NO checkpoints found:**

- **Fully autonomous plan** - spawn single worker for entire plan
- Worker executes all tasks, creates SUMMARY, commits
- Main context: orchestration only

**If checkpoints found, parse into segments:**

Segment = tasks between checkpoints (or start -> first checkpoint, or last checkpoint -> end)

**For each segment, determine routing:**

```
Segment routing rules:

IF segment has no prior checkpoint:
  -> WORKER (first segment, nothing to depend on)

IF segment follows checkpoint:human-verify:
  -> WORKER (verification is confirmation, doesn't affect next work)

IF segment follows checkpoint:decision OR checkpoint:human-action:
  -> MAIN CONTEXT (next tasks need the decision/result)
```

**3. Execution pattern:**

**Pattern A: Fully autonomous (no checkpoints)**

```
Spawn worker -> execute all tasks -> SUMMARY -> commit -> report back
```

**Pattern B: Segmented with verify-only checkpoints**

```
Segment 1: Worker -> execute -> report
Checkpoint: human-verify -> main context
Segment 2: Worker -> execute -> report
Checkpoint: human-verify -> main context
Aggregate -> SUMMARY -> commit
```

**Pattern C: Decision-dependent (must stay in main)**

```
Checkpoint: decision -> main context
Tasks depend on decision -> execute in main
```

**4. Why this works:**

**Segmentation benefits:**

- Fresh context for each autonomous segment
- Main context only for checkpoints
- Can handle large plans if properly segmented

**When segmentation provides no benefit:**

- Checkpoint is decision/human-action and following tasks depend on outcome
- Better to execute sequentially in main than break flow
</step>

<step name="load_prompt">
Read the plan prompt:
```bash
cat .planning/phases/XX-name/{phase}-{plan}-PLAN.md
```

This IS the execution instructions. Follow it exactly.

If plan references CONTEXT.md, that file provides the user's vision for this phase. Honor it throughout execution.
</step>

<step name="execute">
Execute each task in the prompt. **Deviations are normal** - handle them automatically using rules below.

1. Read the @context files listed in the prompt

2. For each task:

   **If `type="auto"`:**

   - Work toward task completion
   - **If CLI/Service returns authentication error:** Handle as authentication gate (see below)
   - **When you discover additional work not in plan:** Apply deviation rules (see below) automatically
   - Run verification
   - Confirm done criteria met
   - **Commit the task** (if plan specifies per-task commits)
   - Track task completion and commit hash for Summary documentation

   **If `type="checkpoint:*"`:**

   - STOP immediately
   - Execute checkpoint protocol
   - Wait for user response
   - Verify if possible
   - Only after user confirmation: continue

3. Run overall verification checks from `<verification>` section
4. Confirm all success criteria from `<success_criteria>` section met
5. Document all deviations in Summary
</step>

<authentication_gates>

## Handling Authentication Errors During Execution

**When you encounter authentication errors during `type="auto"` task execution:**

This is NOT a failure. Authentication gates are expected and normal. Handle them dynamically:

**Authentication error indicators:**

- CLI returns: "Not authenticated", "Not logged in", "Unauthorized", "401", "403"
- Service returns: "Authentication required", "Invalid key", "Missing credentials"
- Command fails with: "Run {tool} login" or "Set {ENV_VAR}"

**Authentication gate protocol:**

1. **Recognize it's an auth gate** - Not a bug, just needs credentials
2. **STOP current task execution** - Don't retry repeatedly
3. **Create dynamic checkpoint:human-action** - Present it to user immediately
4. **Provide exact authentication steps** - Commands, where to get keys
5. **Wait for user to authenticate** - Let them complete auth flow
6. **Verify authentication works** - Test that credentials are valid
7. **Retry the original task** - Resume automation where you left off
8. **Continue normally** - Don't treat this as an error in Summary

**In Summary documentation:**

Document authentication gates as normal flow, not deviations:

```markdown
## Authentication Gates

During execution, authentication was required:

1. Task 3: Service CLI required authentication
   - Paused for `service-cli login`
   - Resumed after authentication
   - Task completed
```

**Key principles:**

- Authentication gates are NOT failures or bugs
- They're expected interaction points during first-time setup
- Handle them gracefully and continue automation after unblocked
- Don't mark tasks as "failed" or "incomplete" due to auth gates
- Document them as normal flow, separate from deviations
</authentication_gates>

<deviation_rules>

## Automatic Deviation Handling

**While executing tasks, you WILL discover work not in the plan.** This is normal.

Apply these rules automatically. Track all deviations for Summary documentation.

---

**RULE 1: Auto-fix bugs**

**Trigger:** Code doesn't work as intended (broken behavior, incorrect output, errors)

**Action:** Fix immediately, track for Summary

**Examples:**

- Logic errors (inverted condition, off-by-one)
- Runtime errors, null pointer exceptions, undefined references
- Broken validation (accepts invalid input, rejects valid input)
- Security vulnerabilities (injection, auth bypass)
- Race conditions, deadlocks
- Resource leaks

**Process:**

1. Fix the bug inline
2. Add/update tests to prevent regression
3. Verify fix works
4. Continue task
5. Track in deviations list: `[Rule 1 - Bug] [description]`

**No user permission needed.** Bugs must be fixed for correct operation.

---

**RULE 2: Auto-add missing critical functionality**

**Trigger:** Code is missing essential features for correctness, security, or basic operation

**Action:** Add immediately, track for Summary

**Examples:**

- Missing error handling (no try/catch)
- No input validation (accepts malicious data)
- Missing null checks (crashes on edge cases)
- Missing auth on protected paths
- Missing authorization checks
- Missing rate limiting on public handlers
- Missing required indexes
- No logging for errors

**Process:**

1. Add the missing functionality inline
2. Add tests for the new functionality
3. Verify it works
4. Continue task
5. Track in deviations list: `[Rule 2 - Missing Critical] [description]`

**Critical = required for correct/secure/performant operation**
**No user permission needed.** These are not "features" - they're requirements.

---

**RULE 3: Auto-fix blocking issues**

**Trigger:** Something prevents you from completing current task

**Action:** Fix immediately to unblock, track for Summary

**Examples:**

- Missing dependency (package not installed, import fails)
- Wrong types blocking compilation
- Broken import paths
- Missing environment variable (app won't start)
- Build configuration error
- Missing file referenced in code
- Circular dependency blocking module resolution

**Process:**

1. Fix the blocking issue
2. Verify task can now proceed
3. Continue task
4. Track in deviations list: `[Rule 3 - Blocking] [description]`

**No user permission needed.** Can't complete task without fixing blocker.

---

**RULE 4: Ask about architectural changes**

**Trigger:** Fix/addition requires significant structural modification

**Action:** STOP, present to user, wait for decision

**Examples:**

- Adding new data model/table (not just column)
- Major schema changes (changing primary key, splitting tables)
- Introducing new service layer or architectural pattern
- Switching libraries/frameworks
- Changing authentication approach (sessions -> tokens)
- Adding new infrastructure (queue, cache layer, CDN)
- Changing service contracts (breaking changes)
- Adding new deployment environment

**Process:**

1. STOP current task
2. Present to user:
   - What you propose
   - Why it's needed
   - Alternatives
   - Impact
3. Wait for decision
4. Proceed based on user choice

---

**Deviation documentation:**

Track all deviations in Summary with this format:

```markdown
## Deviations from Plan

**1. [Rule 1 - Bug] Fixed case-sensitive email uniqueness**
- Found during: Task 4
- Fix: [what was done]
- Files modified: [files]
- Verification: [how verified]
- Commit: [hash]
```

</deviation_rules>
</process>

<success_criteria>
- [ ] Plan executed as written (or deviations documented)
- [ ] All tasks completed or checkpointed
- [ ] Verification checks passed
- [ ] SUMMARY.md created
- [ ] Commits created per plan guidance
</success_criteria>

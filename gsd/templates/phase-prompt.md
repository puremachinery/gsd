# Phase Prompt Template

> **Note:** Planning methodology lives in `agents/planner.md`.
> This template defines the PLAN.md output format.

Template for `.planning/phases/XX-name/{phase}-{plan}-PLAN.md` — executable phase plans optimized for parallel execution.

**Naming:** Use `{phase}-{plan}-PLAN.md` (e.g., `01-02-PLAN.md` for Phase 1, Plan 2)

---

## File Template

```markdown
---
phase: XX-name
plan: NN
type: execute
wave: N                     # Execution wave (1, 2, 3...). Pre-computed at plan time.
depends_on: []              # Plan IDs this plan requires (e.g., ["01-01"]).
files_modified: []          # Files this plan modifies.
autonomous: true            # false if plan has checkpoints requiring user interaction
user_setup: []              # Human-required setup assistant cannot automate (see below)

# Goal-backward verification (derived during planning, verified after execution)
must_haves:
  truths: []                # Observable behaviors that must be true for goal achievement
  artifacts: []             # Files that must exist with real implementation
  key_links: []             # Critical connections between artifacts
---

<objective>
[What this plan accomplishes]

Purpose: [Why this matters for the project]
Output: [What artifacts will be created]
</objective>

<execution_context>
@workflows/execute-plan.md
@templates/SUMMARY.md
[If plan contains checkpoint tasks (type="checkpoint:*"), add:]
@references/checkpoints.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md

# Only reference prior plan SUMMARYs if genuinely needed:
# - This plan uses types/exports from prior plan
# - Prior plan made decision that affects this plan
# - Prior plan output is direct input to this plan
# Do NOT reflexively chain: Plan 02 refs 01, Plan 03 refs 02...

[Relevant source files:]
@src/path/to/relevant.ext
</context>

<tasks>

<task type="auto">
  <name>Task 1: [Action-oriented name]</name>
  <files>path/to/file.ext, another/file.ext</files>
  <action>[Specific implementation - what to do, how to do it, what to avoid and WHY]</action>
  <verify>[Command or check to prove it worked]</verify>
  <done>[Measurable acceptance criteria]</done>
</task>

<task type="auto">
  <name>Task 2: [Action-oriented name]</name>
  <files>path/to/file.ext</files>
  <action>[Specific implementation]</action>
  <verify>[Command or check]</verify>
  <done>[Acceptance criteria]</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <decision>[What needs deciding]</decision>
  <context>[Why this decision matters]</context>
  <options>
    <option id="option-a">
      <name>[Option name]</name>
      <pros>[Benefits and advantages]</pros>
      <cons>[Tradeoffs and limitations]</cons>
    </option>
    <option id="option-b">
      <name>[Option name]</name>
      <pros>[Benefits and advantages]</pros>
      <cons>[Tradeoffs and limitations]</cons>
    </option>
  </options>
  <resume-signal>[How to indicate choice - "Select: option-a or option-b"]</resume-signal>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>[What assistant just built that needs verification]</what-built>
  <how-to-verify>
    1. Run: [command to start app/service]
    2. Open: [location to check]
    3. Test: [Specific interactions]
    4. Confirm: [Expected behaviors]
  </how-to-verify>
  <resume-signal>Type "approved" to continue, or describe issues to fix</resume-signal>
</task>

</tasks>

<verification>
Before declaring plan complete:
- [ ] [Specific test command]
- [ ] [Build/type check passes]
- [ ] [Behavior verification]
</verification>

<success_criteria>

- All tasks completed
- All verification checks pass
- No errors or warnings introduced
- [Plan-specific criteria]
</success_criteria>

<output>
After completion, create `.planning/phases/XX-name/{phase}-{plan}-SUMMARY.md`
</output>
```

---

## Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `phase` | Yes | Phase identifier (e.g., `01-foundation`) |
| `plan` | Yes | Plan number within phase (e.g., `01`, `02`) |
| `type` | Yes | `execute` for standard plans, `tdd` for TDD plans |
| `wave` | Yes | Execution wave number (1, 2, 3...). Pre-computed at plan time. |
| `depends_on` | Yes | Array of plan IDs this plan requires. |
| `files_modified` | Yes | Files this plan touches. |
| `autonomous` | Yes | `true` if no checkpoints, `false` if has checkpoints |
| `user_setup` | No | Array of human-required setup items (external services) |
| `must_haves` | Yes | Goal-backward verification criteria (see below) |

**Wave is pre-computed:** Wave numbers are assigned during plan-phase. Execute-phase reads `wave` directly from frontmatter and groups plans by wave number. No runtime dependency analysis needed.

**Must-haves enable verification:** The `must_haves` field carries goal-backward requirements from planning to execution. After all plans complete, a verification pass checks these criteria against the codebase.

---

## Parallel vs Sequential

**Wave 1 candidates (parallel):**

```yaml
# Plan 01 - Feature A
wave: 1
depends_on: []
files_modified: [src/features/a/model.ext, src/features/a/handler.ext]
autonomous: true

# Plan 02 - Feature B (no overlap with Plan 01)
wave: 1
depends_on: []
files_modified: [src/features/b/model.ext, src/features/b/handler.ext]
autonomous: true
```

All run in parallel (Wave 1) - no dependencies, no file conflicts.

**Sequential (genuine dependency):**

```yaml
# Plan 01 - Auth foundation
wave: 1
depends_on: []
files_modified: [src/lib/auth.ext, src/middleware/auth.ext]
autonomous: true

# Plan 02 - Protected features (needs auth)
wave: 2
depends_on: ["01"]
files_modified: [src/features/control-panel.ext]
autonomous: true
```

Plan 02 in Wave 2 waits for Plan 01 in Wave 1 - genuine dependency on auth types/middleware.

**Checkpoint plan:**

```yaml
# Plan 03 - UI with verification
wave: 3
depends_on: ["01", "02"]
files_modified: [src/modules/control-panel/entry.ext]
autonomous: false  # Has checkpoint:human-verify
```

Wave 3 runs after Waves 1 and 2. Pauses at checkpoint, resumes on approval.

---

## Context Section

**Parallel-aware context:**

```markdown
<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md

# Only include SUMMARY refs if genuinely needed:
# - This plan imports types from prior plan
# - Prior plan made decision affecting this plan
# - Prior plan's output is input to this plan
#
# Independent plans need NO prior SUMMARY references.
# Do NOT reflexively chain: 02 refs 01, 03 refs 02...

@src/relevant/source.ext
</context>
```

**Bad pattern (creates false dependencies):**
```markdown
<context>
@.planning/phases/03-features/03-01-SUMMARY.md  # Just because it's earlier
@.planning/phases/03-features/03-02-SUMMARY.md  # Reflexive chaining
</context>
```

---

## Scope Guidance

**Plan sizing:**

- 2-3 tasks per plan
- ~50% context usage maximum
- Complex phases: multiple focused plans, not one large plan

**When to split:**

- Different subsystems (auth vs service vs modules)
- >3 tasks
- Risk of context overflow
- TDD candidates - separate plans

**Vertical slices preferred:**

```
PREFER: Plan 01 = Feature A (model + handler + module)
        Plan 02 = Feature B (model + handler + module)

AVOID:  Plan 01 = All models
        Plan 02 = All handlers
        Plan 03 = All modules
```

---

## TDD Plans

TDD features get dedicated plans with `type: tdd`.

**Heuristic:** Can you write `expect(fn(input)).toBe(output)` before writing `fn`?
→ Yes: Create a TDD plan
→ No: Standard task in standard plan

See `references/tdd.md` for TDD plan structure.

---

## Task Types

| Type | Use For | Autonomy |
|------|---------|----------|
| `auto` | Everything assistant can do independently | Fully autonomous |
| `checkpoint:human-verify` | Visual/functional verification | Pauses, returns to orchestrator |
| `checkpoint:decision` | Implementation choices | Pauses, returns to orchestrator |
| `checkpoint:human-action` | Truly unavoidable manual steps (rare) | Pauses, returns to orchestrator |

**Checkpoint behavior in parallel execution:**
- Plan runs until checkpoint
- Agent returns with checkpoint details + agent_id
- Orchestrator presents to user
- User responds
- Orchestrator resumes agent with `resume: agent_id`

---

## Examples

**Autonomous parallel plan:**

```markdown
---
phase: 03-features
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [src/features/user/model.ext, src/features/user/handler.ext, src/features/user/module.ext]
autonomous: true
---

<objective>
Implement complete User feature as vertical slice.

Purpose: Self-contained user management that can run parallel to other features.
Output: User model, service handlers, and a module entry point.
</objective>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<tasks>
<task type="auto">
  <name>Task 1: Create User model</name>
  <files>src/features/user/model.ext</files>
  <action>Define User type with id, email, name, createdAt. Export typed interface.</action>
  <verify>run-typecheck passes</verify>
  <done>User type exported and usable</done>
</task>

<task type="auto">
  <name>Task 2: Create User service handlers</name>
  <files>src/features/user/handler.ext</files>
  <action>Create list, get, and create handlers. Use User type from model.</action>
  <verify>request tests pass for all handlers</verify>
  <done>All CRUD operations work</done>
</task>
</tasks>

<verification>
- [ ] run-build succeeds
- [ ] handlers respond correctly
</verification>

<success_criteria>
- All tasks completed
- User feature works end-to-end
</success_criteria>

<output>
After completion, create `.planning/phases/03-features/03-01-SUMMARY.md`
</output>
```

**Plan with checkpoint (non-autonomous):**

```markdown
---
phase: 03-features
plan: 03
type: execute
wave: 2
depends_on: ["03-01", "03-02"]
files_modified: [src/modules/control-panel/entry.ext]
autonomous: false
---

<objective>
Build control-panel with visual verification.

Purpose: Integrate user and product features into unified view.
Output: Working control-panel module.
</objective>

<execution_context>
@workflows/execute-plan.md
@templates/SUMMARY.md
@references/checkpoints.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-features/03-01-SUMMARY.md
@.planning/phases/03-features/03-02-SUMMARY.md
</context>

<tasks>
<task type="auto">
  <name>Task 1: Build control-panel layout</name>
  <files>src/modules/control-panel/entry.ext</files>
  <action>Create responsive layout with user and product sections. Use project styling system.</action>
  <verify>run-build succeeds</verify>
  <done>Control Panel renders without errors</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Responsive control-panel with user and product sections</what-built>
  <how-to-verify>
    1. Run: run-dev
    2. Open: http://localhost:3000/control-panel
    3. Desktop: Verify two-column layout
    4. Mobile: Verify stacked layout
    5. Check: No layout shift, no scroll issues
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>
</tasks>

<verification>
- [ ] run-build succeeds
- [ ] Visual verification passed
</verification>

<success_criteria>
- All tasks completed
- User approved visual layout
</success_criteria>

<output>
After completion, create `.planning/phases/03-features/03-03-SUMMARY.md`
</output>
```

---

## Anti-Patterns

**Bad: Reflexive dependency chaining**
```yaml
depends_on: ["03-01"]  # Just because 01 comes before 02
```

**Bad: Horizontal layer grouping**
```
Plan 01: All models
Plan 02: All handlers (depends on 01)
Plan 03: All modules
```

**Bad: Missing autonomy flag**
```yaml
# Has checkpoint but no autonomous: false
files_modified: [...]
# autonomous: ???  <- Missing!
```

**Bad: Vague tasks**
```xml
<task type="auto">
  <name>Set up authentication</name>
  <action>Add auth to the app</action>
</task>
```

---

## Guidelines

- Always use XML structure for assistant parsing
- Include `wave`, `depends_on`, `files_modified`, `autonomous` in every plan
- Prefer vertical slices over horizontal layers
- Only reference prior SUMMARYs when genuinely needed
- Group checkpoints with related auto tasks in same plan
- 2-3 tasks per plan, ~50% context max

---

## User Setup (External Services)

When a plan introduces external services requiring human configuration, declare in frontmatter:

```yaml
user_setup:
  - service: external-service
    why: "Service requires human-managed credentials"
    env_vars:
      - name: EXTERNAL_API_KEY
        source: "Service console or provider portal"
    dashboard_config:
      - task: "Create callback endpoint"
        location: "Service console > settings > callbacks"
        details: "URL: https://[your-domain]/callbacks/provider"
    local_dev:
      - "service-cli listen --forward-to localhost:3000/callbacks/provider"
```

**Automation-first rule:** `user_setup` contains ONLY what assistant literally cannot do:
- Account creation (requires human signup)
- Secret retrieval (requires portal access)
- Console configuration (requires human in browser)

**NOT included:** Package installs, code changes, file creation, CLI commands assistant can run.

**Result:** Execute-phase generates `{phase}-USER-SETUP.md` with checklist for the user.

---

## Must-Haves (Goal-Backward Verification)

The `must_haves` field defines what must be TRUE for the phase goal to be achieved. Derived during planning, verified after execution.

**Structure:**

```yaml
must_haves:
  truths:
    - "User can see existing messages"
    - "User can send a message"
    - "Messages persist across refresh"
  artifacts:
    - path: "src/modules/Chat.ext"
      provides: "Message list rendering"
      min_lines: 30
    - path: "src/services/chat/handler.ext"
      provides: "Message CRUD operations"
      exports: ["READ", "WRITE"]
    - path: "orm/schema.orm"
      provides: "Message model"
      contains: "model Message"
  key_links:
    - from: "src/modules/Chat.ext"
      to: "service:chat"
      via: "service call in lifecycle hook"
      pattern: "callService.*chat"
    - from: "src/services/chat/handler.ext"
      to: "data-store:message"
      via: "data query"
      pattern: "data\.message\.(find|create)"
```

**Field descriptions:**

| Field | Purpose |
|-------|---------|
| `truths` | Observable behaviors from user perspective. Each must be testable. |
| `artifacts` | Files that must exist with real implementation. |
| `artifacts[].path` | File path relative to project root. |
| `artifacts[].provides` | What this artifact delivers. |
| `artifacts[].min_lines` | Optional. Minimum lines to be considered substantive. |
| `artifacts[].exports` | Optional. Expected exports to verify. |
| `artifacts[].contains` | Optional. Pattern that must exist in file. |
| `key_links` | Critical connections between artifacts. |
| `key_links[].from` | Source artifact. |
| `key_links[].to` | Target artifact or endpoint. |
| `key_links[].via` | How they connect (description). |
| `key_links[].pattern` | Optional. Regex to verify connection exists. |

**Why this matters:**

Task completion != goal achievement. A task "create chat module" can complete by creating a placeholder. The `must_haves` field captures what must actually work, enabling verification to catch gaps before they compound.

**Verification flow:**

1. Plan-phase derives must_haves from phase goal (goal-backward)
2. Must_haves written to PLAN.md frontmatter
3. Execute-phase runs all plans
4. Verification pass checks must_haves against codebase
5. Gaps found -> fix plans created -> execute -> re-verify
6. All must_haves pass -> phase complete

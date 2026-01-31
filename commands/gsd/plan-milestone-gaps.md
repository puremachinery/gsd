---
name: gsd:plan-milestone-gaps
description: Create phases to close all gaps identified by milestone audit
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Create all phases necessary to close gaps identified by `/gsd:audit-milestone`.

Reads MILESTONE-AUDIT.md, groups gaps into logical phases, creates phase entries in ROADMAP.md, and offers to plan each phase.

One command creates all fix phases — no manual `/gsd:add-phase` per gap.
</objective>

<execution_context>
<!-- Spawns gsd-planner agent which has all planning expertise baked in -->
</execution_context>

<context>
**Audit results:**
Glob: .planning/v*-MILESTONE-AUDIT.md (use most recent)

**Original intent (for prioritization):**
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md

**Current state:**
@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<process>

## 1. Load Audit Results

```bash
# Find the most recent audit file
ls -t .planning/v*-MILESTONE-AUDIT.md 2>/dev/null | head -1
```

Parse YAML frontmatter to extract structured gaps:
- `gaps.requirements` — unsatisfied requirements
- `gaps.integration` — missing cross-phase connections
- `gaps.flows` — broken E2E flows

If no audit file exists or has no gaps, error:
```
No audit gaps found. Run `/gsd:audit-milestone` first.
```

## 2. Prioritize Gaps

Group gaps by priority from REQUIREMENTS.md:

| Priority | Action |
|----------|--------|
| `must` | Create phase, blocks milestone |
| `should` | Create phase, recommended |
| `nice` | Ask user: include or defer? |

For integration/flow gaps, infer priority from affected requirements.

## 3. Group Gaps into Phases

Cluster related gaps into logical phases:

**Grouping rules:**
- Same affected phase → combine into one fix phase
- Same subsystem (auth, service, modules) → combine
- Dependency order (fix stubs before wiring)
- Keep phases focused: 2-4 tasks each

**Example grouping:**
```
Gap: DASH-01 unsatisfied (Control Panel doesn't service call)
Gap: Integration Phase 1→3 (Auth not passed to service calls)
Gap: Flow "View control-panel" broken at data service call

→ Phase 6: "Wire Control Panel to service"
  - Add service call to ControlPanel.ext
  - Include auth header in service call
  - Handle response, update state
  - Render user data
```

## 4. Determine Phase Numbers

Find highest existing phase:
```bash
ls -d .planning/phases/*/ | sort -V | tail -1
```

New phases continue from there:
- If Phase 5 is highest, gaps become Phase 6, 7, 8...

## 5. Present Gap Closure Plan

```markdown
## Gap Closure Plan

**Milestone:** {version}
**Gaps to close:** {N} requirements, {M} integration, {K} flows

### Proposed Phases

**Phase {N}: {Name}**
Closes:
- {REQ-ID}: {description}
- Integration: {from} → {to}
Tasks: {count}

**Phase {N+1}: {Name}**
Closes:
- {REQ-ID}: {description}
- Flow: {flow name}
Tasks: {count}

{If nice-to-have gaps exist:}

### Deferred (nice-to-have)

These gaps are optional. Include them?
- {gap description}
- {gap description}

---

Create these {X} phases? (yes / adjust / defer all optional)
```

Wait for user confirmation.

## 6. Update ROADMAP.md

Add new phases to current milestone:

```markdown
### Phase {N}: {Name}
**Goal:** {derived from gaps being closed}
**Requirements:** {REQ-IDs being satisfied}
**Gap Closure:** Closes gaps from audit

### Phase {N+1}: {Name}
...
```

## 7. Create Phase Directories

```bash
mkdir -p ".planning/phases/{NN}-{name}"
```

## 8. Commit Roadmap Update

```bash
git add .planning/ROADMAP.md
git commit -m "docs(roadmap): add gap closure phases {N}-{M}"
```

## 9. Offer Next Steps

```markdown
## ✓ Gap Closure Phases Created

**Phases added:** {N} - {M}
**Gaps addressed:** {count} requirements, {count} integration, {count} flows

---

## ▶ Next Up

**Plan first gap closure phase**

`/gsd:plan-phase {N}`

<sub>`/clear` first → fresh context window</sub>

---

**Also available:**
- `/gsd:execute-phase {N}` — if plans already exist
- `cat .planning/ROADMAP.md` — see updated roadmap

---

**After all gap phases complete:**

`/gsd:audit-milestone` — re-audit to verify gaps closed
`/gsd:complete-milestone {version}` — archive when audit passes
```

</process>

<gap_to_phase_mapping>

## How Gaps Become Tasks

**Requirement gap → Tasks:**
```yaml
gap:
  id: DASH-01
  description: "User sees their data"
  reason: "Control Panel exists but doesn't service call from service"
  missing:
    - "lifecycle hook with service call to /service/user/data"
    - "State for user data"
    - "Render user data in JSX"

becomes:

phase: "Wire Control Panel Data"
tasks:
  - name: "Add data calling service"
    files: [src/modules/ControlPanel.ext]
    action: "Add lifecycle hook that calls service /service/user/data on mount"

  - name: "Add state management"
    files: [src/modules/ControlPanel.ext]
    action: "Add stateHook for userData, loading, error states"

  - name: "Render user data"
    files: [src/modules/ControlPanel.ext]
    action: "Replace placeholder with userData.map rendering"
```

**Integration gap → Tasks:**
```yaml
gap:
  from_phase: 1
  to_phase: 3
  connection: "Auth token → service calls"
  reason: "Control Panel service calls don't include auth header"
  missing:
    - "Auth header in service calls"
    - "Token refresh on 401"

becomes:

phase: "Add Auth to Control Panel service Calls"
tasks:
  - name: "Add auth header to calls service"
    files: [src/modules/ControlPanel.ext, src/lib/api.ext]
    action: "Include Authorization header with token in all service calls"

  - name: "Handle 401 responses"
    files: [src/lib/api.ext]
    action: "Add interceptor to refresh token or redirect to login on 401"
```

**Flow gap → Tasks:**
```yaml
gap:
  name: "User views control-panel after login"
  broken_at: "Control Panel data load"
  reason: "No service call"
  missing:
    - "Fetch user data on mount"
    - "Display loading state"
    - "Render user data"

becomes:

# Usually same phase as requirement/integration gap
# Flow gaps often overlap with other gap types
```

</gap_to_phase_mapping>

<success_criteria>
- [ ] MILESTONE-AUDIT.md loaded and gaps parsed
- [ ] Gaps prioritized (must/should/nice)
- [ ] Gaps grouped into logical phases
- [ ] User confirmed phase plan
- [ ] ROADMAP.md updated with new phases
- [ ] Phase directories created
- [ ] Changes committed
- [ ] User knows to run `/gsd:plan-phase` next
</success_criteria>

# Verification Report Template (Neutral)

Template for `.planning/phases/XX-name/{phase}-VERIFICATION.md` — phase goal verification results.

---

## File Template

```markdown
---
phase: XX-name
verified: YYYY-MM-DDTHH:MM:SSZ
status: passed | gaps_found | human_needed
score: N/M must-haves verified
---

# Phase {X}: {Name} Verification Report

**Phase Goal:** {goal from ROADMAP.md}
**Verified:** {timestamp}
**Status:** {passed | gaps_found | human_needed}

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | {truth from must_haves} | ✓ VERIFIED | {what confirmed it} |
| 2 | {truth from must_haves} | ✗ FAILED | {what's wrong} |
| 3 | {truth from must_haves} | ? UNCERTAIN | {why can't verify} |

**Score:** {N}/{M} truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/modules/Chat.ext` | Message list module | ✓ EXISTS + SUBSTANTIVE | Exports ChatList, renders Message[], no stubs |
| `src/services/chat/handler.ext` | Message handlers | ✗ STUB | File exists but WRITE returns placeholder |
| `data/schema.ext` | Message model | ✓ EXISTS + SUBSTANTIVE | Model defined with all fields |

**Artifacts:** {N}/{M} verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Chat.ext | service:chat | callService in lifecycle hook | ✓ WIRED | Line 23: `callService('chat')` with response handling |
| ChatInput | service:chat WRITE | onSubmit handler | ✗ NOT WIRED | onSubmit only calls logger.info |
| service:chat WRITE | data-store:message | dataStore.message.create | ✗ NOT WIRED | Returns hardcoded response, no data call |

**Wiring:** {N}/{M} connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| {REQ-01}: {description} | ✓ SATISFIED | - |
| {REQ-02}: {description} | ✗ BLOCKED | service handler is stub |
| {REQ-03}: {description} | ? NEEDS HUMAN | Can't verify real-time channel programmatically |

**Coverage:** {N}/{M} requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| src/services/chat/handler.ext | 12 | `// TODO: implement` | ⚠️ Warning | Indicates incomplete |
| src/modules/Chat.ext | 45 | `return "Placeholder"` | 🛑 Blocker | Renders no content |
| src/hooks/useChat.ext | - | File missing | 🛑 Blocker | Expected hook doesn't exist |

**Anti-patterns:** {N} found ({blockers} blockers, {warnings} warnings)

## Human Verification Required

{If no human verification needed:}
None — all verifiable items checked programmatically.

{If human verification needed:}

### 1. {Test Name}
**Test:** {What to do}
**Expected:** {What should happen}
**Why human:** {Why can't verify programmatically}

### 2. {Test Name}
**Test:** {What to do}
**Expected:** {What should happen}
**Why human:** {Why can't verify programmatically}

## Gaps Summary

{If no gaps:}
**No gaps found.** Phase goal achieved. Ready to proceed.

{If gaps found:}

### Critical Gaps (Block Progress)

1. **{Gap name}**
   - Missing: {what's missing}
   - Impact: {why this blocks the goal}
   - Fix: {what needs to happen}

2. **{Gap name}**
   - Missing: {what's missing}
   - Impact: {why this blocks the goal}
   - Fix: {what needs to happen}

### Non-Critical Gaps (Can Defer)

1. **{Gap name}**
   - Issue: {what's wrong}
   - Impact: {limited impact because...}
   - Recommendation: {fix now or defer}

## Recommended Fix Plans

{If gaps found, generate fix plan recommendations:}

### {phase}-{next}-PLAN.md: {Fix Name}

**Objective:** {What this fixes}

**Tasks:**
1. {Task to fix gap 1}
2. {Task to fix gap 2}
3. {Verification task}

**Estimated scope:** {Small / Medium}

---

### {phase}-{next+1}-PLAN.md: {Fix Name}

**Objective:** {What this fixes}

**Tasks:**
1. {Task}
2. {Task}

**Estimated scope:** {Small / Medium}

---

## Verification Metadata

**Verification approach:** Goal-backward (derived from phase goal)
**Must-haves source:** {PLAN.md frontmatter | derived from ROADMAP.md goal}
**Automated checks:** {N} passed, {M} failed
**Human checks required:** {N}
**Total verification time:** {duration}

---
*Verified: {timestamp}*
*Verifier: assistant (subagent)*
```

---

## Guidelines

**Status values:**
- `passed` — All must-haves verified, no blockers
- `gaps_found` — One or more critical gaps found
- `human_needed` — Automated checks pass but human verification required

**Evidence types:**
- For EXISTS: "File at path, exports X"
- For SUBSTANTIVE: "N lines, has patterns X, Y, Z"
- For WIRED: "Line N: code that connects A to B"
- For FAILED: "Missing because X" or "Stub because Y"

**Severity levels:**
- 🛑 Blocker: Prevents goal achievement, must fix
- ⚠️ Warning: Indicates incomplete but doesn't block
- ℹ️ Info: Notable but not problematic

**Fix plan generation:**
- Only generate if gaps_found
- Group related fixes into single plans
- Keep to 2-3 tasks per plan
- Include verification task in each plan

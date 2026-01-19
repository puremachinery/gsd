# Verification Report Template

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
| `src/services/chat/handler.ext` | Message CRUD | ✗ STUB | File exists but WRITE returns placeholder |
| `orm/schema.orm` | Message model | ✓ EXISTS + SUBSTANTIVE | Model defined with all fields |

**Artifacts:** {N}/{M} verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Chat.ext | /service/chat | service call in lifecycle hook | ✓ WIRED | Line 23: `callService('/service/chat')` with response handling |
| ChatInput | /service/chat WRITE | onSubmit handler | ✗ NOT WIRED | onSubmit only calls logger.info |
| /service/chat WRITE | database | orm-tool.message.create | ✗ NOT WIRED | Returns hardcoded response, no DB call |

**Wiring:** {N}/{M} connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| {REQ-01}: {description} | ✓ SATISFIED | - |
| {REQ-02}: {description} | ✗ BLOCKED | service handler is stub |
| {REQ-03}: {description} | ? NEEDS HUMAN | Can't verify WebSocket programmatically |

**Coverage:** {N}/{M} requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| src/services/chat/handler.ext | 12 | `// TODO: implement` | ⚠️ Warning | Indicates incomplete |
| src/modules/Chat.ext | 45 | `return <div>Placeholder</div>` | 🛑 Blocker | Renders no content |
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

---

## Example

```markdown
---
phase: 03-chat
verified: 2025-01-15T14:30:00Z
status: gaps_found
score: 2/5 must-haves verified
---

# Phase 3: Chat Interface Verification Report

**Phase Goal:** Working chat interface where users can send and receive messages
**Verified:** 2025-01-15T14:30:00Z
**Status:** gaps_found

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can see existing messages | ✗ FAILED | Component renders placeholder, not message data |
| 2 | User can type a message | ✓ VERIFIED | Input field exists with onChange handler |
| 3 | User can send a message | ✗ FAILED | onSubmit handler is logger.info only |
| 4 | Sent message appears in list | ✗ FAILED | No state update after send |
| 5 | Messages persist across refresh | ? UNCERTAIN | Can't verify - send doesn't work |

**Score:** 1/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/modules/Chat.ext` | Message list module | ✗ STUB | Returns `<div>Chat will be here</div>` |
| `src/modules/ChatInput.ext` | Message input | ✓ EXISTS + SUBSTANTIVE | Form with input, submit button, handlers |
| `src/services/chat/handler.ext` | Message CRUD | ✗ STUB | READ returns [], WRITE returns { ok: true } |
| `orm/schema.orm` | Message model | ✓ EXISTS + SUBSTANTIVE | Message model with id, content, userId, createdAt |

**Artifacts:** 2/4 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Chat.ext | /service/chat READ | service call | ✗ NOT WIRED | No service call in module |
| ChatInput | /service/chat WRITE | onSubmit | ✗ NOT WIRED | Handler only logs, doesn't service call |
| /service/chat READ | database | orm-tool.message.findMany | ✗ NOT WIRED | Returns hardcoded [] |
| /service/chat WRITE | database | orm-tool.message.create | ✗ NOT WIRED | Returns { ok: true }, no DB call |

**Wiring:** 0/4 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| CHAT-01: User can send message | ✗ BLOCKED | service write is stub |
| CHAT-02: User can view messages | ✗ BLOCKED | Component is placeholder |
| CHAT-03: Messages persist | ✗ BLOCKED | No database integration |

**Coverage:** 0/3 requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| src/modules/Chat.ext | 8 | `<div>Chat will be here</div>` | 🛑 Blocker | No actual content |
| src/services/chat/handler.ext | 5 | `return Response.json([])` | 🛑 Blocker | Hardcoded empty |
| src/services/chat/handler.ext | 12 | `// TODO: save to database` | ⚠️ Warning | Incomplete |

**Anti-patterns:** 3 found (2 blockers, 1 warning)

## Human Verification Required

None needed until automated gaps are fixed.

## Gaps Summary

### Critical Gaps (Block Progress)

1. **Chat module is placeholder**
   - Missing: Actual message list rendering
   - Impact: Users see "Chat will be here" instead of messages
   - Fix: Implement Chat.ext to service call and render messages

2. **service handlers are stubs**
   - Missing: Database integration in READ and WRITE
   - Impact: No data persistence, no real functionality
   - Fix: Wire orm-tool calls in route handlers

3. **No wiring between frontend and backend**
   - Missing: service calls in modules
   - Impact: Even if service worked, UI wouldn't call it
   - Fix: Add lifecycle hook service call in Chat, onSubmit service call in ChatInput

## Recommended Fix Plans

### 03-04-PLAN.md: Implement Chat service

**Objective:** Wire service handlers to database

**Tasks:**
1. Implement READ /service/chat with orm-tool.message.findMany
2. Implement WRITE /service/chat with orm-tool.message.create
3. Verify: Service returns real data, WRITE creates records

**Estimated scope:** Small

---

### 03-05-PLAN.md: Implement Chat UI

**Objective:** Wire Chat module to service

**Tasks:**
1. Implement Chat.ext with lifecycle hook service call and message rendering
2. Wire ChatInput onSubmit to WRITE /service/chat
3. Verify: Messages display, new messages appear after send

**Estimated scope:** Small

---

## Verification Metadata

**Verification approach:** Goal-backward (derived from phase goal)
**Must-haves source:** 03-01-PLAN.md frontmatter
**Automated checks:** 2 passed, 8 failed
**Human checks required:** 0 (blocked by automated failures)
**Total verification time:** 2 min

---
*Verified: 2025-01-15T14:30:00Z*
*Verifier: assistant (subagent)*
```

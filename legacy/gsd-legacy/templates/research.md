# Research Template

Template for `.planning/phases/XX-name/{phase}-RESEARCH.md` - comprehensive ecosystem research before planning.

**Purpose:** Document what assistant needs to know to implement a phase well - not just "which library" but "how do experts build this."

---

## File Template

```markdown
# Phase [X]: [Name] - Research

**Researched:** [date]
**Domain:** [primary technology/problem domain]
**Confidence:** [HIGH/MEDIUM/LOW]

<research_summary>
## Summary

[2-3 paragraph executive summary]
- What was researched
- What the standard approach is
- Key recommendations

**Primary recommendation:** [one-liner actionable guidance]
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| [name] | [ver] | [what it does] | [why experts use it] |
| [name] | [ver] | [what it does] | [why experts use it] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| [name] | [ver] | [what it does] | [use case] |
| [name] | [ver] | [what it does] | [use case] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| [standard] | [alternative] | [when alternative makes sense] |

**Installation:**
```bash
package-manager install [packages]
# or
package-manager install [packages]
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
src/
├── [folder]/        # [purpose]
├── [folder]/        # [purpose]
└── [folder]/        # [purpose]
```

### Pattern 1: [Pattern Name]
**What:** [description]
**When to use:** [conditions]
**Example:**
```text
// [code example from Context7/official docs]
```

### Pattern 2: [Pattern Name]
**What:** [description]
**When to use:** [conditions]
**Example:**
```text
// [code example]
```

### Anti-Patterns to Avoid
- **[Anti-pattern]:** [why it's bad, what to do instead]
- **[Anti-pattern]:** [why it's bad, what to do instead]
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| [problem] | [what you'd build] | [library] | [edge cases, complexity] |
| [problem] | [what you'd build] | [library] | [edge cases, complexity] |
| [problem] | [what you'd build] | [library] | [edge cases, complexity] |

**Key insight:** [why custom solutions are worse in this domain]
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: [Name]
**What goes wrong:** [description]
**Why it happens:** [root cause]
**How to avoid:** [prevention strategy]
**Warning signs:** [how to detect early]

### Pitfall 2: [Name]
**What goes wrong:** [description]
**Why it happens:** [root cause]
**How to avoid:** [prevention strategy]
**Warning signs:** [how to detect early]

### Pitfall 3: [Name]
**What goes wrong:** [description]
**Why it happens:** [root cause]
**How to avoid:** [prevention strategy]
**Warning signs:** [how to detect early]
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources:

### [Common Operation 1]
```text
// Source: [Context7/official docs URL]
[code]
```

### [Common Operation 2]
```text
// Source: [Context7/official docs URL]
[code]
```

### [Common Operation 3]
```text
// Source: [Context7/official docs URL]
[code]
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

What's changed recently:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| [old] | [new] | [date/version] | [what it means for implementation] |

**New tools/patterns to consider:**
- [Tool/Pattern]: [what it enables, when to use]
- [Tool/Pattern]: [what it enables, when to use]

**Deprecated/outdated:**
- [Thing]: [why it's outdated, what replaced it]
</sota_updates>

<open_questions>
## Open Questions

Things that couldn't be fully resolved:

1. **[Question]**
   - What we know: [partial info]
   - What's unclear: [the gap]
   - Recommendation: [how to handle during planning/execution]

2. **[Question]**
   - What we know: [partial info]
   - What's unclear: [the gap]
   - Recommendation: [how to handle]
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Context7 library ID] - [topics fetched]
- [Official docs URL] - [what was checked]

### Secondary (MEDIUM confidence)
- [WebSearch verified with official source] - [finding + verification]

### Tertiary (LOW confidence - needs validation)
- [WebSearch only] - [finding, marked for validation during implementation]
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: [what]
- Ecosystem: [libraries explored]
- Patterns: [patterns researched]
- Pitfalls: [areas checked]

**Confidence breakdown:**
- Standard stack: [HIGH/MEDIUM/LOW] - [reason]
- Architecture: [HIGH/MEDIUM/LOW] - [reason]
- Pitfalls: [HIGH/MEDIUM/LOW] - [reason]
- Code examples: [HIGH/MEDIUM/LOW] - [reason]

**Research date:** [date]
**Valid until:** [estimate - 30 days for stable tech, 7 days for fast-moving]
</metadata>

---

*Phase: XX-name*
*Research completed: [date]*
*Ready for planning: [yes/no]*
```

---

## Good Example

```markdown
# Phase 3: Real-time Collaboration - Research

**Researched:** 2025-01-20
**Domain:** Multi-user sync and conflict resolution
**Confidence:** HIGH

<research_summary>
## Summary

Researched the standard approach for real-time collaboration. The typical stack uses a transport layer for sync, a conflict-resolution strategy, and a shared state model that supports offline edits.

Key finding: Don’t hand-roll conflict resolution. Use a proven CRDT/OT library and focus on domain rules and UX.

**Primary recommendation:** Use SyncLib + StateLib + StorageAdapter. Start with a minimal shared document, wire persistence, then add presence and conflict handling.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SyncLib | 1.x | Real-time transport | Battle-tested sync layer |
| StateLib | 2.x | Shared state model | Predictable updates |
| StorageAdapter | 1.x | Persistence | Durable storage integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PresenceLib | 1.x | Online users | Cursor + presence UI |
| AuditLib | 1.x | Change history | Debugging + rollback |
| UIMergeLib | 1.x | Merge UX | User-friendly conflict resolution |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SyncLib | AltSyncLib | Simpler but less flexible |
| StateLib | Custom store | More control, more bugs |
| StorageAdapter | Direct DB calls | Faster to start, harder to migrate |

**Installation:**
```bash
package-manager install sync-lib state-lib storage-adapter
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Event-Driven Sync
**What:** Treat all collaboration changes as events with versioning
**When to use:** Any multi-user editing surface
**Example:**
```text
// Pseudo-code
onEvent(change):
  apply(change)
  persist(change)
  broadcast(change)
```

### Pattern 2: Server Reconciliation
**What:** Server validates and merges incoming changes
**When to use:** Concurrent edits or offline sync
**Example:**
```text
// Pseudo-code
onClientUpdate(update):
  if conflicts:
    merge(update, serverState)
  save(mergedState)
```

### Anti-Patterns to Avoid
- **Hand-rolled conflict resolution:** Edge cases explode quickly
- **Blind overwrites:** Loses user work
- **No audit trail:** Debugging becomes guesswork
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conflict resolution | Custom merge rules | CRDT/OT library | Correctness + scalability |
| Presence tracking | Polling loops | PresenceLib | Efficiency + UX |
| Sync protocol | Custom sockets | SyncLib | Reliability + tooling |
</dont_hand_roll>
```

---

## Guidelines

**When to create:**
- Before planning phases in niche/complex domains
- When assistant's training data is likely stale or sparse
- When "how do experts do this" matters more than "which library"

**Structure:**
- Use XML tags for section markers (matches GSD templates)
- Seven core sections: summary, standard_stack, architecture_patterns, dont_hand_roll, common_pitfalls, code_examples, sources
- All sections required (drives comprehensive research)

**Content quality:**
- Standard stack: Specific versions, not just names
- Architecture: Include actual code examples from authoritative sources
- Don't hand-roll: Be explicit about what problems to NOT solve yourself
- Pitfalls: Include warning signs, not just "don't do this"
- Sources: Mark confidence levels honestly

**Integration with planning:**
- RESEARCH.md loaded as @context reference in PLAN.md
- Standard stack informs library choices
- Don't hand-roll prevents custom solutions
- Pitfalls inform verification criteria
- Code examples can be referenced in task actions

**After creation:**
- File lives in phase directory: `.planning/phases/XX-name/{phase}-RESEARCH.md`
- Referenced during planning workflow
- plan-phase loads it automatically when present

# Structure Template

Template for `.planning/codebase/STRUCTURE.md` - captures physical file organization.

**Purpose:** Document where things physically live in the codebase. Answers "where do I put X?"

---

## File Template

```markdown
# Codebase Structure

**Analysis Date:** [YYYY-MM-DD]

## Directory Layout

[ASCII tree of top-level directories with purpose]

```
[project-root]/
├── [dir]/          # [Purpose]
├── [dir]/          # [Purpose]
├── [dir]/          # [Purpose]
└── [file]          # [Purpose]
```

## Directory Purposes

**[Directory Name]:**
- Purpose: [What lives here]
- Contains: [Types of files]
- Key files: [Important files in this directory]
- Subdirectories: [If nested, describe structure]

## Key File Locations

**Entry Points:**
- [Path]: [Purpose]

**Configuration:**
- [Path]: [Purpose]

**Core Logic:**
- [Path]: [Purpose]

**Testing:**
- [Path]: [Purpose]

**Documentation:**
- [Path]: [Purpose]

## Naming Conventions

**Files:**
- [Pattern]: [Example]

**Directories:**
- [Pattern]: [Example]

**Special Patterns:**
- [Pattern]: [Example]

## Where to Add New Code

**New Feature:**
- Primary code: [Directory path]
- Tests: [Directory path]
- Config if needed: [Directory path]

**New Module:**
- Implementation: [Directory path]
- Types: [Directory path]
- Tests: [Directory path]

**New Handler/Command:**
- Definition: [Directory path]
- Handler: [Directory path]
- Tests: [Directory path]

**Utilities:**
- Shared helpers: [Directory path]
- Type definitions: [Directory path]

## Special Directories

[Any directories with special meaning or generation]

**[Directory]:**
- Purpose: [e.g., "Generated code", "Build output"]
- Source: [e.g., "Auto-generated", "Build artifacts"]
- Committed: [Yes/No]

---

*Structure analysis: [date]*
*Update when directory structure changes*
```

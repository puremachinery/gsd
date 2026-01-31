# Coding Conventions Template

Template for `.planning/codebase/CONVENTIONS.md` - captures coding style and patterns.

**Purpose:** Document how code is written in this codebase. Prescriptive guide for assistant to match existing style.

---

## File Template

```markdown
# Coding Conventions

**Analysis Date:** [YYYY-MM-DD]

## Naming Patterns

**Files:**
- [Pattern: e.g., "kebab-case for files"]
- [Test files: e.g., "*.test.ext alongside source"]

**Functions:**
- [Pattern: e.g., "camelCase for functions"]
- [Handlers: e.g., "handleEventName for handlers"]

**Variables:**
- [Pattern: e.g., "camelCase for variables"]
- [Constants: e.g., "UPPER_SNAKE_CASE for constants"]

**Types:**
- [Pattern: e.g., "PascalCase for types"]

## Code Style

**Formatting:**
- [Tool: e.g., "formatter with config file"]
- [Line length: e.g., "100 characters max"]
- [Quotes: e.g., "single quotes"]

**Linting:**
- [Tool: e.g., "linter with config file"]
- [Rules: e.g., "project-recommended rules"]
- [Run: e.g., "run-lint"]

## Import Organization

**Order:**
1. [External packages]
2. [Internal modules]
3. [Relative imports]
4. [Type-only imports if supported]

**Grouping:**
- [Blank lines between groups]
- [Alphabetical within each group]

## Error Handling

**Patterns:**
- [Strategy: e.g., "throw errors, catch at boundaries"]
- [Custom errors: e.g., "extend Error class"]

**Error Types:**
- [When to throw vs return]
- [Logging: e.g., "log error with context before throwing"]

## Logging

**Framework:**
- [Tool: e.g., "logger, structured-logger"]
- [Levels: e.g., "debug, info, warn, error"]

**Patterns:**
- [Structured logging with context]
- [Avoid log-only statements]

## Comments

**When to Comment:**
- [Explain why, not what]
- [Document non-obvious logic]

**Doc comments:**
- [Usage: e.g., "required for public APIs"]
- [Format: e.g., "@param, @returns"]

**TODO Comments:**
- [Pattern: e.g., "// TODO: description"]

## Function Design

**Size:**
- [Keep under N lines]

**Parameters:**
- [Max N parameters]
- [Use options object if supported]

**Return Values:**
- [Explicit returns]

## Module Design

**Exports:**
- [Prefer explicit exports]
- [Keep entry points consistent]

**Aggregation Files:**
- [Use index-like aggregation if applicable]
- [Avoid circular dependencies]

---

*Convention analysis: [date]*
*Update when patterns change*
```

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
- [Pattern: e.g., "kebab-case for all files"]
- [Test files: e.g., "*.test.ext alongside source"]
- [Components: e.g., "PascalCase.ext for UIFramework modules"]

**Functions:**
- [Pattern: e.g., "camelCase for all functions"]
- [Async: e.g., "no special prefix for async functions"]
- [Handlers: e.g., "handleEventName for event handlers"]

**Variables:**
- [Pattern: e.g., "camelCase for variables"]
- [Constants: e.g., "UPPER_SNAKE_CASE for constants"]
- [Private: e.g., "_prefix for private members" or "no prefix"]

**Types:**
- [Interfaces: e.g., "PascalCase, no I prefix"]
- [Types: e.g., "PascalCase for type aliases"]
- [Enums: e.g., "PascalCase for enum name, UPPER_CASE for values"]

## Code Style

**Formatting:**
- [Tool: e.g., "formatter with config in formatter config file"]
- [Line length: e.g., "100 characters max"]
- [Quotes: e.g., "single quotes for strings"]
- [Semicolons: e.g., "required" or "omitted"]

**Linting:**
- [Tool: e.g., "linter with linter config file"]
- [Rules: e.g., "project-recommended rules, avoid ad-hoc stdout logging in production"]
- [Run: e.g., "run-lint"]

## Import Organization

**Order:**
1. [e.g., "External packages (ui-framework, web-framework, etc.)"]
2. [e.g., "Internal modules (@/lib, @/modules)"]
3. [e.g., "Relative imports (., ..)"]
4. [e.g., "Type-only imports (if supported)"]

**Grouping:**
- [Blank lines: e.g., "blank line between groups"]
- [Sorting: e.g., "alphabetical within each group"]

**Path Aliases:**
- [Aliases used: e.g., "@/ for src/, @modules/ for src/modules/"]

## Error Handling

**Patterns:**
- [Strategy: e.g., "throw errors, catch at boundaries"]
- [Custom errors: e.g., "extend Error class, named *Error"]
- [Async: e.g., "use try/catch, no .catch() chains"]

**Error Types:**
- [When to throw: e.g., "invalid input, missing dependencies"]
- [When to return: e.g., "expected failures return Result<T, E>"]
- [Logging: e.g., "log error with context before throwing"]

## Logging

**Framework:**
- [Tool: e.g., "logger, logging-lib, structured-logger"]
- [Levels: e.g., "debug, info, warn, error"]

**Patterns:**
- [Format: e.g., "structured logging with context object"]
- [When: e.g., "log state transitions, external calls"]
- [Where: e.g., "log at service boundaries, not in utils"]

## Comments

**When to Comment:**
- [e.g., "explain why, not what"]
- [e.g., "document business logic, algorithms, edge cases"]
- [e.g., "avoid obvious comments like // increment counter"]

**Doc comments:**
- [Usage: e.g., "required for public APIs, optional for internal"]
- [Format: e.g., "use @param, @returns, @throws tags"]

**TODO Comments:**
- [Pattern: e.g., "// TODO(username): description"]
- [Tracking: e.g., "link to issue number if available"]

## Function Design

**Size:**
- [e.g., "keep under 50 lines, extract helpers"]

**Parameters:**
- [e.g., "max 3 parameters, use object for more"]
- [e.g., "use named parameters or destructuring if supported"]

**Return Values:**
- [e.g., "explicit returns, no implicit undefined"]
- [e.g., "return early for guard clauses"]

## Module Design

**Exports:**
- [e.g., "prefer explicit exports; keep entry points consistent"]
- [e.g., "use index.ext to aggregate public API (if used)"]

**Aggregation Files:**
- [e.g., "use index.ext to aggregate public API (if used)"]
- [e.g., "avoid circular dependencies"]

---

*Convention analysis: [date]*
*Update when patterns change*
```

<good_examples>
```markdown
# Coding Conventions

**Analysis Date:** 2025-01-20

## Naming Patterns

**Files:**
- kebab-case for all files (command-handler.ext, user-service.ext)
- *.test.ext alongside source files
- index.ext for public API aggregation (if used)

**Functions:**
- camelCase for all functions
- No special prefix for async functions
- handleEventName for event handlers (handleClick, handleSubmit)

**Variables:**
- camelCase for variables
- UPPER_SNAKE_CASE for constants (MAX_RETRIES, API_BASE_URL)
- No underscore prefix (use language access controls if available)

**Types:**
- PascalCase for interfaces, no I prefix (User, not IUser)
- PascalCase for type aliases (UserConfig, ResponseData)
- PascalCase for enum names, UPPER_CASE for values (Status.PENDING)

## Code Style

**Formatting:**
- formatter with formatter config file
- 100 character line length
- Single quotes for strings
- Semicolons required
- 2 space indentation

**Linting:**
- linter with linter config file
- Extends linter-config/recommended
- Avoid ad-hoc stdout logging in production (use logger)
- Run: run-lint

## Import Organization

**Order:**
1. External packages (ui-framework, web-framework, cli-framework)
2. Internal modules (@/lib, @/services)
3. Relative imports (./utils, ../types)
4. Type-only imports (if supported)

**Grouping:**
- Blank line between groups
- Alphabetical within each group
- Type imports last within each group

**Path Aliases:**
- @/ maps to src/
- No other aliases defined

## Error Handling

**Patterns:**
- Throw errors, catch at boundaries (service handlers, entry points)
- Extend Error class for custom errors (ValidationError, NotFoundError)
- Async functions use try/catch, no .catch() chains

**Error Types:**
- Throw on invalid input, missing dependencies, invariant violations
- Log error with context before throwing: logger.error({ err, userId }, 'Failed to process')
- Include cause in error message: new Error('Failed to X', { cause: originalError })

## Logging

**Framework:**
- logger instance exported from lib/logger.ext
- Levels: debug, info, warn, error (no trace)

**Patterns:**
- Structured logging with context: logger.info({ userId, action }, 'User action')
- Log at service boundaries, not in utility functions
- Log state transitions, external service calls, errors
- Avoid log-only statements in committed code

## Comments

**When to Comment:**
- Explain why, not what: // Retry 3 times because API has transient failures
- Document business rules: // Users must verify email within 24 hours
- Explain non-obvious algorithms or workarounds
- Avoid obvious comments: // set count to 0

**Doc comments:**
- Required for public API functions
- Optional for internal functions if signature is self-explanatory
- Use @param, @returns, @throws tags

**TODO Comments:**
- Format: // TODO: description (no username, using git blame)
- Link to issue if exists: // TODO: Fix race condition (issue #123)

## Function Design

**Size:**
- Keep under 50 lines
- Extract helpers for complex logic
- One level of abstraction per function

**Parameters:**
- Max 3 parameters
- Use options object for 4+ parameters (or named params if supported)
- Use named parameters or destructure where supported

**Return Values:**
- Explicit return statements
- Return early for guard clauses
- Use Result<T, E> type for expected failures

## Module Design

**Exports:**
- Prefer explicit exports over implicit defaults
- Keep module entry points consistent across the codebase
- Expose public API via index.ext aggregation files (if used)

**Aggregation Files:**
- index.ext aggregates public API (if used)
- Keep internal helpers private (don't export from index)
- Avoid circular dependencies (import from specific files if needed)

---

*Convention analysis: 2025-01-20*
*Update when patterns change*
```
</good_examples>

<guidelines>
**What belongs in CONVENTIONS.md:**
- Naming patterns observed in the codebase
- Formatting rules (formatter config, linting rules)
- Import organization patterns
- Error handling strategy
- Logging approach
- Comment conventions
- Function and module design patterns

**What does NOT belong here:**
- Architecture decisions (that's ARCHITECTURE.md)
- Technology choices (that's STACK.md)
- Test patterns (that's TESTING.md)
- File organization (that's STRUCTURE.md)

**When filling this template:**
- Check formatter config file, .eslintrc, or similar config files
- Examine 5-10 representative source files for patterns
- Look for consistency: if 80%+ follows a pattern, document it
- Be prescriptive: "Use X" not "Sometimes Y is used"
- Note deviations: "Legacy code uses Y, new code should use X"
- Keep under ~150 lines total

**Useful for phase planning when:**
- Writing new code (match existing style)
- Adding features (follow naming patterns)
- Refactoring (apply consistent conventions)
- Code review (check against documented patterns)
- Onboarding (understand style expectations)

**Analysis approach:**
- Scan src/ directory for file naming patterns
- Check project.manifest scripts for lint/format commands
- Read 5-10 files to identify function naming, error handling
- Look for config files (formatter config file, linter config file)
- Note patterns in imports, comments, function signatures
</guidelines>

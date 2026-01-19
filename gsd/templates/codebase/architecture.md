# Architecture Template

Template for `.planning/codebase/ARCHITECTURE.md` - captures conceptual code organization.

**Purpose:** Document how the code is organized at a conceptual level. Complements STRUCTURE.md (physical locations).

---

## File Template

```markdown
# Architecture

**Analysis Date:** [YYYY-MM-DD]

## Pattern Overview

**Overall:** [Pattern name: e.g., "Monolith", "Layered service", "CLI tool", "Event-driven"]

**Key Characteristics:**
- [Characteristic 1]
- [Characteristic 2]
- [Characteristic 3]

## Layers

[Describe the conceptual layers and their responsibilities]

**[Layer Name]:**
- Purpose: [What this layer does]
- Contains: [Types of code: e.g., "handlers", "business logic"]
- Depends on: [What it uses]
- Used by: [What uses it]

**[Layer Name]:**
- Purpose:
- Contains:
- Depends on:
- Used by:

## Data / Control Flow

[Describe the typical request/execution lifecycle]

**[Flow Name] (e.g., "Command execution", "Request handling", "Event processing"):**

1. [Entry point]
2. [Processing step]
3. [Processing step]
4. [Output]

**State Management:**
- [How state is handled: e.g., "stateless", "data store per request", "in-memory cache"]

## Key Abstractions

[Core concepts/patterns used throughout the codebase]

**[Abstraction Name]:**
- Purpose: [What it represents]
- Examples: [Concrete examples]
- Pattern: [e.g., "Repository", "Factory", "Adapter"]

## Entry Points

[Where execution begins]

**[Entry Point]:**
- Location: [e.g., "src/main.ext"]
- Triggers: [e.g., "CLI invocation", "incoming request", "scheduled job"]
- Responsibilities: [Parse input, route, orchestrate]

## Error Handling

**Strategy:** [How errors are handled: e.g., "bubbling to top-level handler", "per-handler error wrapping"]

**Patterns:**
- [Pattern 1]
- [Pattern 2]

## Cross-Cutting Concerns

**Logging:**
- [Approach: e.g., "structured logger", "request-scoped context"]

**Validation:**
- [Approach: e.g., "schema validation at boundaries"]

**Authentication/Authorization:**
- [Approach: e.g., "policy checks in handlers"]

---

*Architecture analysis: [date]*
*Update when major patterns change*
```

<good_examples>
```markdown
# Architecture

**Analysis Date:** 2026-01-20

## Pattern Overview

**Overall:** CLI tool with layered services

**Key Characteristics:**
- Single executable
- File-based state
- Stateless command execution

## Layers

**Command Layer:**
- Purpose: Parse user input and route to handlers
- Contains: Command definitions, argument parsing
- Depends on: Service layer
- Used by: Entry point

**Service Layer:**
- Purpose: Core business logic
- Contains: Domain services, orchestration logic
- Depends on: Utilities, external adapters
- Used by: Command handlers

**Utility Layer:**
- Purpose: Shared helpers and adapters
- Contains: File I/O, formatting, integration clients
- Depends on: Standard library
- Used by: Service layer

## Data / Control Flow

**Command execution:**

1. User invokes command
2. Argument parsing and validation
3. Handler calls service methods
4. Services read/write artifacts
5. Results returned to user

**State Management:**
- File-based state in a project planning directory
- Each command execution is independent

## Key Abstractions

**Service:**
- Purpose: Encapsulate domain logic
- Examples: ProjectService, TemplateService
- Pattern: Module-level services

**Adapter:**
- Purpose: Wrap external integrations
- Examples: VCSAdapter, RemoteAPIAdapter
- Pattern: Interface + implementation

## Entry Points

**CLI Entry:**
- Location: `src/main.ext`
- Triggers: CLI invocation
- Responsibilities: Register commands, parse args, route

## Error Handling

**Strategy:** Exceptions bubble to command layer, logged and surfaced to user

**Patterns:**
- Input validation at boundaries
- Consistent error codes and messages

## Cross-Cutting Concerns

**Logging:**
- Structured logging with context

**Validation:**
- Schema checks at boundaries

**Authentication/Authorization:**
- Token checks in adapter layer

---

*Architecture analysis: 2026-01-20*
```
</good_examples>

<guidelines>
**What belongs in ARCHITECTURE.md:**
- Overall architectural pattern
- Conceptual layers and relationships
- Data/control flow
- Key abstractions and patterns
- Entry points
- Error handling strategy
- Cross-cutting concerns

**What does NOT belong here:**
- Exhaustive file listings (use STRUCTURE.md)
- Technology choices (use STACK.md)
- Line-by-line code walkthroughs
- Feature-specific implementation details

**File paths ARE welcome:**
Include file paths as concrete examples of abstractions. Use backticks.

**When filling this template:**
- Read main entry points (main/server/worker)
- Identify layers by reading imports/dependencies
- Trace a typical execution path
- Note recurring patterns (services, adapters, repositories)
- Keep descriptions conceptual, not mechanical
</guidelines>

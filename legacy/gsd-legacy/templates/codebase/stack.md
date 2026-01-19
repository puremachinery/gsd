# Technology Stack Template

Template for `.planning/codebase/STACK.md` - captures the technology foundation.

**Purpose:** Document what technologies run this codebase. Focused on "what executes when you run the code."

---

## File Template

```markdown
# Technology Stack

**Analysis Date:** [YYYY-MM-DD]

## Languages

**Primary:**
- [Language] [Version] - [Where used: e.g., "all application code"]

**Secondary:**
- [Language] [Version] - [Where used: e.g., "build scripts, tooling"]

## Runtime

**Environment:**
- [Runtime] [Version] - [e.g., "RuntimeName 1.2"]
- [Additional requirements if any]

**Package Manager:**
- [Manager] [Version] - [e.g., "PackageManager 3.4"]
- Lockfile: [e.g., "lockfile.ext present"]

## Frameworks

**Core:**
- [Framework] [Version] - [Purpose: e.g., "web server", "UI framework"]

**Testing:**
- [Framework] [Version] - [e.g., "unit tests"]
- [Framework] [Version] - [e.g., "E2E tests"]

**Build/Dev:**
- [Tool] [Version] - [e.g., "bundler", "compiler"]
- [Tool] [Version] - [e.g., "type checker"]

## Key Dependencies

[Only include dependencies critical to understanding the stack - limit to 5-10 most important]

**Critical:**
- [Package] [Version] - [Why it matters: e.g., "authentication", "database access"]
- [Package] [Version] - [Why it matters]

**Infrastructure:**
- [Package] [Version] - [e.g., "HTTP client", "cache client"]

## Configuration

**Environment:**
- [How configured: e.g., ".env files", "environment variables"]
- [Key configs: e.g., "DATABASE_URL, API_KEY required"]

**Build:**
- [Build config files: e.g., "build-config.ext"]

## Platform Requirements

**Development:**
- [OS requirements or "any platform"]
- [Additional tooling: e.g., "ContainerTool for local DB"]

**Production:**
- [Deployment target: e.g., "container", "serverless", "VM"]
- [Version requirements]

---

*Stack analysis: [date]*
*Update after major dependency changes*
```

<good_examples>
```markdown
# Technology Stack

**Analysis Date:** 2025-01-20

## Languages

**Primary:**
- LanguageA 1.0 - All application code

**Secondary:**
- LanguageB 2.0 - Build scripts and tooling

## Runtime

**Environment:**
- RuntimeA 1.0 (native)
- No VM/runtime required at runtime

**Package Manager:**
- PackageManagerA 2.1
- Lockfile: `lockfile.ext` present

## Frameworks

**Core:**
- FrameworkA 3.2 - Web server

**Testing:**
- TestFrameworkA 4.0 - Unit tests
- TestFrameworkB 2.0 - E2E tests

**Build/Dev:**
- BuildToolA 1.5 - Bundling
- TypeToolA 0.9 - Static checks

## Key Dependencies

**Critical:**
- DependencyA 5.0 - Authentication
- DependencyB 1.2 - Database access

**Infrastructure:**
- DependencyC 0.4 - HTTP client

## Configuration

**Environment:**
- Config via environment variables
- Required: API_TOKEN, DATABASE_URL

**Build:**
- `build-config.ext` - Build configuration

## Platform Requirements

**Development:**
- macOS/Linux/Windows
- Toolchain matching runtime version

**Production:**
- Distributed as native artifacts
- No runtime dependencies

---

*Stack analysis: 2025-01-20*
*Update after major dependency changes*
```
</good_examples>

<guidelines>
**What belongs in STACK.md:**
- Languages and versions
- Runtime requirements (language runtime, VM, browser)
- Package manager and lockfile
- Framework choices
- Critical dependencies (limit to 5-10 most important)
- Build tooling
- Platform/deployment requirements

**What does NOT belong here:**
- File structure (that's STRUCTURE.md)
- Architectural patterns (that's ARCHITECTURE.md)
- Every dependency in the manifest (only critical ones)
- Implementation details (defer to code)

**When filling this template:**
- Check manifest files (go.mod, pyproject.toml, Cargo.toml, etc.) for dependencies
- Note runtime version from manifest files or toolchain config
- Include only dependencies that affect understanding (not every utility)
- Specify versions only when version matters (breaking changes, compatibility)

**Useful for phase planning when:**
- Adding new dependencies (check compatibility)
- Upgrading frameworks (know what's in use)
- Choosing implementation approach (must work with existing stack)
- Understanding build requirements
</guidelines>

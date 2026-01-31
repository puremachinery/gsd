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
- [Language] [Version] - [Where used]

**Secondary:**
- [Language] [Version] - [Where used]

## Runtime

**Environment:**
- [Runtime] [Version] - [e.g., "RuntimeName 1.2"]
- [Additional requirements if any]

**Package/Dependency Manager:**
- [Manager] [Version]
- Lockfile: [e.g., "lockfile.ext present"]

## Frameworks & Tooling

**Core:**
- [Framework] [Version] - [Purpose]

**Testing:**
- [Framework] [Version] - [Purpose]

**Build/Dev:**
- [Tool] [Version] - [Purpose]

## Key Dependencies

[Only include dependencies critical to understanding the stack - limit to 5-10 most important]

**Critical:**
- [Dependency] [Version] - [Why it matters]

**Infrastructure:**
- [Dependency] [Version] - [Purpose]

## Configuration

**Environment:**
- [How configured: e.g., env files, config files]
- [Key configs: e.g., "DATABASE_URL, API_KEY required"]

**Build:**
- [Build config files]

## Platform Requirements

**Development:**
- [OS requirements or "any platform"]
- [Additional tooling]

**Production:**
- [Deployment target: e.g., "container", "serverless", "VM", "native binary"]
- [Version requirements]

---

*Stack analysis: [date]*
*Update after major dependency changes*
```

<guidelines>
**What belongs in STACK.md:**
- Languages and versions
- Runtime requirements (language runtime, VM, browser)
- Package/dependency manager and lockfile
- Framework choices
- Critical dependencies (limit to 5-10)
- Build tooling
- Platform/deployment requirements

**What does NOT belong here:**
- File structure (STRUCTURE.md)
- Architectural patterns (ARCHITECTURE.md)
- Every dependency in the manifest
- Implementation details of specific features

**When filling this template:**
- Check manifest files for dependencies
- Note runtime version from toolchain config
- Include only dependencies that affect understanding
- Specify versions only when version matters
</guidelines>

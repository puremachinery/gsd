# GSD Architecture Spec

## Overview

GSD is a meta-prompting system with two distinct components:
1. **Prompt content** (~21k lines of markdown) - the actual value
2. **Installer/hooks** (~700 lines) - plumbing to install and integrate

This spec defines how to restructure for multi-platform support (Claude Code + Codex CLI) and port the installer from Node.js to Nim.

---

## Directory Structure

```
gsd/
├── core/                           # Platform-agnostic content
│   ├── templates/                  # File structure templates
│   │   ├── project.md              # PROJECT.md structure
│   │   ├── requirements.md         # REQUIREMENTS.md structure
│   │   ├── roadmap.md              # ROADMAP.md structure
│   │   ├── state.md                # STATE.md structure
│   │   ├── plan.md                 # PLAN.md structure
│   │   ├── summary.md              # SUMMARY.md structure
│   │   └── ...                     # Other templates (codebase/, research/)
│   ├── references/                 # Deep-dive guides
│   │   ├── questioning.md          # Interview techniques
│   │   ├── verification.md         # Testing patterns
│   │   ├── deviation-rules.md      # Auto-fix rules
│   │   ├── git-integration.md      # Commit conventions
│   │   └── ...
│   └── concepts/                   # Workflow philosophy docs
│       ├── context-engineering.md  # Why fresh contexts matter
│       ├── phase-workflow.md       # Plan→execute→verify cycle
│       └── file-structure.md       # .planning/ directory spec
│
├── platforms/
│   ├── claude/                     # Claude Code implementation
│   │   ├── commands/gsd/           # 24 slash commands
│   │   ├── workflows/              # Orchestration workflows
│   │   ├── agents/                 # 11 subagent definitions
│   │   └── hooks/                  # statusline.nim, update.nim (compiled)
│   │
│   └── codex/                      # Codex CLI implementation (future)
│       ├── skills/gsd/             # SKILL.md equivalents
│       ├── orchestration/          # Agents SDK workflows
│       └── config/                 # AGENTS.md template
│
├── installer/                      # Nim source
│   ├── src/
│   │   ├── gsd.nim                 # Main entry point
│   │   ├── install.nim             # Installation logic
│   │   ├── statusline.nim          # Status bar hook
│   │   ├── update.nim              # Update checker
│   │   ├── config.nim              # Config resolution
│   │   └── settings.nim            # settings.json handling
│   ├── gsd.nimble                  # Build configuration
│   └── tests/                      # Installation tests
│
├── dist/                           # Built binaries (gitignored)
│   ├── gsd-darwin-arm64
│   ├── gsd-darwin-x64
│   ├── gsd-linux-x64
│   └── gsd-windows-x64.exe
│
├── ARCHITECTURE.md                 # This file
├── REVIEW_NOTES.md                 # Review findings
├── CHANGELOG.md
├── LICENSE
└── README.md
```

**Compatibility note:** Existing command files reference `@~/.claude/gsd/...`. To avoid breaking, keep `~/.claude/gsd/` as the install root and nest new `core/` + `platforms/` inside it, or update all @-refs in platform files.

---

## Prompt Strategy

**Decision: Separate files per platform, not templates.**

Rationale:
- Tool names differ (`Read` vs `read_file`) but so do capabilities and idioms
- Workflows differ (Task tool vs Agents SDK orchestration)
- Templating adds complexity; maintenance burden is acceptable given ~2 platforms
- Keeps each platform's prompts idiomatic rather than lowest-common-denominator

Core content (templates/, references/, concepts/) is shared and platform-agnostic - it describes *what* to do, not *how* to invoke tools.

Platform-specific content (commands/, workflows/, agents/) implements the *how* using each platform's idioms.

---

## Repo/Binary Strategy

**Decision:** Single repo + single binary, with a `--platform` flag to target Claude or Codex installs.

**Config isolation:** Do not store Codex config under `.claude`. Each platform uses its own config root (Claude: `.claude`, Codex: its native config directory such as `$CODEX_HOME` or a user-specified path). The installer writes platform-specific defaults so they never collide.

---

## Config Resolution

**Problem:** Hooks need to know where GSD is installed (global `~/.claude`, custom dir, or local `./.claude`).

**Solution:** Write a `gsd-config.json` at install time; hooks read it.

```json
{
  "version": "2.0.0",
  "install_type": "global",
  "config_dir": "/Users/name/.claude",
  "installed_at": "2026-01-17T10:30:00Z"
}
```

Location: `{config_dir}/gsd-config.json`

Hooks resolve config dir:
1. Read `GSD_CONFIG_DIR` env var if set
2. Else check for `./.claude/gsd-config.json` (local install)
3. Else check for `~/.claude/gsd-config.json` (global install)
4. Fail with clear error if none found

This eliminates all hardcoded `~/.claude` paths in hooks.

**CWD caveat:** Hooks may run with a different working directory. Prefer writing absolute paths into `settings.json` (e.g., `command: "/abs/path/gsd statusline --config-dir /abs/path"`) to avoid cwd ambiguity.

### Split-Brain Scenario

**Problem:** User has both global (`~/.claude`) and local (`./.claude`) installs. Running `gsd update` or `gsd doctor` from inside the local project - which installation does it act on?

**Solution:** CLI commands explicitly resolve and report which environment they target.

Resolution order for CLI commands:
1. Explicit `--config-dir` flag (highest priority)
2. Local `./.claude/gsd-config.json` if present in CWD
3. Global `~/.claude/gsd-config.json`

**Output must always state the target:**
```
Updating local installation at /path/to/project/.claude...
```
or
```
Updating global installation at ~/.claude...
```

To force a specific target when both exist:
```bash
gsd update --global              # Explicit global
gsd update --local               # Explicit local
gsd update --config-dir ~/.claude-work  # Explicit custom
```

---

## Codex Config Root Detection

**Goal:** Install Codex assets into Codex's own config root, not `.claude`.

**Resolution order (Codex installs):**
1. Explicit `--config-dir` flag (highest priority)
2. `$CODEX_HOME` env var (Codex standard)
3. Default Codex config dir (e.g., `~/.codex` or platform default)

Write `gsd-config.json` into the resolved Codex config dir and ensure all Codex hooks/skills reference that path.

---

## Settings Merge Strategy

**Problem:** Users may have custom hooks/statusLine; current installer can clobber them.

**Solution:** Merge, don't replace.

```
1. Read existing settings.json (or {} if missing/invalid)
2. If parse fails: backup to settings.json.bak, warn user, start fresh
3. Merge GSD hooks into existing hooks array (dedupe by exact command match or a stable GSD token)
4. For statusLine: auto-migrate if old GSD, prompt only if custom (see below)
5. Write merged result
```

**Hook deduplication:** Avoid substring matching. Prefer exact command matches, or tag the command with a stable marker (e.g., `#gsd`) so replacements only touch GSD-owned hooks.

### Statusline Auto-Migration

**Problem:** Prompting the user every time is fatiguing. But we can't blindly overwrite custom statuslines.

**Solution:** Recognize known old GSD patterns and auto-migrate; prompt only for truly custom scripts.

Known old GSD statusline patterns (auto-migrate silently):
```
node ~/.claude/hooks/statusline.js
node "$HOME/.claude/hooks/statusline.js"
node .claude/hooks/statusline.js
```

If the existing statusline matches any of these patterns → replace without prompting.

If the existing statusline is something else (e.g., `python my_custom_bar.py`, `~/bin/my-statusline`) → prompt user in interactive mode, skip in non-interactive mode.

### JSON Resilience

Hand-edited JSON files often have issues (trailing commas, comments). The installer should:
1. Try standard JSON parse first
2. On failure, backup the file and warn user
3. Start with empty `{}` rather than crashing

In Nim, use `try/except` aggressively around all JSON parsing.

---

## Local vs Global Storage

**Decision:** Local installs use local storage; global installs use global storage.

| Install Type | Config Dir | Cache/Todos | VERSION |
|--------------|------------|-------------|---------|
| Global | `~/.claude/` | `~/.claude/cache/`, `~/.claude/todos/` | `~/.claude/gsd/VERSION` |
| Global+custom | `{custom}/` | `{custom}/cache/`, `{custom}/todos/` | `{custom}/gsd/VERSION` |
| Local | `./.claude/` | `./.claude/cache/`, `./.claude/todos/` | `./.claude/gsd/VERSION` |

Hooks read `gsd-config.json` to resolve paths. No hardcoding.

**Resolution rule:** If both local and global installs exist, prefer local when invoked from that project; otherwise, require `--config-dir` in the command to avoid ambiguity.

---

## Installer CLI

```
gsd [command] [options]

Commands:
  install     Install GSD (default if no command)
  uninstall   Remove GSD from config dir
  doctor      Validate installation health
  update      Check for and install updates

Install options:
  -g, --global              Install to ~/.claude (default)
  -l, --local               Install to ./.claude
  -c, --config-dir <path>   Custom config directory
  --force-statusline        Replace existing statusline
  --platform <name>         Target platform: claude (default), codex

Other options:
  -h, --help                Show help
  -v, --version             Show version
  --verbose                 Verbose output
```

**Examples:**
```bash
gsd install --global                    # Standard global install
gsd install --local                     # Project-only install
gsd install --config-dir ~/.claude-work # Custom config dir
gsd install --platform codex            # Install for Codex CLI
gsd doctor                              # Validate installation
gsd update                              # Update to latest
```

---

## Build & Distribution

### Cross-Compilation Targets

| Target | Triple | Output |
|--------|--------|--------|
| macOS ARM | `aarch64-apple-darwin` | `gsd-darwin-arm64` |
| macOS Intel | `x86_64-apple-darwin` | `gsd-darwin-x64` |
| Linux x64 | `x86_64-linux-gnu` | `gsd-linux-x64` |
| Windows x64 | `x86_64-windows-gnu` | `gsd-windows-x64.exe` |

### Build Commands

```bash
# Development
nimble build

# Release (optimized, stripped)
nimble build -d:release --opt:size
strip dist/gsd-*

# Cross-compile (requires appropriate toolchains)
nimble build -d:release --cpu:amd64 --os:linux
nimble build -d:release --cpu:amd64 --os:windows
```

### Distribution Channels

1. **GitHub Releases** - Primary; attach binaries to releases
2. **Homebrew** - Formula downloads from GitHub releases
3. **Direct download** - curl/wget one-liner in README

**Homebrew formula sketch:**
```ruby
class Gsd < Formula
  desc "Meta-prompting system for Claude Code and Codex CLI"
  homepage "https://github.com/puremachinery/gsd"
  version "2.0.0"

  on_macos do
    on_arm do
      url "https://github.com/.../gsd-darwin-arm64"
      sha256 "..."
    end
    on_intel do
      url "https://github.com/.../gsd-darwin-x64"
      sha256 "..."
    end
  end

  def install
    bin.install "gsd-darwin-#{Hardware::CPU.arch}" => "gsd"
  end
end
```

---

## Update Mechanism

**Current:** Shells out to `npm view` on every session start.

**New:** HTTP check against GitHub API (no npm dependency).

```nim
# Check latest release
GET https://api.github.com/repos/puremachinery/gsd/releases/latest
Headers:
  User-Agent: gsd-cli/2.0.0
  Authorization: Bearer $GITHUB_TOKEN  # if env var present
  If-None-Match: <cached ETag>         # if available

# Parse response for tag_name
# Compare with installed VERSION
# Cache result in {config_dir}/cache/gsd-update-check.json
```

### Rate Limit Handling

GitHub API limits:
- Unauthenticated: 60 requests/hour/IP
- With `GITHUB_TOKEN`: 5,000 requests/hour

**Implementation:**
1. Always send `User-Agent: gsd-cli/{version}` (required by GitHub)
2. If `GITHUB_TOKEN` env var exists, include `Authorization: Bearer {token}`
3. Store and reuse ETag header to minimize actual requests (304 Not Modified doesn't count against limit)
4. Cache TTL: 24 hours

**Fail-open policy:** If API returns 403 (rate limited), 5xx (server error), or network fails:
- Treat as "no update available"
- Do not block session startup
- Do not show error to user (silent failure)
- Log to debug file if `--verbose` was used

---

## Statusline Protocol

Claude Code sends JSON to statusline hook via stdin:

```json
{
  "model": {"display_name": "Claude Sonnet 4"},
  "workspace": {"current_dir": "/path/to/project"},
  "session_id": "abc123",
  "context_window": {"remaining_percentage": 75}
}
```

Hook outputs formatted string to stdout:

```
Claude Sonnet 4 │ Building auth system │ project │ ██████░░░░ 60%
```

Context bar colors:
- Green: <50% used
- Yellow: 50-65% used
- Orange: 65-80% used
- Red+blink: >80% used

---

## Testing Strategy

### Installer Tests

```nim
# tests/test_install.nim
suite "installation":
  test "global install creates expected structure":
    # ...

  test "local install creates expected structure":
    # ...

  test "custom config dir works":
    # ...

  test "reinstall is idempotent":
    # ...

  test "settings.json merge preserves user hooks":
    # ...

  test "invalid settings.json triggers backup":
    # ...
```

### Manual Smoke Tests

1. Fresh global install → verify `/gsd:help` works
2. Fresh local install → verify `/gsd:help` works
3. Upgrade from previous version → verify no orphaned files
4. Install with existing statusline → verify prompt appears
5. Install with custom config dir → verify hooks resolve correctly

---

## Migration Path

### From Node.js (v1.x) to Nim (v2.x)

1. User runs `gsd install --global` (downloads Nim binary)
2. Installer detects existing installation from original project (if any)
3. Removes old Node.js hooks (`gsd-check-update.js`, `statusline.js`)
4. Installs new Nim hooks
5. Updates `settings.json` hook commands to point to new binary
6. Writes `gsd-config.json`

---

## Open Decisions (Resolved)

| Question | Decision |
|----------|----------|
| Local vs global cache | Follow install type (local→local, global→global) |
| Settings merge | Merge hooks, prompt for statusLine conflict |
| Prompt templating | Separate files per platform, not templates |
| Codex parity | Full parity target; Skills + Agents SDK |
| Distribution | GitHub releases + Homebrew formula |

---

## Nim Implementation Notes

### ANSI Colors (Cross-Platform)

Using raw ANSI escape codes for colors. Windows requires special handling.

**Windows Virtual Terminal Processing:**
```nim
when defined(windows):
  import std/winlean

  proc enableVirtualTerminal() =
    let handle = getStdHandle(STD_OUTPUT_HANDLE)
    var mode: DWORD
    discard getConsoleMode(handle, addr mode)
    mode = mode or ENABLE_VIRTUAL_TERMINAL_PROCESSING
    discard setConsoleMode(handle, mode)
```

Call `enableVirtualTerminal()` early in `main()` on Windows before any ANSI output.

**Fallback:** If enabling VT fails (very old Windows), strip ANSI codes and output plain text.

### JSON Parsing

Nim's standard `json` module is strict. For resilience:

```nim
import std/[json, options]

proc parseJsonSafe(content: string): Option[JsonNode] =
  try:
    return some(parseJson(content))
  except JsonParsingError:
    return none(JsonNode)
```

Use `Option[T]` throughout config handling to gracefully handle missing/malformed data.

### HTTP Client

Use Nim's `std/httpclient` for GitHub API calls:

```nim
import std/[httpclient, json, os]

proc checkForUpdate(configDir: string): Option[string] =
  let client = newHttpClient(timeout = 5000)
  client.headers = newHttpHeaders({
    "User-Agent": "gsd-cli/" & Version,
    "Accept": "application/vnd.github.v3+json"
  })

  # Add auth if available
  let token = getEnv("GITHUB_TOKEN")
  if token.len > 0:
    client.headers["Authorization"] = "Bearer " & token

  try:
    let resp = client.get("https://api.github.com/repos/.../releases/latest")
    if resp.status == "200 OK":
      let data = parseJson(resp.body)
      return some(data["tag_name"].getStr())
  except:
    discard  # Fail silently

  return none(string)
```

### File Operations

Use `std/os` for cross-platform file operations:
- `copyFile`, `copyDir` for installation
- `removeFile`, `removeDir` for cleanup
- `existsFile`, `existsDir` for checks
- `expandTilde` for `~` expansion (note: manual on Windows)

---

## Out of Scope (For Now)

- Gemini CLI support (architectural mismatch; revisit if they add multi-agent)
- GUI installer
- Auto-update (user runs `gsd update` manually)
- Telemetry/analytics

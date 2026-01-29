<div align="center">

# GSD

**Get Stuff Done.** *(Or, you know, the other version.)*

A meta-prompting and context engineering system for Claude Code and Codex CLI.

[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

</div>

---

## What Is This?

GSD is a structured workflow system that makes AI coding assistants reliable at scale. It solves **context rot** — the quality degradation that happens as the AI fills its context window during long projects.

The system provides:
- **24 slash commands** for project lifecycle management
- **Multi-agent orchestration** with fresh context per task
- **Spec-driven development** (plan → execute → verify)
- **Atomic git commits** per task for clean, bisectable history
- **Session continuity** across context resets

## Status

**Active.** The installer is a native Nim binary; releases bundle the binary and all prompt content.

## Platforms

| Platform | Status |
|----------|--------|
| Claude Code | Supported |
| Codex CLI | Supported (beta) |

## Installation

Download the release bundle for your platform from:

https://github.com/puremachinery/gsd/releases

Then:

```bash
# Extract the release bundle
tar -xzf gsd-darwin-arm64.tar.gz
cd gsd-darwin-arm64

# Install globally (to ~/.claude)
./install --global

# Or install locally (to ./.claude in current project)
./install --local

# Install for Codex CLI (to ~/.codex)
./install --platform=codex --global
```

Release bundles are available for:
- macOS (Apple Silicon — also runs on Intel via Rosetta 2): `gsd-darwin-arm64.tar.gz`
- Linux (x64): `gsd-linux-x64.tar.gz`
- Windows (x64): `gsd-windows-x64.zip`

Each bundle contains:
- `gsd` binary (or `gsd.exe` on Windows)
- `gsd/` directory (templates, workflows, references)
- `commands/` directory (slash command definitions)
- `agents/` directory (subagent definitions)

## Core Workflow

```
/gsd:new-project     # Define requirements, create roadmap
/gsd:discuss-phase   # Capture implementation vision
/gsd:plan-phase      # Create detailed execution plans
/gsd:execute-phase   # Run plans with fresh context per task
/gsd:verify-work     # Manual acceptance testing
/gsd:complete-milestone  # Ship and archive
```

## How It Works

GSD keeps AI assistants capable throughout large projects by:

1. **Fresh context per subagent** — Heavy work happens in spawned agents with clean 200k context windows
2. **Thin orchestrator** — Main context stays at 30-40% utilization
3. **Persistent state** — `STATE.md` preserves decisions across context resets
4. **Size-limited artifacts** — Templates enforce concise documentation

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details.

## Building from Source

Requires [Nim](https://nim-lang.org/) 2.0+.

```bash
git clone https://github.com/puremachinery/gsd.git
cd gsd/installer
nimble build          # build the binary
nimble test           # run tests
nimble format         # format code with nimpretty
nimble check          # format check + build + test (used by pre-push hook)
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## Attribution

Based on [GET SHIT DONE](https://github.com/glittercowboy/get-shit-done) by Lex Christopherson (TÂCHES), licensed under MIT.

## License

MIT — see [LICENSE](LICENSE)

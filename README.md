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

**Work in progress.** The installer is being rewritten in Nim to remove Node.js dependencies.

The prompt engineering content (commands, workflows, templates, agents) is functional and derived from [glittercowboy/get-shit-done](https://github.com/glittercowboy/get-shit-done).

## Platforms

| Platform | Status |
|----------|--------|
| Claude Code | Primary target |
| Codex CLI | Planned |

## Installation

*Coming soon.* Once the Nim installer is complete, download the binary for your platform from:

https://github.com/puremachinery/gsd/releases

Then:

```bash
# Rename the binary for your platform (example for Apple Silicon):
mv gsd-darwin-arm64 gsd
chmod +x gsd
./gsd install --global
```

Binaries will be available for:
- macOS (Apple Silicon): `gsd-darwin-arm64`
- macOS (Intel): `gsd-darwin-x64`
- Linux (x64): `gsd-linux-x64`
- Windows (x64): `gsd-windows-x64.exe`

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

## Attribution

Based on [GET SHIT DONE](https://github.com/glittercowboy/get-shit-done) by Lex Christopherson (TÂCHES), licensed under MIT.

## License

MIT — see [LICENSE](LICENSE)

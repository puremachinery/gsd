# Changelog

All notable changes to GSD will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planned
- Installer rewritten in Nim (no Node.js dependency)
- Multi-platform support (Claude Code + Codex CLI)
- `gsd-config.json` for proper config directory resolution
- Split-brain handling for local vs global installs
- GitHub API update checking (no npm dependency)
- ETag caching and GITHUB_TOKEN support for rate limits
- Auto-migration of old GSD statusline configurations
- Windows virtual terminal processing for ANSI colors
- Settings.json merge preserves user's custom hooks
- Invalid settings.json backed up instead of silently replaced

---

## Attribution

This project is based on [GET SHIT DONE](https://github.com/glittercowboy/get-shit-done) by Lex Christopherson (TÂCHES), licensed under MIT.

The prompt engineering content (commands, workflows, templates, agents) is derived from the original project. The installer is being rewritten in Nim to remove Node.js dependencies and add multi-platform support.

See the [original project's changelog](https://github.com/glittercowboy/get-shit-done/blob/main/CHANGELOG.md) for history prior to this fork.

[Unreleased]: https://github.com/puremachinery/gsd/commits/master

# Changelog

All notable changes to GSD will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

---

## [0.3.0] - 2026-01-26

### Added
- Shared `.gsd/` directory for platform-agnostic resources (templates, workflows, references)
- Multi-platform install UX (interactive platform selection, `--platform` flag)
- Config resolution chain: `--config-dir` > `GSD_CONFIG_DIR` > local `.gsd/` > global `~/.gsd/` > legacy fallback
- `gsd doctor` checks all discovered installations (local + global, per-platform)
- Platform inference for custom config directories
- CLI integration tests

### Changed
- `gsd-config.json` moves from tool directory to `.gsd/`; uses `gsd_dir` and `platforms` array (replaces v0.2 `config_dir` and `platform` string)
- `gsd update` re-installs all discovered installations (local + global)
- Prompt content separated from installer; tool directories contain only integration files

## [0.2.0] - 2026-01-19

### Added
- Codex CLI support (`~/.codex/prompts/`, `AGENTS.md`, `config.toml` hooks)
- Native installer in Nim (replaces Node.js)
- Multi-platform support (macOS ARM/Intel, Linux, Windows)
- `gsd-config.json` for config directory resolution
- Support for local, global, and custom config directories
- GitHub API update checking with ETag caching
- `GITHUB_TOKEN` support for higher rate limits
- Auto-migration of old GSD statusline configurations
- Windows virtual terminal processing for ANSI colors
- Settings.json merge preserves user's custom hooks
- Invalid settings.json backed up instead of silently replaced
- Path rewriting for @-references based on install type
- Comprehensive test suite for installer

### Removed
- Node.js dependency
- Legacy `hooks/` directory structure

---

[Unreleased]: https://github.com/puremachinery/gsd/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/puremachinery/gsd/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/puremachinery/gsd/commits/v0.2.0

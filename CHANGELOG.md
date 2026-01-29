# Changelog

All notable changes to GSD will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

---

## [0.3.1] - 2026-01-28

### Added
- Install rollback on partial failure (freshly created directories removed, pre-existing directories preserved, settings.json backed up and restored)
- GitHub API retry logic (1 retry with 500ms delay on network/timeout errors)
- Update cache lifecycle tests (isCacheValid, loadCachedResult, saveCacheResult, ETag round-trip)
- Claude Code install end-to-end tests (full structure verification, rollback validation)
- Pre-push hook and `nimble check` task for local validation
- CONTRIBUTING.md and GitHub issue template

### Fixed
- CI: install libpcre3-dev on Ubuntu for PCRE dependency
- Shell-escape paths in hook command strings to prevent injection
- Guard expandPath against empty slice on `~/` and `%USERPROFILE%/`
- Use CatchableError instead of bare `except:` in isInteractive
- HTTP timeout reduced from 15s to 3s for session start hook

### Removed
- Dead `runUpdateAll` proc (never called; real logic is in `gsd.nim:cmdUpdate`)

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

[Unreleased]: https://github.com/puremachinery/gsd/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/puremachinery/gsd/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/puremachinery/gsd/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/puremachinery/gsd/commits/v0.2.0

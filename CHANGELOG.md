# Changelog

All notable changes to GSD will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
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
- `gsd doctor` command for installation health checks
- Comprehensive test suite for installer

### Changed
- Platform-agnostic prompt content separated from installer

### Removed
- Node.js dependency
- Legacy `hooks/` directory structure

---

[Unreleased]: https://github.com/puremachinery/gsd/commits/master

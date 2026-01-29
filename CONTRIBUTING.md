# Contributing to GSD

Thanks for your interest in contributing. Here's how to get started.

## Setup

1. Install [Nim](https://nim-lang.org/) 2.0+
2. Clone the repo and build:
   ```bash
   git clone https://github.com/puremachinery/gsd.git
   cd gsd/installer
   nimble build
   nimble test
   ```
3. Set up the pre-push hook:
   ```bash
   git config core.hooksPath .githooks
   ```

## Development Workflow

- Source is in `installer/src/`, tests in `installer/tests/`
- Format code: `nimble format` (enforced by CI)
- Run tests: `nimble test`
- Full check before pushing: `nimble check`

## Making Changes

1. Create a branch from `master`
2. Make your changes
3. Add or update tests for any new behavior
4. Run `nimble check` to verify formatting, build, and tests all pass
5. Open a pull request

## Code Style

- Line length: 100 characters (enforced by nimpretty)
- No external dependencies — stdlib only
- Error handling: use `CatchableError`, never bare `except:`
- Shell paths: always use `quoteShell` when embedding paths in commands

## What to Work On

Check [open issues](https://github.com/puremachinery/gsd/issues) for bugs and feature requests. Issues labeled `good first issue` are a good starting point.

## Reporting Bugs

Use the [bug report template](https://github.com/puremachinery/gsd/issues/new?template=bug_report.md) and include:
- GSD version (`gsd --version`)
- Platform (macOS/Linux/Windows)
- Steps to reproduce
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

# Package
version       = "0.3.0"
author        = "Zera Alexander"
description   = "GSD installer and hooks for Claude Code and Codex CLI"
license       = "MIT"
srcDir        = "src"
bin           = @["gsd"]

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task test, "Run tests":
  exec "nim c -r tests/test_platform.nim"
  exec "nim c -r tests/test_toml.nim"
  exec "nim c -r tests/test_config.nim"
  exec "nim c -r tests/test_install.nim"
  exec "nim c -r tests/test_statusline.nim"
  exec "nim c -r tests/test_update.nim"
  exec "nim c -r tests/test_cli_integration.nim"

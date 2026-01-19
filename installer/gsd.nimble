# Package
version       = "0.1.0"
author        = "Zera Alexander"
description   = "GSD installer and hooks for Claude Code (Codex CLI planned)"
license       = "MIT"
srcDir        = "src"
bin           = @["gsd"]

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task test, "Run tests":
  exec "nim c -r tests/test_config.nim"
  exec "nim c -r tests/test_install.nim"
  exec "nim c -r tests/test_statusline.nim"
  exec "nim c -r tests/test_update.nim"

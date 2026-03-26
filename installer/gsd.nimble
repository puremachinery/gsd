import os

# Package
version       = "0.3.5"
author        = "mach"
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

task format, "Format source with nimpretty":
  for f in listFiles("src") & listFiles("tests"):
    if f.endsWith(".nim"):
      exec "nimpretty --maxLineLen:100 " & quoteShell(f)

task smoke_script, "Run the bootstrap smoke contract script":
  when defined(windows):
    echo "Skipping bootstrap smoke on Windows; requires Bash."
  else:
    exec "bash ../scripts/smoke/bootstrap-contract.sh gsd"

task smoke, "Run bootstrap smoke contract":
  exec "nimble build -y"
  exec "nimble smoke_script -y"

task verify, "Run format check, build, tests, and bootstrap smoke":
  # Format check (diff-based, non-destructive)
  var failed = false
  for f in listFiles("src") & listFiles("tests"):
    if f.endsWith(".nim"):
      let quotedFile = quoteShell(f)
      let quotedBackup = quoteShell(f & ".bak")
      cpFile(f, f & ".bak")
      let (_, fmtCode) = gorgeEx("nimpretty --maxLineLen:100 " & quotedFile)
      if fmtCode != 0:
        echo "nimpretty failed on: " & f
        failed = true
      else:
        let (_, diffCode) = gorgeEx("diff -q " & quotedFile & " " & quotedBackup)
        if diffCode != 0:
          echo "Not formatted: " & f
          failed = true
      mvFile(f & ".bak", f)
  if failed:
    echo "Format check failed. Run 'nimble format' to fix."
    quit(1)
  echo "Format check passed."
  # Build
  exec "nimble build -y"
  # Tests
  exec "nimble test -y"
  # Smoke
  exec "nimble smoke_script -y"

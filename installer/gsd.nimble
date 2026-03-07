# Package
version       = "0.3.3"
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

task format, "Format source with nimpretty":
  for f in listFiles("src") & listFiles("tests"):
    if f.endsWith(".nim"):
      exec "nimpretty --maxLineLen:100 " & f

task smokeScript, "Run the bootstrap smoke contract script":
  exec "bash ../scripts/smoke/bootstrap-contract.sh gsd"

task smoke, "Run bootstrap smoke contract":
  exec "nimble build -y"
  exec "nimble smokeScript -y"

task verify, "Run format check, build, tests, and bootstrap smoke":
  # Format check (diff-based, non-destructive)
  var failed = false
  for f in listFiles("src") & listFiles("tests"):
    if f.endsWith(".nim"):
      cpFile(f, f & ".bak")
      let (fmtOut, fmtCode) = gorgeEx("nimpretty --maxLineLen:100 " & f)
      if fmtCode != 0:
        echo "nimpretty failed on: " & f
        failed = true
      else:
        let (_, diffCode) = gorgeEx("diff -q " & f & " " & f & ".bak")
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
  exec "nimble smokeScript -y"

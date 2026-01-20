## Integration tests for gsd CLI flows

import std/[unittest, os, osproc, strutils, json, envvars, streams, times]
import ../src/config
import ../src/platform

proc repoRoot(): string =
  parentDir(getCurrentDir())

proc buildGsdBinary(): string =
  var binPath = getTempDir() / "gsd-test-bin" / "gsd-test"
  if fileExists(binPath):
    return binPath

  createDir(parentDir(binPath))
  let sourcePath = repoRoot() / "installer" / "src" / "gsd.nim"
  let p = startProcess(
    "nim",
    args = @["c", "-o:" & binPath, sourcePath],
    options = {poUsePath, poStdErrToStdOut}
  )
  let output = readAll(p.outputStream)
  let code = p.waitForExit()
  p.close()

  if code != 0:
    raise newException(OSError, "Failed to build gsd binary: " & output)

  return binPath

proc prepareWorkspace(): string =
  let workDir = getTempDir() / ("gsd_cli_work_" & $epochTime().int)
  createDir(workDir)
  copyDir(repoRoot() / "gsd", workDir / "gsd")
  copyDir(repoRoot() / "commands", workDir / "commands")
  copyDir(repoRoot() / "agents", workDir / "agents")
  return workDir

proc writeConfig(dir: string, p: Platform, installType: InstallType) =
  createDir(dir)
  let payload = %*{
    "version": Version,
    "install_type": $installType,
    "platform": $p,
    "config_dir": dir,
    "installed_at": "2026-01-01T00:00:00Z"
  }
  writeFile(dir / ConfigFileName, payload.pretty())

proc seedClaudeInstall(workDir, dir: string, installType: InstallType) =
  writeConfig(dir, pClaudeCode, installType)
  copyDir(workDir / "gsd", dir / "gsd")
  createDir(dir / "commands")
  copyDir(workDir / "commands" / "gsd", dir / "commands" / "gsd")
  copyDir(workDir / "agents", dir / "agents")
  writeFile(dir / "gsd" / VersionFileName, Version)

proc seedMinimalInstall(dir: string, p: Platform, installType: InstallType) =
  writeConfig(dir, p, installType)
  createDir(dir / "gsd")
  writeFile(dir / "gsd" / VersionFileName, Version)

proc clearEnvVar(key: string) =
  if getEnv(key).len > 0:
    delEnv(key)

suite "CLI integration":
  test "update --platform=claude updates local and global installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localDir = workDir / ".claude"
    let globalDir = tempHome / ".claude"

    writeConfig(localDir, pClaudeCode, itLocal)
    writeConfig(globalDir, pClaudeCode, itGlobal)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    clearEnvVar(ConfigEnvVar)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    let output = execProcess(
      bin,
      args = @["update", "--platform=claude"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check output.contains("Update complete!")
    check fileExists(localDir / "gsd" / VersionFileName)
    check fileExists(globalDir / "gsd" / VersionFileName)

  test "uninstall --platform=claude removes local and global installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localDir = workDir / ".claude"
    let globalDir = tempHome / ".claude"

    seedMinimalInstall(localDir, pClaudeCode, itLocal)
    seedMinimalInstall(globalDir, pClaudeCode, itGlobal)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    clearEnvVar(ConfigEnvVar)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    discard execProcess(
      bin,
      args = @["uninstall", "--platform=claude"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check not fileExists(localDir / ConfigFileName)
    check not fileExists(globalDir / ConfigFileName)
    check not dirExists(localDir / "gsd")
    check not dirExists(globalDir / "gsd")

  test "doctor --platform ignores GSD_CONFIG_DIR for mismatched platform":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localDir = workDir / ".claude"
    let envDir = tempHome / "gsd-env"

    writeConfig(localDir, pClaudeCode, itLocal)
    writeConfig(envDir, pCodexCli, itCustom)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    putEnv(ConfigEnvVar, envDir)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    let output = execProcess(
      bin,
      args = @["doctor", "--platform=claude"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check output.contains(localDir)
    check not output.contains(envDir)

  test "doctor without flags checks multiple installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localDir = workDir / ".claude"
    let globalDir = tempHome / ".claude"

    seedClaudeInstall(workDir, localDir, itLocal)
    seedClaudeInstall(workDir, globalDir, itGlobal)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    clearEnvVar(ConfigEnvVar)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    let output = execProcess(
      bin,
      args = @["doctor"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check output.contains(localDir)
    check output.contains(globalDir)
    check output.contains("Summary: 0 issue(s), 2 warning(s) across 2 installation(s)")

  test "update without platform updates all installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let claudeLocal = workDir / ".claude"
    let codexLocal = workDir / ".codex"
    let claudeGlobal = tempHome / ".claude"
    let codexGlobal = tempHome / ".codex"

    writeConfig(claudeLocal, pClaudeCode, itLocal)
    writeConfig(codexLocal, pCodexCli, itLocal)
    writeConfig(claudeGlobal, pClaudeCode, itGlobal)
    writeConfig(codexGlobal, pCodexCli, itGlobal)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    clearEnvVar(ConfigEnvVar)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    let output = execProcess(
      bin,
      args = @["update"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check output.contains("Update complete!")
    for dir in [claudeLocal, codexLocal, claudeGlobal, codexGlobal]:
      check fileExists(dir / "gsd" / VersionFileName)

  test "uninstall --all removes all installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let claudeLocal = workDir / ".claude"
    let codexLocal = workDir / ".codex"
    let claudeGlobal = tempHome / ".claude"
    let codexGlobal = tempHome / ".codex"

    seedMinimalInstall(claudeLocal, pClaudeCode, itLocal)
    seedMinimalInstall(codexLocal, pCodexCli, itLocal)
    seedMinimalInstall(claudeGlobal, pClaudeCode, itGlobal)
    seedMinimalInstall(codexGlobal, pCodexCli, itGlobal)

    let oldHome = getEnv("HOME")
    let oldEnv = getEnv(ConfigEnvVar)
    putEnv("HOME", tempHome)
    clearEnvVar(ConfigEnvVar)
    defer:
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      if oldEnv.len > 0: putEnv(ConfigEnvVar, oldEnv) else: delEnv(ConfigEnvVar)
      removeDir(workDir)
      removeDir(tempHome)

    discard execProcess(
      bin,
      args = @["uninstall", "--all"],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    for dir in [claudeLocal, codexLocal, claudeGlobal, codexGlobal]:
      check not fileExists(dir / ConfigFileName)
      check not dirExists(dir / "gsd")

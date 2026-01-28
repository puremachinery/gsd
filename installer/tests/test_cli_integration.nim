## Integration tests for gsd CLI flows

import std/[unittest, os, osproc, strutils, json, envvars, streams, times]
import ../src/config
import ../src/platform

proc repoRoot(): string =
  parentDir(getCurrentDir())

proc buildGsdBinary(): string =
  var binPath = getTempDir() / "gsd-test-bin" / "gsd-test"
  let sourceDir = repoRoot() / "installer" / "src"
  if fileExists(binPath):
    let binTime = getLastModificationTime(binPath)
    var needsRebuild = false
    for path in walkDirRec(sourceDir):
      if path.endsWith(".nim") and getLastModificationTime(path) > binTime:
        needsRebuild = true
        break
    if not needsRebuild:
      return binPath

  createDir(parentDir(binPath))
  let sourcePath = sourceDir / "gsd.nim"
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

proc writeConfig(gsdDir: string, platforms: seq[Platform], installType: InstallType) =
  ## Write a v0.3 gsd-config.json to a .gsd/ directory
  createDir(gsdDir)
  var platArr = newJArray()
  for p in platforms:
    platArr.add(%($p))
  let payload = %*{
    "version": Version,
    "install_type": $installType,
    "gsd_dir": gsdDir,
    "platforms": platArr,
    "installed_at": "2026-01-01T00:00:00Z"
  }
  writeFile(gsdDir / ConfigFileName, payload.pretty())

proc seedClaudeInstall(workDir, gsdDir: string, installType: InstallType) =
  ## Seed a v0.3 install: shared resources in .gsd/, tool files in .claude/
  writeConfig(gsdDir, @[pClaudeCode], installType)
  # Copy shared resources into .gsd/ (contents, not the dir itself)
  let gsdSource = workDir / "gsd"
  for kind, path in walkDir(gsdSource):
    let name = extractFilename(path)
    if kind == pcDir:
      copyDir(path, gsdDir / name)
    elif kind == pcFile:
      copyFile(path, gsdDir / name)
  writeFile(gsdDir / VersionFileName, Version)
  # Tool-specific files in .claude/ (sibling of .gsd/)
  let scopeRoot = parentDir(gsdDir)
  let toolDir = scopeRoot / ".claude"
  createDir(toolDir / "commands")
  copyDir(workDir / "commands" / "gsd", toolDir / "commands" / "gsd")
  createDir(toolDir / "agents")
  for kind, path in walkDir(workDir / "agents"):
    if kind == pcFile:
      copyFile(path, toolDir / "agents" / extractFilename(path))

proc seedMinimalInstall(gsdDir: string, platforms: seq[Platform], installType: InstallType) =
  ## Seed a minimal v0.3 install: config + VERSION in .gsd/
  writeConfig(gsdDir, platforms, installType)
  writeFile(gsdDir / VersionFileName, Version)

proc clearEnvVar(key: string) =
  if getEnv(key).len > 0:
    delEnv(key)

suite "CLI integration":
  test "update --platform=claude updates local and global installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let globalGsd = tempHome / ".gsd"

    writeConfig(localGsd, @[pClaudeCode], itLocal)
    writeConfig(globalGsd, @[pClaudeCode], itGlobal)

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
    check fileExists(localGsd / VersionFileName)
    check fileExists(globalGsd / VersionFileName)

  test "uninstall --platform=claude removes local and global installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let globalGsd = tempHome / ".gsd"

    seedMinimalInstall(localGsd, @[pClaudeCode], itLocal)
    seedMinimalInstall(globalGsd, @[pClaudeCode], itGlobal)

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

    # .gsd/ dirs should be removed (only platform was claude)
    check not dirExists(localGsd)
    check not dirExists(globalGsd)

  test "doctor --platform ignores GSD_CONFIG_DIR for mismatched platform":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let envDir = tempHome / "gsd-env"

    writeConfig(localGsd, @[pClaudeCode], itLocal)
    writeConfig(envDir, @[pCodexCli], itCustom)

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

    check output.contains(localGsd)
    check not output.contains(envDir)

  test "doctor without flags checks multiple installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let globalGsd = tempHome / ".gsd"

    seedClaudeInstall(workDir, localGsd, itLocal)
    seedClaudeInstall(workDir, globalGsd, itGlobal)

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

    check output.contains(localGsd)
    check output.contains(globalGsd)
    check output.contains("Summary: 0 issue(s), 2 warning(s) across 2 installation(s)")

  test "update without platform updates all installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let globalGsd = tempHome / ".gsd"

    writeConfig(localGsd, @[pClaudeCode, pCodexCli], itLocal)
    writeConfig(globalGsd, @[pClaudeCode, pCodexCli], itGlobal)

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
    check fileExists(localGsd / VersionFileName)
    check fileExists(globalGsd / VersionFileName)

  test "uninstall --all removes all installs":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_home_" & $epochTime().int)
    createDir(tempHome)

    let localGsd = workDir / ".gsd"
    let globalGsd = tempHome / ".gsd"

    seedMinimalInstall(localGsd, @[pClaudeCode, pCodexCli], itLocal)
    seedMinimalInstall(globalGsd, @[pClaudeCode, pCodexCli], itGlobal)

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

    # .gsd/ dirs should be removed
    check not dirExists(localGsd)
    check not dirExists(globalGsd)

  test "uninstall --config-dir uses custom .gsd/ directory":
    let bin = buildGsdBinary()
    let workDir = prepareWorkspace()
    let tempHome = getTempDir() / ("gsd_cli_custom_" & $epochTime().int)
    createDir(tempHome)

    let customGsd = tempHome / "gsd-custom"

    # Set up custom .gsd/ with config
    seedMinimalInstall(customGsd, @[pClaudeCode], itCustom)

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
      args = @["uninstall", "--config-dir", customGsd],
      options = {poUsePath, poStdErrToStdOut},
      workingDir = workDir
    )

    check output.contains("Uninstalling GSD")
    # .gsd/ should be removed (single platform)
    check not dirExists(customGsd)

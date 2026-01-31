## Tests for config.nim

import std/[unittest, os, strutils, options, envvars]
import ../src/config
import ../src/platform

proc hasInstall(installs: seq[InstalledConfig], p: Platform, dir: string): bool =
  for item in installs:
    if item.platform == p and item.dir == dir:
      return true
  return false

suite "expandPath":
  test "tilde alone expands to home directory":
    let result = expandPath("~")
    # normalizedPath removes trailing slashes
    check result == getHomeDir().normalizedPath

  test "tilde with path expands correctly":
    let result = expandPath("~/foo/bar")
    check result == (getHomeDir() / "foo/bar").normalizedPath

  test "tilde with trailing slash":
    let result = expandPath("~/")
    # ~/ expands to home dir (normalized, no trailing slash)
    check result == getHomeDir().normalizedPath

  test "tilde username style returns as-is":
    let result = expandPath("~otheruser/path")
    check result == "~otheruser/path"

  test "absolute path unchanged":
    let result = expandPath("/usr/local/bin")
    check result == "/usr/local/bin"

  test "relative path unchanged":
    let result = expandPath("relative/path")
    check result == "relative/path"

  test "empty string unchanged":
    let result = expandPath("")
    check result == ""

suite "getLocalConfigDir":
  test "returns .gsd in current directory":
    let result = getLocalConfigDir()
    check result == getCurrentDir() / ".gsd"

suite "getGlobalConfigDir":
  test "returns .gsd in home directory":
    let result = getGlobalConfigDir()
    check result == getHomeDir() / ".gsd"

suite "getGsdCacheDir":
  test "returns cache subdirectory":
    let result = getGsdCacheDir("/some/path")
    check result == "/some/path/cache"

suite "getGsdDir":
  test "returns path directly":
    let result = getGsdDir("/some/path")
    check result == "/some/path"

suite "Version constant":
  test "version is defined":
    check Version.len > 0
    check Version.contains(".")

suite "expandPath Windows compatibility":
  # These tests verify the function handles various path formats
  # that could appear on Windows or Unix systems

  test "handles forward slashes":
    let result = expandPath("~/foo/bar/baz")
    check result.contains("foo")
    check result.contains("bar")

  test "handles paths with dots":
    let result = expandPath("./relative/path")
    check result == "./relative/path"

  test "handles paths with parent refs":
    let result = expandPath("../parent/path")
    check result == "../parent/path"

  test "does not expand tilde in middle of path":
    let result = expandPath("/some/~path/file")
    check result == "/some/~path/file"

suite "config round-trip":
  test "saveConfig and loadConfig work together":
    # Create temp directory for test
    let tempDir = getTempDir() / "gsd_test_config"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let config = GsdConfig(
      version: "1.2.3",
      installType: itLocal,
      platforms: @[pClaudeCode, pCodexCli],
      gsdDir: "/test/path",
      installedAt: "2025-01-01T00:00:00Z"
    )

    check saveConfig(config, tempDir) == true

    let loaded = loadConfig(tempDir)
    check loaded.isSome
    check loaded.get().version == "1.2.3"
    check loaded.get().installType == itLocal
    check loaded.get().platforms == @[pClaudeCode, pCodexCli]
    check loaded.get().gsdDir == "/test/path"
    check loaded.get().installedAt == "2025-01-01T00:00:00Z"

  test "loadConfig returns none for missing file":
    let result = loadConfig("/nonexistent/path")
    check result.isNone

  test "loadConfig returns none for invalid JSON":
    let tempDir = getTempDir() / "gsd_test_invalid"
    createDir(tempDir)
    defer: removeDir(tempDir)

    writeFile(tempDir / "gsd-config.json", "not valid json")

    let result = loadConfig(tempDir)
    check result.isNone

suite "findConfigDir resolution":
  test "uses GSD_CONFIG_DIR when set":
    let tempDir = getTempDir() / "gsd_test_env"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let oldEnv = getEnv(ConfigEnvVar)
    putEnv(ConfigEnvVar, tempDir)
    defer:
      if oldEnv.len > 0:
        putEnv(ConfigEnvVar, oldEnv)
      else:
        delEnv(ConfigEnvVar)

    let found = findConfigDir()
    check found.isSome
    check found.get() == tempDir

  test "falls back to legacy codex config when .gsd/ not present":
    let originalDir = getCurrentDir()
    let tempHome = getTempDir() / "gsd_test_home"
    let tempWork = getTempDir() / "gsd_test_work"
    createDir(tempHome)
    createDir(tempWork)
    defer:
      setCurrentDir(originalDir)
      removeDir(tempHome)
      removeDir(tempWork)

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    defer:
      if oldHome.len > 0:
        putEnv("HOME", oldHome)
      else:
        delEnv("HOME")

    let oldEnv = getEnv(ConfigEnvVar)
    if oldEnv.len > 0:
      delEnv(ConfigEnvVar)
    defer:
      if oldEnv.len > 0:
        putEnv(ConfigEnvVar, oldEnv)
      else:
        delEnv(ConfigEnvVar)

    setCurrentDir(tempWork)

    # v0.2 legacy: config in tool dir
    let codexDir = tempHome / ".codex"
    createDir(codexDir)
    writeFile(codexDir / ConfigFileName, "{}")

    let found = findConfigDir()
    check found.isSome
    check found.get() == codexDir

  test "findConfigDir(platform) ignores env dir if platform mismatches":
    let originalDir = getCurrentDir()
    let tempHome = getTempDir() / "gsd_test_env_platform_home"
    let tempWork = getTempDir() / "gsd_test_env_platform_work"
    createDir(tempHome)
    createDir(tempWork)
    defer:
      setCurrentDir(originalDir)
      removeDir(tempHome)
      removeDir(tempWork)

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    defer:
      if oldHome.len > 0:
        putEnv("HOME", oldHome)
      else:
        delEnv("HOME")

    let oldEnv = getEnv(ConfigEnvVar)
    defer:
      if oldEnv.len > 0:
        putEnv(ConfigEnvVar, oldEnv)
      else:
        delEnv(ConfigEnvVar)

    setCurrentDir(tempWork)

    # v0.3 config with only codex platform
    let envDir = tempHome / ".envcodex"
    createDir(envDir)
    writeFile(envDir / ConfigFileName, """{"platforms":["codex"],"gsd_dir":"/tmp"}""")
    putEnv(ConfigEnvVar, envDir)

    let found = findConfigDir(pClaudeCode)
    check found.isNone

  test "findConfigDir(platform) uses env dir when config has matching platform":
    let tempDir = getTempDir() / "gsd_test_env_markers"
    createDir(tempDir)
    writeFile(tempDir / ConfigFileName, """{"platforms":["codex"],"gsd_dir":"/tmp"}""")
    defer: removeDir(tempDir)

    let oldEnv = getEnv(ConfigEnvVar)
    putEnv(ConfigEnvVar, tempDir)
    defer:
      if oldEnv.len > 0:
        putEnv(ConfigEnvVar, oldEnv)
      else:
        delEnv(ConfigEnvVar)

    let found = findConfigDir(pCodexCli)
    check found.isSome
    check found.get() == tempDir

suite "install enumeration":
  test "inferInstallType identifies local/global/custom":
    let originalDir = getCurrentDir()
    let tempHome = getTempDir() / "gsd_test_infer_home"
    let tempWork = getTempDir() / "gsd_test_infer_work"
    createDir(tempHome)
    createDir(tempWork)
    defer:
      setCurrentDir(originalDir)
      removeDir(tempHome)
      removeDir(tempWork)

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    defer:
      if oldHome.len > 0:
        putEnv("HOME", oldHome)
      else:
        delEnv("HOME")

    setCurrentDir(tempWork)

    check inferInstallType(platform.getLocalGsdDir()) == itLocal
    check inferInstallType(platform.getGlobalGsdDir()) == itGlobal
    check inferInstallType(tempHome / "custom") == itCustom

  test "inferPlatformFromDir detects Claude markers":
    let tempDir = getTempDir() / "gsd_test_infer_claude"
    createDir(tempDir / "commands" / "gsd")
    createDir(tempDir / "agents")
    writeFile(tempDir / "agents" / "gsd-agent.md", "# agent")
    defer: removeDir(tempDir)

    let inferred = inferPlatformFromDir(tempDir)
    check inferred.isSome
    check inferred.get() == pClaudeCode

  test "inferPlatformFromDir detects Codex markers":
    let tempDir = getTempDir() / "gsd_test_infer_codex"
    createDir(tempDir / "prompts")
    writeFile(tempDir / "prompts" / "gsd-help.md", "# prompt")
    writeFile(tempDir / "AGENTS.md", "# agents")
    defer: removeDir(tempDir)

    let inferred = inferPlatformFromDir(tempDir)
    check inferred.isSome
    check inferred.get() == pCodexCli

  test "listInstalledConfigs returns platforms from .gsd/ config":
    let originalDir = getCurrentDir()
    let tempHome = getTempDir() / "gsd_test_list_home"
    let tempWork = getTempDir() / "gsd_test_list_work"
    createDir(tempHome)
    createDir(tempWork)
    defer:
      setCurrentDir(originalDir)
      removeDir(tempHome)
      removeDir(tempWork)

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    defer:
      if oldHome.len > 0:
        putEnv("HOME", oldHome)
      else:
        delEnv("HOME")

    let oldEnv = getEnv(ConfigEnvVar)
    if oldEnv.len > 0:
      delEnv(ConfigEnvVar)
    defer:
      if oldEnv.len > 0:
        putEnv(ConfigEnvVar, oldEnv)
      else:
        delEnv(ConfigEnvVar)

    setCurrentDir(tempWork)

    # v0.3: local .gsd/ with both platforms
    let localGsd = platform.getLocalGsdDir()
    createDir(localGsd)
    writeFile(localGsd / ConfigFileName, """{"platforms":["claude","codex"],"gsd_dir":"/tmp"}""")

    # v0.3: global .gsd/ with just claude
    let globalGsd = platform.getGlobalGsdDir()
    createDir(globalGsd)
    writeFile(globalGsd / ConfigFileName, """{"platforms":["claude"],"gsd_dir":"/tmp"}""")

    let installs = listInstalledConfigs()
    check hasInstall(installs, pClaudeCode, localGsd)
    check hasInstall(installs, pCodexCli, localGsd)
    check hasInstall(installs, pClaudeCode, globalGsd)

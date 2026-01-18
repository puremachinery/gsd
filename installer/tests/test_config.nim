## Tests for config.nim

import std/[unittest, os, strutils]
import ../src/config

suite "expandPath":
  test "tilde alone expands to home directory":
    let result = expandPath("~")
    check result == getHomeDir()

  test "tilde with path expands correctly":
    let result = expandPath("~/foo/bar")
    check result == getHomeDir() / "foo/bar"

  test "tilde with trailing slash":
    let result = expandPath("~/")
    check result == getHomeDir() / ""

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
  test "returns .claude in current directory":
    let result = getLocalConfigDir()
    check result == getCurrentDir() / ".claude"

suite "getGlobalConfigDir":
  test "returns .claude in home directory":
    let result = getGlobalConfigDir()
    check result == getHomeDir() / ".claude"

suite "getGsdCacheDir":
  test "returns cache subdirectory":
    let result = getGsdCacheDir("/some/path")
    check result == "/some/path/cache"

suite "getGsdDir":
  test "returns gsd subdirectory":
    let result = getGsdDir("/some/path")
    check result == "/some/path/gsd"

suite "Version constant":
  test "version is defined":
    check Version.len > 0
    check Version.contains(".")

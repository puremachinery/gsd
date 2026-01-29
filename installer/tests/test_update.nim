## Tests for update.nim

import std/[unittest, os, json, options, times]
import ../src/update

suite "compareVersions":
  test "equal versions return 0":
    check compareVersions("1.0.0", "1.0.0") == 0
    check compareVersions("2.5.3", "2.5.3") == 0

  test "older version returns -1":
    check compareVersions("1.0.0", "1.0.1") == -1
    check compareVersions("1.0.0", "1.1.0") == -1
    check compareVersions("1.0.0", "2.0.0") == -1

  test "newer version returns 1":
    check compareVersions("1.0.1", "1.0.0") == 1
    check compareVersions("1.1.0", "1.0.0") == 1
    check compareVersions("2.0.0", "1.0.0") == 1

  test "handles v prefix":
    check compareVersions("v1.0.0", "1.0.0") == 0
    check compareVersions("1.0.0", "v1.0.0") == 0
    check compareVersions("v1.0.0", "v1.0.1") == -1

  test "handles V prefix":
    check compareVersions("V1.0.0", "1.0.0") == 0

  test "handles two-part versions":
    check compareVersions("1.0", "1.0.0") == 0
    check compareVersions("1.0", "1.0.1") == -1
    check compareVersions("1.1", "1.0.0") == 1

  test "handles single-part versions":
    check compareVersions("1", "1.0.0") == 0
    check compareVersions("2", "1.0.0") == 1

  test "handles pre-release tags":
    # Pre-release part is stripped, only numeric compared
    check compareVersions("1.0.0-beta", "1.0.0") == 0
    check compareVersions("1.0.0-alpha", "1.0.0-beta") == 0
    check compareVersions("1.0.0-rc1", "1.0.1") == -1

  test "major version takes precedence":
    check compareVersions("2.0.0", "1.9.9") == 1
    check compareVersions("1.9.9", "2.0.0") == -1

  test "minor version takes precedence over patch":
    check compareVersions("1.2.0", "1.1.9") == 1
    check compareVersions("1.1.9", "1.2.0") == -1

  test "handles whitespace":
    check compareVersions(" 1.0.0 ", "1.0.0") == 0
    check compareVersions("1.0.0", " 1.0.0 ") == 0

  test "real world versions":
    check compareVersions("0.1.0", "0.1.1") == -1
    check compareVersions("1.6.4", "1.6.3") == 1
    check compareVersions("1.6.4", "2.0.0") == -1

  test "handles empty parts gracefully":
    # Edge case: should not crash
    check compareVersions("1..0", "1.0.0") == 0

suite "isCacheValid":
  test "returns false for missing file":
    check isCacheValid("/nonexistent/path/cache.json") == false

  test "returns true for fresh cache":
    let tempDir = getTempDir() / "gsd_test_cache_valid"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    let freshTime = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    let cacheJson = %*{
      "checked_at": freshTime,
      "current_version": "0.3.0",
      "latest_version": "0.3.0",
      "update_available": false,
      "release_url": "",
      "etag": ""
    }
    writeFile(cachePath, cacheJson.pretty())

    check isCacheValid(cachePath) == true

  test "returns false for expired cache":
    let tempDir = getTempDir() / "gsd_test_cache_expired"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    # 25 hours ago
    let expiredTime = (now().utc - initDuration(hours = 25)).format(
        "yyyy-MM-dd'T'HH:mm:ss'Z'")
    let cacheJson = %*{
      "checked_at": expiredTime,
      "current_version": "0.3.0",
      "latest_version": "0.3.0",
      "update_available": false,
      "release_url": "",
      "etag": ""
    }
    writeFile(cachePath, cacheJson.pretty())

    check isCacheValid(cachePath) == false

  test "returns false for corrupt JSON":
    let tempDir = getTempDir() / "gsd_test_cache_corrupt"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    writeFile(cachePath, "not valid json {{{")

    check isCacheValid(cachePath) == false

suite "loadCachedResult":
  test "returns None for missing file":
    let result = loadCachedResult("/nonexistent/path/cache.json")
    check result.isNone

  test "returns None for corrupt JSON":
    let tempDir = getTempDir() / "gsd_test_load_corrupt"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    writeFile(cachePath, "not valid json {{{")

    let result = loadCachedResult(cachePath)
    check result.isNone

  test "loads valid cache correctly":
    let tempDir = getTempDir() / "gsd_test_load_valid"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    let cacheJson = %*{
      "current_version": "0.2.0",
      "latest_version": "0.3.0",
      "update_available": true,
      "release_url": "https://github.com/puremachinery/gsd/releases/v0.3.0",
      "checked_at": "2026-01-01T00:00:00Z",
      "etag": "abc123"
    }
    writeFile(cachePath, cacheJson.pretty())

    let result = loadCachedResult(cachePath)
    check result.isSome
    let r = result.get()
    check r.currentVersion == "0.2.0"
    check r.latestVersion == "0.3.0"
    check r.updateAvailable == true
    check r.releaseUrl == "https://github.com/puremachinery/gsd/releases/v0.3.0"

suite "saveCacheResult":
  test "writes correct JSON structure":
    let tempDir = getTempDir() / "gsd_test_save_cache"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    let checkResult = UpdateCheckResult(
      currentVersion: "0.2.0",
      latestVersion: "0.3.0",
      updateAvailable: true,
      releaseUrl: "https://github.com/puremachinery/gsd/releases/v0.3.0"
    )

    saveCacheResult(cachePath, checkResult, "etag-value")

    check fileExists(cachePath)
    let content = readFile(cachePath)
    let json = parseJson(content)
    check json["current_version"].getStr() == "0.2.0"
    check json["latest_version"].getStr() == "0.3.0"
    check json["update_available"].getBool() == true
    check json["release_url"].getStr() ==
        "https://github.com/puremachinery/gsd/releases/v0.3.0"
    check json["etag"].getStr() == "etag-value"
    check json.hasKey("checked_at")

  test "creates parent directory if missing":
    let tempDir = getTempDir() / "gsd_test_save_mkdir"
    defer: removeDir(tempDir)

    let cachePath = tempDir / "subdir" / "cache.json"
    let checkResult = UpdateCheckResult(
      currentVersion: "0.3.0",
      latestVersion: "0.3.0",
      updateAvailable: false,
      releaseUrl: ""
    )

    saveCacheResult(cachePath, checkResult)
    check fileExists(cachePath)

suite "ETag round-trip":
  test "saved ETag can be loaded back":
    let tempDir = getTempDir() / "gsd_test_etag_roundtrip"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    let checkResult = UpdateCheckResult(
      currentVersion: "0.3.0",
      latestVersion: "0.3.0",
      updateAvailable: false,
      releaseUrl: ""
    )

    saveCacheResult(cachePath, checkResult, "W/\"abc123def\"")

    let loadedEtag = loadCachedEtag(cachePath)
    check loadedEtag == "W/\"abc123def\""

  test "returns empty string for missing cache":
    check loadCachedEtag("/nonexistent/cache.json") == ""

  test "returns empty string for corrupt cache":
    let tempDir = getTempDir() / "gsd_test_etag_corrupt"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let cachePath = tempDir / "cache.json"
    writeFile(cachePath, "not json")

    check loadCachedEtag(cachePath) == ""

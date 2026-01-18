## Tests for update.nim

import std/[unittest]
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

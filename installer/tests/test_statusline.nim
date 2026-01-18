## Tests for statusline.nim

import std/[unittest, options, strutils]
import ../src/statusline

suite "stripAnsi":
  test "removes color codes":
    let input = "\e[32mgreen\e[0m"
    check stripAnsi(input) == "green"

  test "removes multiple codes":
    let input = "\e[1m\e[32mbold green\e[0m normal"
    check stripAnsi(input) == "bold green normal"

  test "handles empty string":
    check stripAnsi("") == ""

  test "preserves plain text":
    check stripAnsi("plain text") == "plain text"

  test "removes complex codes":
    let input = "\e[38;5;196mred\e[0m"
    check stripAnsi(input) == "red"

suite "parseInput":
  test "parses complete JSON":
    let json = """
    {
      "model": {"display_name": "Claude Opus"},
      "workspace": {"current_dir": "/Users/test/project"},
      "session_id": "abc123",
      "context_window": {"remaining_percentage": 75}
    }
    """
    let result = parseInput(json)

    check result.isSome
    let input = result.get()
    check input.model.get() == "Claude Opus"
    check input.workspace.get() == "project"
    check input.sessionId.get() == "abc123"
    check input.contextRemaining.get() == 75

  test "handles missing model":
    let json = """{"workspace": {"current_dir": "/test"}}"""
    let result = parseInput(json)

    check result.isSome
    check result.get().model.isNone

  test "handles missing workspace":
    let json = """{"model": {"display_name": "Opus"}}"""
    let result = parseInput(json)

    check result.isSome
    check result.get().workspace.isNone

  test "handles empty JSON":
    let json = "{}"
    let result = parseInput(json)

    check result.isSome
    let input = result.get()
    check input.model.isNone
    check input.workspace.isNone
    check input.contextRemaining.isNone

  test "returns none for invalid JSON":
    let json = "not json"
    let result = parseInput(json)

    check result.isNone

  test "returns none for empty string":
    let result = parseInput("")

    check result.isNone

suite "getContextColor":
  test "green when less than 50% used":
    # remaining=60 means used=40
    let color = getContextColor(60)
    check color.contains("32")  # Green ANSI code

  test "yellow when 50-65% used":
    # remaining=40 means used=60
    let color = getContextColor(40)
    check color.contains("33")  # Yellow ANSI code

  test "yellow when 65-80% used":
    # remaining=25 means used=75
    let color = getContextColor(25)
    check color.contains("33")  # Yellow ANSI code

  test "red and blink when 80%+ used":
    # remaining=15 means used=85
    let color = getContextColor(15)
    check color.contains("31")  # Red ANSI code
    check color.contains("5")   # Blink ANSI code

  test "red at edge case 80% used":
    # remaining=20 means used=80
    let color = getContextColor(20)
    check color.contains("31")  # Red ANSI code

suite "renderContextBar":
  test "empty bar at 0% used":
    let bar = stripAnsi(renderContextBar(100))
    check bar.contains("0%")

  test "full bar at 100% used":
    let bar = stripAnsi(renderContextBar(0))
    check bar.contains("100%")

  test "half bar at 50% used":
    let bar = stripAnsi(renderContextBar(50))
    check bar.contains("50%")

  test "contains bar characters":
    let bar = renderContextBar(50)
    check bar.contains("█") or bar.contains("░")

suite "extractAfterMarker":
  test "extracts text after marker":
    let result = extractAfterMarker("**Current:** Fix the bug", "**Current:**")

    check result.isSome
    check result.get() == "Fix the bug"

  test "trims whitespace":
    let result = extractAfterMarker("**Current:**   lots of spaces   ", "**Current:**")

    check result.isSome
    check result.get() == "lots of spaces"

  test "returns none when marker not found":
    let result = extractAfterMarker("No marker here", "**Current:**")

    check result.isNone

  test "returns none when nothing after marker":
    let result = extractAfterMarker("**Current:**", "**Current:**")

    check result.isNone

  test "returns none when only whitespace after marker":
    let result = extractAfterMarker("**Current:**   ", "**Current:**")

    check result.isNone

  test "handles Working on marker":
    let result = extractAfterMarker("**Working on:** Building feature", "**Working on:**")

    check result.isSome
    check result.get() == "Building feature"

  test "extracts from middle of line":
    let result = extractAfterMarker("Status: **Current:** Active task", "**Current:**")

    check result.isSome
    check result.get() == "Active task"

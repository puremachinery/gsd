## Tests for toml.nim

import std/[unittest, os, tables, options, strutils]
import ../src/toml

suite "TomlValue constructors":
  test "newTomlString creates string value":
    let v = newTomlString("hello")
    check v.kind == tvkString
    check v.strVal == "hello"

  test "newTomlInt creates int value":
    let v = newTomlInt(42)
    check v.kind == tvkInt
    check v.intVal == 42

  test "newTomlBool creates bool value":
    let t = newTomlBool(true)
    let f = newTomlBool(false)
    check t.kind == tvkBool
    check t.boolVal == true
    check f.boolVal == false

  test "newTomlArray creates array value":
    let arr = newTomlArray(@[newTomlString("a"), newTomlString("b")])
    check arr.kind == tvkArray
    check arr.arrayVal.len == 2

  test "newTomlTable creates empty table":
    let t = newTomlTable()
    check t.kind == tvkTable
    check t.tableVal.len == 0

suite "toTomlString":
  test "serializes string with quotes":
    let v = newTomlString("hello")
    check v.toTomlString() == "\"hello\""

  test "escapes special characters":
    let v = newTomlString("line1\nline2")
    check v.toTomlString() == "\"line1\\nline2\""

    let v2 = newTomlString("has \"quotes\"")
    check v2.toTomlString() == "\"has \\\"quotes\\\"\""

  test "serializes int":
    let v = newTomlInt(123)
    check v.toTomlString() == "123"

  test "serializes bool":
    check newTomlBool(true).toTomlString() == "true"
    check newTomlBool(false).toTomlString() == "false"

  test "serializes simple array":
    let arr = newTomlArray(@[newTomlString("a"), newTomlString("b")])
    check arr.toTomlString() == "[\"a\", \"b\"]"

suite "parseToml":
  test "parses simple key-value pairs":
    let content = """
key = "value"
number = 42
flag = true
"""
    let doc = parseToml(content)
    check doc.root.hasKey("key")
    check doc.root["key"].strVal == "value"
    check doc.root["number"].intVal == 42
    check doc.root["flag"].boolVal == true

  test "parses tables":
    let content = """
[section]
name = "test"
"""
    let doc = parseToml(content)
    check doc.root.hasKey("section")
    check doc.root["section"].kind == tvkTable
    check doc.root["section"].tableVal["name"].strVal == "test"

  test "parses array of tables":
    let content = """
[[items]]
name = "first"

[[items]]
name = "second"
"""
    let doc = parseToml(content)
    check doc.root.hasKey("items")
    check doc.root["items"].kind == tvkArray
    check doc.root["items"].arrayVal.len == 2
    check doc.root["items"].arrayVal[0].tableVal["name"].strVal == "first"
    check doc.root["items"].arrayVal[1].tableVal["name"].strVal == "second"

  test "ignores comments":
    let content = """
# This is a comment
key = "value"
# Another comment
"""
    let doc = parseToml(content)
    check doc.root.len == 1
    check doc.root["key"].strVal == "value"

  test "handles empty content":
    let doc = parseToml("")
    check doc.root.len == 0

suite "serializeToml":
  test "serializes simple values":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())
    doc.root["name"] = newTomlString("test")
    doc.root["count"] = newTomlInt(5)

    let output = serializeToml(doc)
    check output.contains("name = \"test\"")
    check output.contains("count = 5")

  test "serializes tables":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())
    var section = newTomlTable()
    section.tableVal["key"] = newTomlString("value")
    doc.root["section"] = section

    let output = serializeToml(doc)
    check output.contains("[section]")
    check output.contains("key = \"value\"")

  test "serializes array of tables":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())
    var item1 = newTomlTable()
    item1.tableVal["name"] = newTomlString("first")
    var item2 = newTomlTable()
    item2.tableVal["name"] = newTomlString("second")
    doc.root["items"] = newTomlArray(@[item1, item2])

    let output = serializeToml(doc)
    check output.contains("[[items]]")
    check output.contains("name = \"first\"")
    check output.contains("name = \"second\"")

suite "loadToml and saveToml":
  test "round-trip preserves data":
    let tempDir = getTempDir() / "gsd_test_toml"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let path = tempDir / "test.toml"

    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())
    doc.root["name"] = newTomlString("test")
    doc.root["count"] = newTomlInt(42)

    check saveToml(doc, path) == true

    let loaded = loadToml(path)
    check loaded.isSome
    check loaded.get().root["name"].strVal == "test"
    check loaded.get().root["count"].intVal == 42

  test "loadToml returns none for missing file":
    let result = loadToml("/nonexistent/path/file.toml")
    check result.isNone

suite "mergeCodexNotify":
  test "adds hooks to empty document":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())

    var hook = newTomlTable()
    hook.tableVal["event"] = newTomlString("session_start")
    hook.tableVal["command"] = newTomlString("gsd check-update #gsd")

    mergeCodexNotify(doc, @[hook])

    check doc.root.hasKey("notify")
    check doc.root["notify"].kind == tvkArray
    check doc.root["notify"].arrayVal.len == 1

  test "preserves existing non-GSD hooks":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())

    var existingHook = newTomlTable()
    existingHook.tableVal["event"] = newTomlString("other_event")
    existingHook.tableVal["command"] = newTomlString("other-command")
    doc.root["notify"] = newTomlArray(@[existingHook])

    var gsdHook = newTomlTable()
    gsdHook.tableVal["event"] = newTomlString("session_start")
    gsdHook.tableVal["command"] = newTomlString("gsd check-update #gsd")

    mergeCodexNotify(doc, @[gsdHook])

    check doc.root["notify"].arrayVal.len == 2

  test "replaces existing GSD hooks":
    var doc = TomlDocument(root: initOrderedTable[string, TomlValue]())

    var oldGsdHook = newTomlTable()
    oldGsdHook.tableVal["command"] = newTomlString("gsd old-command #gsd")
    doc.root["notify"] = newTomlArray(@[oldGsdHook])

    var newGsdHook = newTomlTable()
    newGsdHook.tableVal["event"] = newTomlString("session_start")
    newGsdHook.tableVal["command"] = newTomlString("gsd new-command #gsd")

    mergeCodexNotify(doc, @[newGsdHook])

    check doc.root["notify"].arrayVal.len == 1
    check doc.root["notify"].arrayVal[0].tableVal["command"].strVal == "gsd new-command #gsd"

suite "createGsdNotifyHooks":
  test "creates session start hook":
    let hooks = createGsdNotifyHooks("/usr/local/bin/gsd", "/home/user/.codex")
    check hooks.len == 1
    check hooks[0].tableVal["event"].strVal == "session_start"
    check hooks[0].tableVal["command"].strVal.contains("gsd")
    check hooks[0].tableVal["command"].strVal.contains("#gsd")

suite "mergeCodexNotifyText":
  test "adds hooks to empty file":
    var hook = newTomlTable()
    hook.tableVal["event"] = newTomlString("session_start")
    hook.tableVal["command"] = newTomlString("gsd check-update #gsd")

    let result = mergeCodexNotifyText("", @[hook])
    check result.contains("[[notify]]")
    check result.contains("event = \"session_start\"")
    check result.contains("#gsd")

  test "preserves unknown TOML content":
    let original = """
# User config
model = "gpt-4"
api.key = "sk-xxx"

[preferences]
theme = "dark"
nested.value = 42
"""
    var hook = newTomlTable()
    hook.tableVal["event"] = newTomlString("session_start")
    hook.tableVal["command"] = newTomlString("gsd test #gsd")

    let result = mergeCodexNotifyText(original, @[hook])

    # Original content should be preserved
    check result.contains("model = \"gpt-4\"")
    check result.contains("api.key = \"sk-xxx\"")
    check result.contains("[preferences]")
    check result.contains("theme = \"dark\"")
    check result.contains("nested.value = 42")
    # New hook should be added
    check result.contains("[[notify]]")
    check result.contains("#gsd")

  test "removes existing GSD hooks":
    let original = """
[[notify]]
event = "session_start"
command = "gsd old-command #gsd"

[[notify]]
event = "other"
command = "other-command"
"""
    var hook = newTomlTable()
    hook.tableVal["event"] = newTomlString("session_start")
    hook.tableVal["command"] = newTomlString("gsd new-command #gsd")

    let result = mergeCodexNotifyText(original, @[hook])

    # Old GSD hook should be removed
    check not result.contains("old-command")
    # Non-GSD hook should be preserved
    check result.contains("other-command")
    # New GSD hook should be present
    check result.contains("new-command")

  test "removes all GSD hooks when empty list passed":
    let original = """
[[notify]]
event = "session_start"
command = "gsd check-update #gsd"

[[notify]]
event = "other"
command = "keep-this"
"""
    let result = mergeCodexNotifyText(original, @[])

    # GSD hook should be removed
    check not result.contains("#gsd")
    check not result.contains("check-update")
    # Non-GSD hook should remain
    check result.contains("keep-this")

  test "preserves comments":
    let original = """
# This is a config file
# With comments

model = "test"
"""
    let result = mergeCodexNotifyText(original, @[])

    check result.contains("# This is a config file")
    check result.contains("# With comments")

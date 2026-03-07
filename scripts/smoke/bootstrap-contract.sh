#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <gsd-binary>" >&2
  exit 1
}

fail() {
  echo "smoke failed: $*" >&2
  exit 1
}

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$script_dir/lib.sh"

run_in_project() {
  (
    cd "$project_dir"
    env -u GSD_CONFIG_DIR HOME="$temp_home" "$@"
  )
}

run_project_bash() {
  (
    cd "$project_dir"
    env -u GSD_CONFIG_DIR HOME="$temp_home" bash -c "$1"
  )
}

[ "$#" -eq 1 ] || usage

require_cmd bash
require_cmd find
require_cmd git
require_cmd grep
require_cmd mktemp
GSD_BIN="$(resolve_path "$1")"
[ -f "$GSD_BIN" ] || fail "gsd binary not found: $GSD_BIN"
[ -x "$GSD_BIN" ] || fail "gsd binary is not executable: $GSD_BIN"
PYTHON_BIN="$(select_python)"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/gsd-bootstrap-smoke.XXXXXX")"
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] || [ "${GSD_SMOKE_PRESERVE_TMP:-0}" = "1" ]; then
    printf 'Bootstrap smoke artifacts preserved at %s\n' "$tmp_root" >&2
    return
  fi

  rm -rf "$tmp_root"
}
trap cleanup EXIT

temp_home="$tmp_root/home"
project_dir="$tmp_root/project"
mkdir -p "$temp_home" "$project_dir"
temp_home="$(resolve_path "$temp_home")"
project_dir="$(resolve_path "$project_dir")"
project_name="$(basename "$project_dir")"
gsd_dir="$project_dir/.gsd"

run_in_project "$GSD_BIN" --version >/dev/null
run_in_project "$GSD_BIN" install --platform=both --local >/dev/null

managed_bin="$(resolve_path "$gsd_dir/runtime/bin/gsd")"
claude_prompt="$project_dir/.claude/commands/gsd/new-project.md"
codex_prompt="$project_dir/.codex/prompts/gsd-new-project.md"
claude_settings="$project_dir/.claude/settings.json"
codex_config="$project_dir/.codex/config.toml"
codex_agents="$project_dir/.codex/AGENTS.md"
gsd_config="$gsd_dir/gsd-config.json"

assert_dir "$gsd_dir"
assert_file "$gsd_dir/VERSION"
assert_executable "$managed_bin"
assert_file "$claude_prompt"
assert_file "$codex_prompt"
assert_file "$claude_settings"
assert_file "$codex_config"
assert_file "$codex_agents"
assert_file "$gsd_config"
assert_file "$project_dir/.gsd/references/questioning.md"
assert_file "$project_dir/.gsd/references/ui-brand.md"
assert_file "$project_dir/.gsd/templates/project.md"
assert_file "$project_dir/.gsd/templates/requirements.md"

claude_prompt_content="$(cat "$claude_prompt")"
codex_prompt_content="$(cat "$codex_prompt")"
claude_settings_content="$(cat "$claude_settings")"
codex_config_content="$(cat "$codex_config")"
codex_agents_content="$(cat "$codex_agents")"

assert_contains "$claude_prompt_content" "@.gsd/references/questioning.md"
assert_contains "$claude_prompt_content" "@.gsd/templates/project.md"
assert_contains "$claude_prompt_content" ".planning/PROJECT.md"
assert_contains "$claude_prompt_content" ".planning/config.json"
assert_contains "$claude_prompt_content" ".planning/REQUIREMENTS.md"
assert_contains "$claude_prompt_content" ".planning/ROADMAP.md"
assert_contains "$claude_prompt_content" ".planning/STATE.md"
assert_contains "$claude_prompt_content" "git init"
assert_not_contains "$claude_prompt_content" "@~/.gsd/"

assert_contains "$codex_prompt_content" "@.gsd/references/questioning.md"
assert_contains "$codex_prompt_content" ".planning/PROJECT.md"
assert_not_contains "$codex_prompt_content" "@~/.gsd/"
assert_contains "$claude_prompt_content" 'CODE_FILES=$(find . -type f \( -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.java" \) 2>/dev/null | grep -v deps | grep -vF ".git" | head -20)'
assert_contains "$claude_prompt_content" 'HAS_PACKAGE=$({ [ -f project.manifest ] || [ -f requirements.txt ] || [ -f Cargo.toml ] || [ -f go.mod ] || [ -f Package.swift ]; } && echo "yes")'

assert_contains "$claude_settings_content" "$managed_bin"
assert_contains "$claude_settings_content" "check-update --config-dir"
assert_contains "$claude_settings_content" "statusline --config-dir"
assert_contains "$claude_settings_content" "$gsd_dir"
assert_contains "$claude_settings_content" "#gsd"
assert_contains "$codex_config_content" "$managed_bin"
assert_contains "$codex_config_content" "check-update --config-dir"
assert_contains "$codex_config_content" "$gsd_dir"
assert_contains "$codex_config_content" "#gsd"
assert_contains "$codex_agents_content" "<!-- GSD:AGENTS START -->"
assert_contains "$codex_agents_content" "gsd-roadmapper"

"$PYTHON_BIN" - "$gsd_config" "$gsd_dir" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
expected_dir = pathlib.Path(sys.argv[2]).resolve()
data = json.loads(config_path.read_text())

if data.get("install_type") != "local":
    raise SystemExit(f"unexpected install_type: {data.get('install_type')!r}")

platforms = sorted(data.get("platforms", []))
if platforms != ["claude", "codex"]:
    raise SystemExit(f"unexpected platforms: {platforms!r}")

actual_dir = pathlib.Path(data.get("gsd_dir", "")).resolve()
if actual_dir != expected_dir:
    raise SystemExit(f"unexpected gsd_dir: {actual_dir} != {expected_dir}")
PY

git_output="$(run_project_bash 'if [ -d .git ] || [ -f .git ]; then
  echo "Git repo exists in current directory"
else
  git -c init.defaultBranch=main init >/dev/null 2>&1
  echo "Initialized new git repo"
fi')"
assert_contains "$git_output" "Initialized new git repo"
assert_dir "$project_dir/.git"

brownfield_output="$(run_project_bash 'CODE_FILES=$(find . -type f \( -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.java" \) 2>/dev/null | grep -v deps | grep -vF ".git" | head -20)
HAS_PACKAGE=$({ [ -f project.manifest ] || [ -f requirements.txt ] || [ -f Cargo.toml ] || [ -f go.mod ] || [ -f Package.swift ]; } && echo "yes")
HAS_CODEBASE_MAP=$([ -d .planning/codebase ] && echo "yes")
printf "CODE_FILES=%s\nHAS_PACKAGE=%s\nHAS_CODEBASE_MAP=%s\n" "$CODE_FILES" "$HAS_PACKAGE" "$HAS_CODEBASE_MAP"')"
printf '%s\n' "$brownfield_output" | grep -Fx 'CODE_FILES=' >/dev/null || fail "expected no brownfield code files"
printf '%s\n' "$brownfield_output" | grep -Fx 'HAS_PACKAGE=' >/dev/null || fail "expected no package manifest"
printf '%s\n' "$brownfield_output" | grep -Fx 'HAS_CODEBASE_MAP=' >/dev/null || fail "expected no codebase map"

touch "$project_dir/requirements.txt"
package_detection_output="$(run_project_bash 'HAS_PACKAGE=$({ [ -f project.manifest ] || [ -f requirements.txt ] || [ -f Cargo.toml ] || [ -f go.mod ] || [ -f Package.swift ]; } && echo "yes")
printf "HAS_PACKAGE=%s\n" "$HAS_PACKAGE"')"
printf '%s\n' "$package_detection_output" | grep -Fx 'HAS_PACKAGE=yes' >/dev/null || fail "expected manifest detection to recognize requirements.txt"
rm "$project_dir/requirements.txt"

mkdir -p "$project_dir/.planning"
cat > "$project_dir/.planning/STATE.md" <<'EOF_STATE'
# State

**Current:** Bootstrap smoke
EOF_STATE

doctor_claude_output="$(run_in_project "$managed_bin" doctor --config-dir "$gsd_dir" --platform=claude)"
doctor_codex_output="$(run_in_project "$managed_bin" doctor --config-dir "$gsd_dir" --platform=codex)"
assert_contains "$doctor_claude_output" "Installation is healthy!"
assert_contains "$doctor_codex_output" "Installation is healthy!"

update_output="$(run_in_project "$managed_bin" update --platform=both --dry-run)"
assert_contains "$update_output" "Would install GSD"
assert_contains "$update_output" "Dry run complete. No files were modified."

status_input="$("$PYTHON_BIN" - "$project_dir" <<'PY'
import json
import sys

project_dir = sys.argv[1]
payload = {
    "model": {"display_name": "Smoke Model"},
    "workspace": {"current_dir": project_dir},
    "context_window": {"remaining_percentage": 75},
}
print(json.dumps(payload), end="")
PY
)"
status_output="$(printf '%s' "$status_input" | run_in_project "$managed_bin" statusline --config-dir "$gsd_dir")"
assert_contains "$status_output" "Smoke Model"
assert_contains "$status_output" "Bootstrap smoke"
assert_contains "$status_output" "$project_name"
assert_contains "$status_output" "25%"

echo "Bootstrap smoke passed."

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <gsd-binary>" >&2
  exit 1
}

fail() {
  echo "live smoke failed: $*" >&2
  exit 1
}

resolve_path() {
  local path="$1"
  local dir base

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  (
    cd "$dir"
    printf '%s/%s\n' "$(pwd -P)" "$base"
  )
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_dir() {
  [ -d "$1" ] || fail "expected directory: $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null || fail "expected to find '$needle'"
}

assert_contains_any() {
  local haystack="$1"
  shift
  local needle

  for needle in "$@"; do
    if printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null; then
      return 0
    fi
  done

  fail "expected to find one of: $*"
}

assert_matches() {
  local haystack="$1"
  local pattern="$2"
  printf '%s' "$haystack" | grep -E -- "$pattern" >/dev/null || fail "expected to match regex: $pattern"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

prepare_codex_home() {
  local source_codex_home="${CODEX_HOME:-$HOME/.codex}"

  codex_home_root="$smoke_root/codex-home"
  codex_home="$codex_home_root/.codex"
  mkdir -p "$codex_home"
  : > "$codex_home/config.toml"

  if [ -n "${OPENAI_API_KEY:-}" ]; then
    printf '%s\n' "$OPENAI_API_KEY" |
      HOME="$codex_home_root" CODEX_HOME="$codex_home" codex login --with-api-key >/dev/null
  elif [ -f "$source_codex_home/auth.json" ]; then
    cp "$source_codex_home/auth.json" "$codex_home/auth.json"
  else
    fail "codex is not authenticated; run 'codex login' or export OPENAI_API_KEY"
  fi

  HOME="$codex_home_root" CODEX_HOME="$codex_home" codex login status >/dev/null 2>&1 ||
    fail "codex isolated auth check failed"
}

[ "$#" -eq 1 ] || usage

require_cmd codex
require_cmd git

GSD_BIN="$(resolve_path "$1")"
[ -f "$GSD_BIN" ] || fail "gsd binary not found: $GSD_BIN"
[ -x "$GSD_BIN" ] || fail "gsd binary is not executable: $GSD_BIN"

root_provided=0
if [ -n "${GSD_LIVE_SMOKE_ROOT:-}" ]; then
  smoke_root="$GSD_LIVE_SMOKE_ROOT"
  mkdir -p "$smoke_root"
  root_provided=1
else
  smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/gsd-live-smoke.XXXXXX")"
fi

cleanup() {
  local exit_code=$?
  if [ "$exit_code" -eq 0 ] && [ "${GSD_LIVE_SMOKE_PRESERVE:-0}" != "1" ] && [ "$root_provided" -eq 0 ]; then
    rm -rf "$smoke_root"
  else
    printf 'Live smoke artifacts preserved at %s\n' "$smoke_root" >&2
  fi
}
trap cleanup EXIT

smoke_root="$(resolve_path "$smoke_root")"
project_dir="$smoke_root/project"
log_dir="$smoke_root/logs"
prompt_file="$smoke_root/live-smoke-prompt.txt"
last_message_file="$log_dir/last-message.txt"
transcript_file="$log_dir/codex-transcript.log"
mkdir -p "$project_dir" "$log_dir"
project_dir="$(resolve_path "$project_dir")"

prepare_codex_home

(
  cd "$project_dir"
  "$GSD_BIN" install --platform=codex --local >/dev/null
)

assert_file "$project_dir/.codex/prompts/gsd-new-project.md"
assert_file "$project_dir/.gsd/references/questioning.md"
assert_file "$project_dir/.gsd/references/ui-brand.md"
assert_file "$project_dir/.gsd/templates/project.md"
assert_file "$project_dir/.gsd/templates/requirements.md"

cat > "$prompt_file" <<'PROMPT'
You are running a non-interactive smoke test for GSD.

Read and follow the instructions in `.codex/prompts/gsd-new-project.md` as the primary workflow.

Treat the following as the complete user conversation and constraints. Do not ask follow-up questions; use these answers directly and continue:
- Build a tiny single-user Python CLI todo app named `todo-smoke`.
- Persist tasks in a local JSON file in the repository.
- V1 includes add, list, complete, and delete commands.
- No auth, no sync, no reminders, no tags, no priorities, no web UI.
- Skip optional research.
- If the workflow would normally use AskUserQuestion or interactive confirmation, choose the forward-progress option that matches this brief and continue.
- Stop immediately once the `gsd-new-project` workflow is complete.
- Do not implement the application.
- Do not create files outside the workflow's initialization artifacts.

When and only when the workflow is complete and the expected planning artifacts exist, output exactly: SMOKE_OK
PROMPT

HOME="$codex_home_root" CODEX_HOME="$codex_home" OTEL_SDK_DISABLED=true codex exec \
  --full-auto \
  --ephemeral \
  --skip-git-repo-check \
  -c 'notify=[]' \
  -C "$project_dir" \
  -o "$last_message_file" \
  "$(cat "$prompt_file")" | tee "$transcript_file"

last_message="$(tr -d '\r\n' < "$last_message_file")"
[ "$last_message" = "SMOKE_OK" ] || fail "unexpected final message: $last_message"

assert_dir "$project_dir/.git"
assert_file "$project_dir/.planning/PROJECT.md"
assert_file "$project_dir/.planning/config.json"
assert_file "$project_dir/.planning/REQUIREMENTS.md"
assert_file "$project_dir/.planning/ROADMAP.md"
assert_file "$project_dir/.planning/STATE.md"

project_content="$(cat "$project_dir/.planning/PROJECT.md")"
requirements_content="$(cat "$project_dir/.planning/REQUIREMENTS.md")"
roadmap_content="$(cat "$project_dir/.planning/ROADMAP.md")"
state_content="$(cat "$project_dir/.planning/STATE.md")"
config_content="$(cat "$project_dir/.planning/config.json")"

assert_contains "$project_content" "todo-smoke"
assert_contains "$project_content" "Python CLI"
assert_contains "$project_content" "JSON file"
assert_matches "$requirements_content" '\*\*[A-Z]+-[0-9]{2}\*\*'
assert_contains "$requirements_content" "JSON file"
assert_contains_any "$roadmap_content" "Phase 1" "Phase 01"
assert_contains_any "$roadmap_content" "Phase 2" "Phase 02"
assert_contains_any "$state_content" "Current focus" "Current phase" "Current Phase" "Status:"
assert_contains "$config_content" '"mode"'

commit_count="$(git -C "$project_dir" rev-list --count HEAD)"
[ "$commit_count" -ge 1 ] || fail "expected at least one git commit"

unexpected_files="$(cd "$project_dir" && find . -type f ! -path './.planning/*' ! -path './.codex/*' ! -path './.gsd/*' ! -path './.git/*' | sort || true)"
[ -z "$unexpected_files" ] || fail "unexpected non-workflow files created: $unexpected_files"

if [ -d "$project_dir/.planning/research" ]; then
  fail "expected optional research to be skipped"
fi

echo "Live new-project smoke passed."

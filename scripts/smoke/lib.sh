assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_dir() {
  [ -d "$1" ] || fail "expected directory: $1"
}

assert_executable() {
  [ -x "$1" ] || fail "expected executable file: $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null || fail "expected to find '$needle'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "did not expect to find '$needle'"
  fi
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

select_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1 &&
    python -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi

  fail "python3-compatible interpreter is required"
}

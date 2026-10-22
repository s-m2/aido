#!/usr/bin/env bash
# run_tests.sh — offline unit tests for aido's Phase 2 testability layer.
#
# Exercises the modules under test in isolation using a fake Ollama backend,
# so the real interactive loop and network are never touched.
#
# Requires: bash, jq, curl (curl is only needed for syntax, not execution).
#
# Exit code: 0 if all assertions pass, 1 otherwise.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LIB_DIR="${SCRIPT_DIR%/test}/src/lib"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() {
  echo "  FAIL: $1"
  [[ -n "${2:-}" ]] && echo "        $2"
  FAIL=$((FAIL + 1))
}

# assert_eq <expected> <actual> <label>
assert_eq() {
  if [[ "$1" == "$2" ]]; then
    pass "$3"
  else
    fail "$3" "expected '$1' but got '$2'"
  fi
}

# Assert a command produced output.
assert_nonempty() {
  if [[ -n "$2" ]]; then
    pass "$1"
  else
    fail "$1" "expected non-empty output but got empty"
  fi
}

# Assert a command failed (non-zero exit).
assert_fails() {
  if "$@" >/dev/null 2>&1; then
    fail "$1" "expected failure but command exited 0"
  else
    pass "$1"
  fi
}

echo "=== context.sh ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/context.sh"
ctx=$(gather_context)
assert_nonempty "gather_context returns non-empty" "$ctx"
for key in "OS:" "Kernel:" "Shell:" "User:" "Home:" "PWD:" "PATH:" "Date:"; do
  if [[ "$ctx" == *"$key"* ]]; then
    pass "gather_context contains '$key'"
  else
    fail "gather_context contains '$key'" "output was:\n$ctx"
  fi
done

echo "=== prompt.sh ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/prompt.sh"
sys=$(build_system_prompt)
assert_nonempty "build_system_prompt returns non-empty" "$sys"
[[ "$sys" == *"You are a precise Linux command-line assistant."* ]] && \
  pass "system prompt has strict header" || fail "system prompt has strict header"
[[ "$sys" == *"Environment:"* ]] && \
  pass "system prompt injects environment" || fail "system prompt injects environment"

echo "=== llm.sh (mock Ollama) ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/llm.sh"
# Prepend the fake curl dir and force the mock to answer with a known command.
export PATH="$SCRIPT_DIR:$PATH"
# Config vars that the real entry point sets; the harness sources modules directly.
export MODEL='mock-model'
export OLLAMA_HOST='http://localhost:11434'
export TEMPERATURE='0.1'
export AIDO_MOCK_RESPONSE='echo hello-from-mock'
got=$(call_ollama "list files")
assert_eq "echo hello-from-mock" "$got" "call_ollama returns cleaned mock command"

# Mock returns a markdown-fenced command (inline); the fence strip should remove it.
export AIDO_MOCK_RESPONSE='```echo fenced```'
got=$(call_ollama "list files")
assert_eq "echo fenced" "$got" "call_ollama strips markdown fences"

# Mock returns a leading/trailing-whitespace command; trimmed.
export AIDO_MOCK_RESPONSE='   echo padded   '
got=$(call_ollama "list files")
assert_eq "echo padded" "$got" "call_ollama trims leading/trailing whitespace"

# curl failure -> call_ollama should die (non-zero).
export AIDO_MOCK_STATUS=7
assert_fails "call_ollama fails when curl can't connect" call_ollama "list files"
unset AIDO_MOCK_STATUS

echo "=== ui.sh (edit_in_editor) ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/ui.sh"

# edit_in_editor reads from/writes to the controlling TTY, so it only works in
# an interactive session. Guard these tests with a TTY check.
if [[ -t 0 && -t 1 && -e /dev/tty ]]; then
  export EDITOR='true'
  out=$(edit_in_editor "unchanged")
  assert_eq "unchanged" "$out" "edit_in_editor returns file content (no trailing newline)"

  export EDITOR='sh -c "printf E >> \"$1\""'
  out=$(edit_in_editor "seed")
  assert_eq "seedE" "$out" "edit_in_editor reflects edited file content"
else
  echo "  SKIP: edit_in_editor (requires interactive TTY)"
fi

echo
echo "================ RESULTS ================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bash
# run_tests.sh — offline unit tests for aido.
#
# Exercises the modules under test in isolation using a fake OpenAI-compatible
# backend, so the real interactive loop and network are never touched.
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

echo "=== config.sh (BASE_URL derivation) ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/config.sh"

# Default when nothing is set
unset BASE_URL OLLAMA_HOST AIDO_BASE_URL || true
apply_defaults
assert_eq "http://localhost:11434/v1" "$BASE_URL" "BASE_URL defaults to Ollama /v1"

# Derived from OLLAMA_HOST
unset BASE_URL AIDO_BASE_URL || true
export OLLAMA_HOST="http://example:11434"
apply_defaults
assert_eq "http://example:11434/v1" "$BASE_URL" "BASE_URL derived from OLLAMA_HOST"

# Explicit BASE_URL wins
export BASE_URL="http://custom/v1"
apply_defaults
assert_eq "http://custom/v1" "$BASE_URL" "explicit BASE_URL is preserved"
unset BASE_URL OLLAMA_HOST

echo "=== llm.sh (mock OpenAI-compatible) ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/util.sh"
# shellcheck source=/dev/null
. "${LIB_DIR}/llm.sh"

# Ensure the mock provider is executable (git may have stored it as 644).
chmod +x "$SCRIPT_DIR/mock_provider.sh" 2>/dev/null || true

# Prepend the fake curl dir and force the mock to answer with a known command.
export PATH="$SCRIPT_DIR:$PATH"
# Config vars that the real entry point sets; the harness sources modules directly.
export MODEL='mock-model'
export BASE_URL='http://localhost:11434/v1'
export TEMPERATURE='0.1'
export AIDO_MOCK_RESPONSE='echo hello-from-mock'
got=$(call_llm "list files")
assert_eq "echo hello-from-mock" "$got" "call_llm returns cleaned mock command"

# Alias still works
got=$(call_ollama "list files")
assert_eq "echo hello-from-mock" "$got" "call_ollama alias returns cleaned mock command"

# Mock returns a markdown-fenced command (inline); the fence strip should remove it.
export AIDO_MOCK_RESPONSE='```echo fenced```'
got=$(call_llm "list files")
assert_eq "echo fenced" "$got" "call_llm strips markdown fences"

# Mock returns a leading/trailing-whitespace command; trimmed.
export AIDO_MOCK_RESPONSE='   echo padded   '
got=$(call_llm "list files")
assert_eq "echo padded" "$got" "call_llm trims leading/trailing whitespace"

# System override path (used by explain)
export AIDO_MOCK_RESPONSE='This command lists files.'
got=$(call_llm "ls -la" "You are a helpful shell assistant. Explain the following command.")
assert_eq "This command lists files." "$got" "call_llm accepts system override"

# curl failure -> call_llm should die (non-zero).
export AIDO_MOCK_STATUS=7
assert_fails "call_llm fails when curl can't connect" call_llm "list files"
unset AIDO_MOCK_STATUS

echo "=== ui.sh (TUI selection) ==="
# shellcheck source=/dev/null
. "${LIB_DIR}/ui.sh"

# Forced modes (when the binary exists or mode is ansi)
export TUI=ansi
detect_ui
assert_eq "ansi" "$UI_MODE" "TUI=ansi selects ansi"

if command -v gum >/dev/null 2>&1; then
  export TUI=gum
  detect_ui
  assert_eq "gum" "$UI_MODE" "TUI=gum selects gum"
else
  echo "  SKIP: TUI=gum (gum not installed)"
fi

if command -v dialog >/dev/null 2>&1; then
  export TUI=dialog
  detect_ui
  assert_eq "dialog" "$UI_MODE" "TUI=dialog selects dialog"
else
  echo "  SKIP: TUI=dialog (dialog not installed)"
fi

if command -v whiptail >/dev/null 2>&1; then
  export TUI=whiptail
  detect_ui
  assert_eq "whiptail" "$UI_MODE" "TUI=whiptail selects whiptail"
else
  echo "  SKIP: TUI=whiptail (whiptail not installed)"
fi

# auto picks something valid
export TUI=auto
detect_ui
case "$UI_MODE" in
  gum|dialog|whiptail|ansi) pass "TUI=auto selects a valid mode ($UI_MODE)" ;;
  *) fail "TUI=auto selects a valid mode" "got '$UI_MODE'" ;;
esac

# invalid falls back to auto behavior (via validate, but detect_ui itself tolerates)
export TUI=not-a-mode
detect_ui
case "$UI_MODE" in
  gum|dialog|whiptail|ansi) pass "invalid TUI falls back to a valid mode ($UI_MODE)" ;;
  *) fail "invalid TUI falls back to a valid mode" "got '$UI_MODE'" ;;
esac

echo "=== ui.sh (edit_in_editor) ==="
# edit_in_editor reads from/writes to the controlling TTY, so it only works in
# an interactive session. Guard these tests with a TTY check.
if [[ -t 0 && -t 1 && -e /dev/tty ]]; then
  export EDITOR='true'
  out=$(edit_in_editor "unchanged")
  assert_eq "unchanged" "$out" "edit_in_editor returns file content (no trailing newline)"

  # Helper rewrites the file to a known value (with trailing newline, as real
  # editors do). edit_in_editor strips that trailing newline on the way out.
  editor_helper=$(mktemp)
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "seedE" > "$1"' > "$editor_helper"
  chmod +x "$editor_helper"
  export EDITOR="$editor_helper"
  out=$(edit_in_editor "seed")
  assert_eq "seedE" "$out" "edit_in_editor reflects edited file content"
  rm -f "$editor_helper"
else
  echo "  SKIP: edit_in_editor (requires interactive TTY)"
fi

echo
echo "================ RESULTS ================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]]

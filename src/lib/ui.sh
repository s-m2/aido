# ──────────────────────────────────────────────
# ui.sh — interactive approval loop + editor helper
# ──────────────────────────────────────────────

# Edit a value in $EDITOR and echo the result (no trailing newline).
edit_in_editor() {
  local content="$1"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  ${EDITOR} "$tmp" </dev/tty >/dev/tty || true
  local result
  result=$(<"$tmp")
  rm -f "$tmp"
  # Remove trailing newline that editors often add
  printf '%s' "$result"
}

# interactive_loop <prompt>
# The core state machine: generate, then offer approve/edit/prompt/cancel.
interactive_loop() {
  local prompt="$1"
  local cmd
  local retries=0

  while true; do
    if [[ -z "${cmd:-}" ]]; then
      info "Generating command with ${MODEL}..."
      if ! cmd=$(call_ollama "$prompt"); then
        die "LLM call failed"
      fi
    fi

    echo
    echo "Generated command:"
    echo "────────────────────────────────────────────────────────"
    echo "$cmd"
    echo "────────────────────────────────────────────────────────"
    echo
    echo -n "[a]pprove  [e]dit command  [p]rompt again  [c]ancel  > "
    read -r choice </dev/tty

    case "${choice,,}" in
      a|"")
        echo
        info "Executing..."
        # Execute in current shell environment so cd, exports, etc. work
        if eval "$cmd"; then
          log_history "$prompt" "$cmd" "success"
          info "Done (exit 0)"
        else
          local rc=$?
          log_history "$prompt" "$cmd" "failed:$rc"
          info "Command failed with exit code $rc"
        fi
        return
        ;;
      e)
        cmd=$(edit_in_editor "$cmd")
        # loop again to show the edited command
        ;;
      p)
        prompt=$(edit_in_editor "$prompt")
        cmd=""   # force regeneration
        ((retries++)) || true
        if (( retries > MAX_RETRIES )); then
          info "Too many prompt retries. Consider refining your request."
        fi
        ;;
      c|q)
        info "Cancelled."
        log_history "$prompt" "$cmd" "cancelled"
        exit 0
        ;;
      *)
        echo "Unknown option. Please choose a, e, p or c."
        ;;
    esac
  done
}

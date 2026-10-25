# ──────────────────────────────────────────────
# ui.sh — interactive approval loop + editor helper + light TUI
# ──────────────────────────────────────────────

# Colors (safe if terminal doesn't support them)
if [[ -t 1 ]]; then
  BOLD=$(tput bold 2>/dev/null || true)
  RESET=$(tput sgr0 2>/dev/null || true)
  CYAN=$(tput setaf 6 2>/dev/null || true)
  GREEN=$(tput setaf 2 2>/dev/null || true)
  YELLOW=$(tput setaf 3 2>/dev/null || true)
  DIM=$(tput dim 2>/dev/null || true)
else
  BOLD= RESET= CYAN= GREEN= YELLOW= DIM=
fi

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

# Detect best available UI helper once.
detect_ui() {
  if command -v gum >/dev/null 2>&1; then
    UI_MODE=gum
  elif command -v dialog >/dev/null 2>&1; then
    UI_MODE=dialog
  else
    UI_MODE=ansi
  fi
}

# Show a short spinner message (non-blocking-ish for generation).
show_generating() {
  case "${UI_MODE:-ansi}" in
    gum)
      gum spin --spinner line --title "Generating command with ${MODEL}..." -- sleep 0.1 >/dev/null 2>&1 || true
      ;;
    *)
      info "Generating command with ${MODEL}..."
      ;;
  esac
}

# Pretty-print the generated command.
show_command() {
  local cmd="$1"
  echo
  echo "${CYAN}${BOLD}Generated command:${RESET}"
  echo "${DIM}────────────────────────────────────────────────────────${RESET}"
  echo "${GREEN}${cmd}${RESET}"
  echo "${DIM}────────────────────────────────────────────────────────${RESET}"
  echo
}

# interactive_loop <prompt>
# The core state machine: generate, then offer approve/edit/explain/prompt/cancel.
interactive_loop() {
  local prompt="$1"
  local cmd
  local retries=0

  detect_ui

  while true; do
    if [[ -z "${cmd:-}" ]]; then
      show_generating
      if ! cmd=$(call_llm "$prompt"); then
        die "LLM call failed"
      fi
    fi

    show_command "$cmd"

    local choice
    case "${UI_MODE:-ansi}" in
      gum)
        choice=$(gum choose --header "What next?" "approve" "edit command" "explain" "edit prompt" "cancel") || choice=cancel
        ;;
      dialog)
        choice=$(dialog --stdout --menu "What next?" 14 50 5 \
          a "approve" e "edit command" x "explain" p "edit prompt" c "cancel" 2>&1) || choice=c
        ;;
      *)
        echo -n "${BOLD}[a]${RESET}pprove  ${BOLD}[e]${RESET}dit command  ${BOLD}[x]${RESET}explain  ${BOLD}[p]${RESET}rompt again  ${BOLD}[c]${RESET}ancel  > "
        read -r choice </dev/tty
        ;;
    esac

    case "${choice,,}" in
      a|approve|"")
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
      e|"edit command")
        cmd=$(edit_in_editor "$cmd")
        # loop again to show the edited command
        ;;
      x|explain)
        echo
        info "Asking model to explain..."
        local explain_sys="You are a helpful shell assistant. Explain the following command clearly and concisely: what it does, any important flags, potential risks, and safer alternatives if relevant. Keep it short."
        local explanation
        explanation=$(call_llm "$cmd" "$explain_sys") || explanation="(explain failed)"
        echo "${YELLOW}${BOLD}Explanation:${RESET}"
        echo "$explanation"
        echo
        # stay in the loop so user can still approve/edit/cancel
        ;;
      p|"edit prompt")
        prompt=$(edit_in_editor "$prompt")
        cmd=""   # force regeneration
        ((retries++)) || true
        if (( retries > MAX_RETRIES )); then
          info "Too many prompt retries. Consider refining your request."
        fi
        ;;
      c|q|cancel)
        info "Cancelled."
        log_history "$prompt" "$cmd" "cancelled"
        exit 0
        ;;
      *)
        echo "Unknown option. Please choose a, e, x, p or c."
        ;;
    esac
  done
}

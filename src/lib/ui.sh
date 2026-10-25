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

# Resolve UI_MODE from TUI config (or auto-detect).
# Sets UI_MODE to one of: gum, dialog, whiptail, ansi
detect_ui() {
  local want="${TUI:-auto}"
  case "$want" in
    gum|dialog|whiptail|ansi)
      if [[ "$want" == "ansi" ]] || command -v "$want" >/dev/null 2>&1; then
        UI_MODE="$want"
      else
        info "Warning: TUI='$want' requested but '$want' not found; falling back"
        want=auto
      fi
      ;;
  esac

  if [[ "$want" == "auto" || -z "${UI_MODE:-}" ]]; then
    if command -v gum >/dev/null 2>&1; then
      UI_MODE=gum
    elif command -v dialog >/dev/null 2>&1; then
      UI_MODE=dialog
    elif command -v whiptail >/dev/null 2>&1; then
      UI_MODE=whiptail
    else
      UI_MODE=ansi
    fi
  fi
}

# Print the resolved TUI mode (for --tui).
show_tui() {
  detect_ui
  echo "$UI_MODE"
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

    # ANSI / gum leave the terminal intact, so print the command normally.
    # dialog / whiptail take over the screen, so embed the command in the menu text.
    if [[ "${UI_MODE:-ansi}" != "dialog" && "${UI_MODE:-ansi}" != "whiptail" ]]; then
      show_command "$cmd"
    fi

    local choice
    local menu_text
    menu_text=$(printf 'Generated command:\n\n%s\n\nWhat next?' "$cmd")

    case "${UI_MODE:-ansi}" in
      gum)
        choice=$(gum choose --header "What next?" "approve" "edit command" "explain" "edit prompt" "cancel") || choice=cancel
        ;;
      dialog)
        choice=$(dialog --stdout --title "aido" --ok-label "Approve" --menu "$menu_text" 18 70 5 \
          a "approve" e "edit command" x "explain" p "edit prompt" c "cancel" 2>&1) || choice=c
        ;;
      whiptail)
        # whiptail writes the selected tag to stderr; swap fds so we can capture it.
        choice=$(whiptail --title "aido" --ok-button "Approve" --menu "$menu_text" 18 70 5 \
          a "approve" e "edit command" x "explain" p "edit prompt" c "cancel" \
          3>&1 1>&2 2>&3) || choice=c
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

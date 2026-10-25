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
# dialog/whiptail use an infobox only when regenerating after an edit;
# the initial generation stays quiet so the menu appears without a flash.
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

# Show text to the user in a way that matches the current UI mode.
# For dialog/whiptail this is a blocking msgbox so the text isn't lost
# when the next menu opens.
show_text() {
  local title="$1"
  local body="$2"
  case "${UI_MODE:-ansi}" in
    dialog)
      dialog --title "$title" --msgbox "$body" 20 70
      ;;
    whiptail)
      whiptail --title "$title" --msgbox "$body" 20 70
      ;;
    *)
      echo
      echo "${YELLOW}${BOLD}${title}:${RESET}"
      echo "$body"
      echo
      ;;
  esac
}

# Non-blocking waiting indicator.
# dialog --infobox works. whiptail --infobox is broken in xterm-style
# terminals (blank box / alternate-screen bug), so we use a plain info
# line that stays visible on the shell.
show_wait() {
  local msg="$1"
  case "${UI_MODE:-ansi}" in
    dialog)
      dialog --title "aido" --infobox "$msg" 5 50
      ;;
    *)
      info "$msg"
      ;;
  esac
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
    local status
    menu_text=$(printf 'Generated command:\n\n%s\n\nSelect an action below, or press Approve to run it.' "$cmd")

    case "${UI_MODE:-ansi}" in
      gum)
        choice=$(gum choose --header "What next?" "approve" "edit command" "explain" "edit prompt" "cancel") || choice=cancel
        ;;
      dialog)
        choice=$(dialog --stdout --title "aido" \
          --ok-label "Approve" --cancel-label "Cancel" \
          --menu "$menu_text" 18 70 3 \
          e "edit command" x "explain" p "edit prompt" 2>&1)
        status=$?
        if [[ "$status" -ne 0 ]]; then
          choice=c
        elif [[ -z "$choice" ]]; then
          choice=a
        fi
        ;;
      whiptail)
        choice=$(whiptail --title "aido" \
          --ok-button "Approve" --cancel-button "Cancel" \
          --menu "$menu_text" 18 70 3 \
          e "edit command" x "explain" p "edit prompt" \
          3>&1 1>&2 2>&3)
        status=$?
        if [[ "$status" -ne 0 ]]; then
          choice=c
        elif [[ -z "$choice" ]]; then
          choice=a
        fi
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
        show_wait "Asking model to explain..."
        local explain_sys="You are a helpful shell assistant. Explain the following command clearly and concisely: what it does, any important flags, potential risks, and safer alternatives if relevant. Keep it short."
        local explanation
        explanation=$(call_llm "$cmd" "$explain_sys") || explanation="(explain failed)"
        show_text "Explanation" "$explanation"
        # stay in the loop so user can still approve/edit/cancel
        ;;
      p|"edit prompt")
        prompt=$(edit_in_editor "$prompt")
        cmd=""   # force regeneration
        ((retries++)) || true
        if (( retries > MAX_RETRIES )); then
          info "Too many prompt retries. Consider refining your request."
        fi
        # After the editor closes, show a regenerating indicator so the
        # screen doesn't look frozen while the model runs.
        show_wait "Regenerating command..."
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

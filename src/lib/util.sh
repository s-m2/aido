# ──────────────────────────────────────────────
# util.sh — shared helpers (die, info, dirs, history logging)
# ──────────────────────────────────────────────

# Echo an error message to stderr and exit.
die()  { echo "aido: $*" >&2; exit 1; }

# Echo an informational message to stderr.
info() { echo "→ $*" >&2; }

# Make sure the history file's directory exists.
ensure_dirs() {
  mkdir -p "$(dirname "$HISTORY_FILE")"
}

# Append a record (prompt, command, status, model) to the JSONL history log.
log_history() {
  local prompt="$1" cmd="$2" status="$3"
  ensure_dirs
  jq -n \
    --arg ts "$(date -Iseconds)" \
    --arg prompt "$prompt" \
    --arg cmd "$cmd" \
    --arg status "$status" \
    --arg model "$MODEL" \
    '{timestamp:$ts, prompt:$prompt, command:$cmd, status:$status, model:$model}' \
    >> "$HISTORY_FILE"
}

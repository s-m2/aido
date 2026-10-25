# ──────────────────────────────────────────────
# config.sh — load user configuration
#
# Persistent defaults live in ~/.config/aido/config.env (a simple
# KEY=value file). Precedence, highest to lowest:
#   1. Explicit environment variables (AIDO_MODEL=..., etc.)
#   2. The user config file
#   3. Built-in defaults
#
# A missing file is fine; defaults apply.
# ──────────────────────────────────────────────

CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/aido"
CONFIG_FILE="${CONFIG_DIR}/config.env"

# Map each config key to the explicit env var that overrides it.
# The file keys MODEL/TEMPERATURE are AIDO_MODEL/AIDO_TEMPERATURE.
declare -A KEY_ENV=(
  [MODEL]=AIDO_MODEL
  [OLLAMA_HOST]=OLLAMA_HOST
  [TEMPERATURE]=AIDO_TEMPERATURE
  [EDITOR]=EDITOR
  [HISTORY_FILE]=HISTORY_FILE
  [MAX_RETRIES]=MAX_RETRIES
)

# load_config — source the user config file, filling any key not already set
# by an explicit env var (env wins over the file).
load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local key val
  while IFS='=' read -r key val || [[ -n "$key" ]]; do
    case "$key" in
      ''|'#'*) continue ;;
    esac
    # Strip CR (CRLF) and surrounding quotes.
    val="${val%$'\r'}"
    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\") val="${val#\'}"; val="${val%\'}" ;;
    esac
    # Respect explicit env vars over the file. Skip unknown keys.
    local overridename="${KEY_ENV[$key]:-}"
    [[ -z "$overridename" ]] && continue
    [[ -n "${!overridename:-}" ]] && continue
    export "$key"="$val"
  done < "$CONFIG_FILE"
}

# apply_defaults — fill in any key not set by an explicit env var or the config
# file (env > file > default). Runs AFTER load_config(): assigning these defaults
# here (rather than at the top of the file) is deliberate, because a non-empty
# pre-default like OLLAMA_HOST would trip load_config()'s "env var already set"
# check and silently ignore the user's config file value.
apply_defaults() {
  MODEL="${MODEL:-qwen2.5-coder:7b}"
  OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
  TEMPERATURE="${TEMPERATURE:-0.1}"
  EDITOR="${EDITOR:-vim}"
  HISTORY_FILE="${HISTORY_FILE:-${HOME}/.aido/history.jsonl}"
  MAX_RETRIES="${MAX_RETRIES:-2}"
}

# ensure_config_template — make sure the config directory + template exist
# (used by --config on first run). Does NOT launch an editor.
ensure_config_template() {
  mkdir -p "$CONFIG_DIR"
  [[ -f "$CONFIG_FILE" ]] && return 0
  cat > "$CONFIG_FILE" <<'EOF'
# aido user config (~/.config/aido/config.env)
# One KEY=value per line. Lines starting with # are comments.
# Set a value to blank to fall back to the built-in default.
MODEL=qwen2.5-coder:7b
OLLAMA_HOST=http://localhost:11434
TEMPERATURE=0.1
EDITOR=vim
MAX_RETRIES=2
EOF
  info "Created template config at ${CONFIG_FILE}"
}

# validate_config — sanity-check values that would otherwise fail later
# with a confusing jq/curl error. Falls back to a safe default on bad input.
validate_config() {
  case "$TEMPERATURE" in
    ''|*[!0-9.]*|.*.*)
      info "Warning: AIDO_TEMPERATURE='${TEMPERATURE}' is not a number; using 0.1"
      TEMPERATURE=0.1
      ;;
  esac
  [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || {
    info "Warning: MAX_RETRIES='${MAX_RETRIES}' is not a number; using 2"
    MAX_RETRIES=2
  }
}

# ──────────────────────────────────────────────
# context.sh — gather environment context for the system prompt
# ──────────────────────────────────────────────

gather_context() {
  local os_info shell_info
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    os_info="${PRETTY_NAME:-$NAME $VERSION}"
  else
    os_info="$(uname -s) $(uname -r)"
  fi
  shell_info="${SHELL##*/} (${BASH_VERSION:-unknown})"

  cat <<EOF
OS: ${os_info}
Kernel: $(uname -r)
Shell: ${shell_info}
User: ${USER:-$(whoami)}
Home: ${HOME}
PWD: ${PWD}
PATH: ${PATH}
Date: $(date -Iseconds)
EOF
}

#!/usr/bin/env bash
# install.sh — install aido to your PATH.
#
# Default installs to ~/.local (user, no root needed) as:
#   ~/.local/bin/aido        +   ~/.local/lib/
#
# Flags:
#   --user            Install to ~/.local (default). No sudo required.
#   --prefix DIR      Install to DIR/bin (script) and DIR/lib (modules).
#   --sudo            Try to install to a system path with sudo when possible.
#   --force           Overwrite existing files.
#   --uninstall       Remove the aido install and its config/history.
#   --dry-run         Print what would happen without doing it.
#   -h, --help        Show this message.
#
# Usage:
#   ./scripts/install.sh                      # installs to ~/.local
#   ./scripts/install.sh --sudo               # installs to /usr/local with sudo
#   ./scripts/install.sh --prefix /opt/aido
set -euo pipefail

# ──────────────────────────────────────────────
# Locate project root and source files
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
SRC_BIN="${PROJECT_ROOT}/src/bin"
SRC_LIB="${PROJECT_ROOT}/src/lib"
SRC_AIDO="${SRC_BIN}/aido"

# ──────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────
PREFIX="${HOME}/.local"
FLAG_USER=0
FLAG_SUDO=0
FLAG_FORCE=0
FLAG_UNINSTALL=0
FLAG_DRY=0

for arg in "$@"; do
  if [[ -n "${PENDING_PREFIX:+x}" ]]; then
    PREFIX="$arg"
    PENDING_PREFIX=""
    continue
  fi
  case "$arg" in
    --user)       FLAG_USER=1 ;;
    --sudo)       FLAG_SUDO=1 ;;
    --prefix)     PENDING_PREFIX=1 ;;
    --prefix=*)   PREFIX="${arg#*=}" ;;
    --force)      FLAG_FORCE=1 ;;
    --uninstall)  FLAG_UNINSTALL=1 ;;
    --dry-run)    FLAG_DRY=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "unknown argument: $arg" >&2
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 2 ;;
  esac
done
[[ -n "${PENDING_PREFIX:+x}" ]] && { echo "error: --prefix requires a directory argument" >&2; exit 2; }

# ──────────────────────────────────────────────
# Resolve target directories
# ──────────────────────────────────────────────
BIN_DIR="${PREFIX%/}/bin"
LIB_DIR="${PREFIX%/}/lib"
HISTORY_FILE="${HOME}/.aido/history.jsonl"

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────
sudo_ok() {
  command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null
}

# Does the resolved prefix resolve to a system (non-user) location?
is_system_prefix() {
  case "${PREFIX%/}" in
    /usr|/usr/*|/opt/*|/usr/local) return 0 ;;
    *) return 1 ;;
  esac
}

# Install the files (or print what would happen).
do_install() {
  local target_bin="${BIN_DIR}/aido"
  local marker="${BIN_DIR}/.aido-install-marker"

  # Refuse to overwrite without --force.
  if [[ -e "$target_bin" && "$FLAG_FORCE" -eq 0 ]]; then
    echo "refusing: ${target_bin} already exists (use --force to overwrite)" >&2
    exit 1
  fi

  if [[ "$FLAG_DRY" -eq 1 ]]; then
    echo "would create dir : ${BIN_DIR}"
    echo "would create dir : ${LIB_DIR}"
    echo "would copy         ${SRC_AIDO} -> ${target_bin} (executable)"
    echo "would copy         ${SRC_LIB} -> ${LIB_DIR}"
    echo "would write marker : ${marker}"
    return 0
  fi

  mkdir -p "$BIN_DIR" "$LIB_DIR"
  cp -f "$SRC_AIDO" "$target_bin"
  chmod +x "$target_bin"
  cp -rf "$SRC_LIB"/. "${LIB_DIR}/"

  # Marker: lets uninstall remove only things it installed.
  printf 'PREFIX=%s\nTARGET=%s\n' "$PREFIX" "$(date -Iseconds)" > "$marker"

  echo "installed aido to ${BIN_DIR}"
  echo "modules at        ${LIB_DIR}"
}

# Uninstall the files (or print what would happen).
do_uninstall() {
  local marker="${BIN_DIR}/.aido-install-marker"
  if [[ "$FLAG_DRY" -eq 1 ]]; then
    echo "would remove file : ${BIN_DIR}/aido"
    echo "would remove file : ${marker}"
    echo "would remove dir  : ${LIB_DIR}"
    echo "would keep        ${HISTORY_FILE} (your command history)"
    return 0
  fi

  # Remove only the files aido installed, leaving other tools in bin/ intact.
  for f in "${BIN_DIR}/aido" "${marker}"; do
    if [[ -e "$f" ]]; then
      rm -f "$f"
      echo "removed ${f}"
    fi
  done
  if [[ -e "$LIB_DIR" ]]; then
    rm -rf "$LIB_DIR"
    echo "removed ${LIB_DIR}"
  else
    echo "nothing to remove: ${LIB_DIR}"
  fi
  echo "kept ${HISTORY_FILE} (your command history). Delete it to wipe history too."
}

# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
main() {
  [[ -f "$SRC_AIDO" ]] || { echo "error: aido entry point not found at ${SRC_AIDO}" >&2; exit 1; }
  [[ -d "$SRC_LIB" ]]  || { echo "error: lib dir not found at ${SRC_LIB}" >&2; exit 1; }

  if [[ "$FLAG_UNINSTALL" -eq 1 ]]; then
    # Always operate on the default user prefix for uninstall unless --prefix given.
    do_uninstall
    return 0
  fi

  # For system prefixes we need sudo; try it automatically.
  if is_system_prefix && [[ "$FLAG_USER" -eq 1 || -z "${FLAG_SUDO:+x}" ]]; then
    if sudo_ok; then
      echo "system prefix detected; re-running with sudo..." >&2
      if [[ "$FLAG_DRY" -eq 1 ]]; then
        do_install
      else
        sudo "$0" "$@" --sudo
      fi
      return 0
    fi
    echo "refusing: ${PREFIX} is a system path and sudo is not available/non-interactive." >&2
    echo "use --user (installs to ~/.local, no sudo) or run with root privileges." >&2
    exit 1
  fi

  do_install
}

main "$@"

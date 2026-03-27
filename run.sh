#!/usr/bin/env bash
# run.sh — launch Claude Code in the dangerously-safe container
#
# Usage:
#   ./run.sh                        # interactive session
#   ./run.sh "fix the bug"          # pass a prompt
#   ./run.sh --print "list files"   # non-interactive
#
# From any project directory:
#   cd ~/my-project && /path/to/dangerously-safe-container/run.sh
#
# Resume a previous session:
#   RESUME_HASH=<hash> ./run.sh     # or via: make run RESUME=<hash>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The directory to mount as /workspace — defaults to wherever you called run.sh from
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
export WORKSPACE_DIR

# The directory to mount as /home/claude — persists sessions, config, and history
CLAUDE_HOME_DIR="${CLAUDE_HOME_DIR:-${HOME}/.dangerously-safe-container/claude-home}"
export CLAUDE_HOME_DIR

# Initialize the host home dir on first run so the container has what it needs
mkdir -p "${CLAUDE_HOME_DIR}/.claude/backups"
if [[ ! -f "${CLAUDE_HOME_DIR}/.claude.json" ]]; then
  echo '{}' > "${CLAUDE_HOME_DIR}/.claude.json"
fi

# Sync GSD from this machine's ~/.claude into the container's claude home.
# Only copies when the host version differs from the container's installed version.
HOST_CLAUDE="${HOME}/.claude"
CONTAINER_CLAUDE="${CLAUDE_HOME_DIR}/.claude"
HOST_GSD_VERSION_FILE="${HOST_CLAUDE}/get-shit-done/VERSION"

if [[ -f "$HOST_GSD_VERSION_FILE" ]]; then
  HOST_GSD_VER=$(cat "$HOST_GSD_VERSION_FILE")
  CONTAINER_GSD_VER=$(cat "${CONTAINER_CLAUDE}/get-shit-done/VERSION" 2>/dev/null || echo "")

  if [[ "$HOST_GSD_VER" != "$CONTAINER_GSD_VER" ]]; then
    echo "Syncing GSD ${HOST_GSD_VER} into container home..."

    # Core GSD engine (workflows, bin, references, templates)
    mkdir -p "${CONTAINER_CLAUDE}/get-shit-done"
    cp -r "${HOST_CLAUDE}/get-shit-done/." "${CONTAINER_CLAUDE}/get-shit-done/"

    # Slash commands
    mkdir -p "${CONTAINER_CLAUDE}/commands/gsd"
    cp -r "${HOST_CLAUDE}/commands/gsd/." "${CONTAINER_CLAUDE}/commands/gsd/"

    # Agent definitions (gsd-* only — pragmatic-engineer et al. not GSD-owned)
    mkdir -p "${CONTAINER_CLAUDE}/agents"
    cp -f "${HOST_CLAUDE}"/agents/gsd-*.md "${CONTAINER_CLAUDE}/agents/" 2>/dev/null || true

    # Hooks (gsd-* only)
    mkdir -p "${CONTAINER_CLAUDE}/hooks"
    cp -f "${HOST_CLAUDE}"/hooks/gsd-*.js "${CONTAINER_CLAUDE}/hooks/" 2>/dev/null || true

    # Manifest + package.json (needed by GSD tools)
    cp -f "${HOST_CLAUDE}/gsd-file-manifest.json" "${CONTAINER_CLAUDE}/" 2>/dev/null || true
    cp -f "${HOST_CLAUDE}/package.json" "${CONTAINER_CLAUDE}/" 2>/dev/null || true
  fi

  # Write settings.json on first run — points hooks at container-local paths
  if [[ ! -f "${CONTAINER_CLAUDE}/settings.json" ]]; then
    cat > "${CONTAINER_CLAUDE}/settings.json" <<'SETTINGS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"/home/claude/.claude/hooks/gsd-check-update.js\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|Agent|Task",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/home/claude/.claude/hooks/gsd-context-monitor.js\"",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/home/claude/.claude/hooks/gsd-prompt-guard.js\"",
            "timeout": 5
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "node \"/home/claude/.claude/hooks/gsd-statusline.js\""
  }
}
SETTINGS
  fi
fi

# Load .env if present next to this script
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo >&2 "error: ANTHROPIC_API_KEY is not set."
  echo >&2 "  export ANTHROPIC_API_KEY=sk-ant-..."
  echo >&2 "  or add it to ${SCRIPT_DIR}/.env"
  exit 1
fi

IMAGE_NAME="dangerously-safe-container:latest"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "Image not found. Building ${IMAGE_NAME}..."
  docker compose --project-directory "$SCRIPT_DIR" build
fi

DOCKER_FLAGS=(--rm --interactive --tty)

# On Linux, pass through UID/GID so files written to /workspace are owned correctly.
# On macOS, Docker Desktop handles this transparently.
if [[ "$(uname -s)" == "Linux" ]]; then
  DOCKER_FLAGS+=(--user "$(id -u):$(id -g)")
fi

# Build optional --resume flag
RESUME_ARGS=()
if [[ -n "${RESUME_HASH:-}" ]]; then
  RESUME_ARGS+=(--resume "$RESUME_HASH")
fi

exec docker compose \
  --project-directory "$SCRIPT_DIR" \
  run \
  "${DOCKER_FLAGS[@]}" \
  claude \
  --dangerously-skip-permissions \
  "${RESUME_ARGS[@]}" \
  "$@"

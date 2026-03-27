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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The directory to mount as /workspace — defaults to wherever you called run.sh from
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
export WORKSPACE_DIR

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

exec docker compose \
  --project-directory "$SCRIPT_DIR" \
  run \
  "${DOCKER_FLAGS[@]}" \
  claude \
  --dangerously-skip-permissions \
  "$@"

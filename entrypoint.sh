#!/usr/bin/env bash
# Restore ~/.claude.json from backup if it has gone missing (happens because the
# file lives outside the ~/.claude/ named volume and is lost on container restart).
set -euo pipefail

CONFIG="$HOME/.claude.json"
BACKUP_DIR="$HOME/.claude/backups"

if [[ ! -f "$CONFIG" ]]; then
  latest_backup=$(ls -t "$BACKUP_DIR"/.claude.json.backup.* 2>/dev/null | head -1 || true)
  if [[ -n "$latest_backup" ]]; then
    cp "$latest_backup" "$CONFIG"
  fi
fi

exec claude "$@"

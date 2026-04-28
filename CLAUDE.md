# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A Docker-based sandbox that runs `claude --dangerously-skip-permissions` in an isolated environment. The host filesystem is mounted read-write at `/workspace`; Claude's home directory (`~/.dangerously-safe-container/claude-home`) is bind-mounted to persist sessions and config across container restarts. Networking is intentionally left unrestricted.

## Common commands

```bash
make build          # Build (or rebuild) the Docker image
make run            # Launch an interactive Claude session in the current directory
make run WORKSPACE=/path/to/project   # Run against a specific project
make run RESUME=<hash>                # Resume a previous session
make shell          # Open a bash shell inside the container
make root-shell     # Open a root shell (debugging)
make version        # Show Claude Code version in the image
make clean          # Remove image and volumes
make clean-config   # Delete persistent Claude home (resets history/settings)
make pull           # Pull fresh base image and rebuild without cache
```

From any project directory, you can also invoke directly:
```bash
/path/to/dangerously-safe-container/run.sh
/path/to/dangerously-safe-container/run.sh "fix the bug"
RESUME_HASH=<hash> /path/to/dangerously-safe-container/run.sh
```

## Configuration

Copy `.env.example` to `.env` and set values as needed:
- `ANTHROPIC_API_KEY` — required for API subscribers; Pro/Max users run `claude login` inside the container instead
- `CLAUDE_MODEL` — optional model pin (e.g. `claude-opus-4-6`)
- `ANTHROPIC_BASE_URL` — optional proxy endpoint
- `CLAUDE_CPUS` / `CLAUDE_MEMORY` — resource limits (defaults: 4 CPUs, 4 GB)

## Architecture

- **`Dockerfile`** — builds from `node:22-bookworm-slim`, installs system tools (ripgrep, fd, git, etc.), renames the `node` user to `claude`, installs Claude Code via the official installer, and sets `--dangerously-skip-permissions` as the default CMD.
- **`docker-compose.yml`** — defines the service with resource limits, drops all Linux capabilities (`cap_drop: ALL`, `no-new-privileges`), and mounts `WORKSPACE_DIR` → `/workspace` and `CLAUDE_HOME_DIR` → `/home/claude`.
- **`run.sh`** — the main launcher: sets up the persistent home dir, syncs GSD (Get Shit Done) tooling from the host's `~/.claude` into the container home if versions differ, writes a default `settings.json` for GSD hooks on first run, loads `.env`, auto-builds the image if missing, and execs into the container.
- **`entrypoint.sh`** — restores `~/.claude.json` from backup if it's missing (this file lives outside the mounted volume and can be lost on container restart), then execs `claude "$@"`.

## GSD sync behavior

On each `run.sh` invocation, if the host has GSD installed at `~/.claude/get-shit-done/`, it is synced into the container home when the version differs. This keeps the container's GSD version in sync with the host without requiring image rebuilds. The sync copies: the GSD engine, slash commands (`~/.claude/commands/gsd/`), `gsd-*` agents, `gsd-*` hooks, and manifest/package files.

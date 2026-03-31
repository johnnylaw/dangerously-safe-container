# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim AS base

LABEL org.opencontainers.image.title="dangerously-safe-container" \
      org.opencontainers.image.description="Isolated Claude Code sandbox"

# System deps — ripgrep and fd-find are used by Claude Code's search tools
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      curl \
      wget \
      ca-certificates \
      gnupg \
      python3 \
      python3-pip \
      python3-venv \
      build-essential \
      jq \
      ripgrep \
      fd-find \
      vim \
      nano \
      less \
      procps \
      unzip \
      zip \
      ssh-client \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# fd-find installs as fdfind; symlink for conventional use
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# Rename the pre-existing "node" user (UID 1000) to "claude"
RUN usermod -l claude -d /home/claude -m node \
    && groupmod -n claude node \
    && echo "claude ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt" >> /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude

# Install Claude Code via the official native installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Set up mount points and default config file
RUN mkdir -p /workspace \
    && chown claude:claude /workspace \
    && mkdir -p /home/claude/.claude/backups \
    && echo '{}' > /home/claude/.claude.json \
    && chown -R claude:claude /home/claude

COPY --chown=claude:claude entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER claude
WORKDIR /workspace

ENV PATH="/usr/local/bin:/home/claude/.local/bin:${PATH}" \
    HOME="/home/claude" \
    NODE_ENV="production" \
    CLAUDE_CODE_DISABLE_AUTOUPDATE="1"

ENTRYPOINT ["entrypoint.sh"]
CMD ["--dangerously-skip-permissions"]

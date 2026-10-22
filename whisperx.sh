#!/usr/bin/env bash
# Install / remove whisperx-service as a systemd unit that runs docker compose
# from this directory.
set -euo pipefail

NAME=whisperx
UNIT=/etc/systemd/system/$NAME.service
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
die() { echo "error: $*" >&2; exit 1; }

case "${1:-}" in
  install)
    # The container runs as the invoking user so ./cache stays owned by them,
    # also when this script is run through sudo.
    RUN_UID=${SUDO_UID:-$(id -u)}
    RUN_GID=${SUDO_GID:-$(id -g)}
    [ "$RUN_UID" -ne 0 ] || die "run as your normal user (or via sudo), not as root"

    DOCKER=$(command -v docker) || die "docker not found"
    "$DOCKER" compose version >/dev/null 2>&1 \
      || die "'docker compose' (v2 plugin) not available, see README prerequisites"

    install -d -o "$RUN_UID" -g "$RUN_GID" "$DIR/cache"
    [ -f "$DIR/.env" ] || install -o "$RUN_UID" -g "$RUN_GID" -m 600 "$DIR/.env.example" "$DIR/.env"

    sudo_ tee "$UNIT" >/dev/null <<UNIT
[Unit]
Description=whisperX ASR webservice (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=$DIR
Environment=UID=$RUN_UID GID=$RUN_GID RESTART_POLICY=no
# First start builds the image, which can take a while
ExecStartPre=$DOCKER compose build
TimeoutStartSec=0
# Runs in the foreground: systemd tracks the container's state, logs go to the journal
ExecStart=$DOCKER compose up --remove-orphans --abort-on-container-exit
ExecStop=$DOCKER compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
    sudo_ systemctl daemon-reload
    sudo_ systemctl enable --now "$NAME.service"
    echo "Installed and started $NAME.service (http://localhost:9000/docs)"
    ;;
  uninstall)
    if [ -f "$UNIT" ]; then
      sudo_ systemctl disable --now "$NAME.service" || true
      sudo_ rm -f "$UNIT"
      sudo_ systemctl daemon-reload
    fi
    cd "$DIR"
    docker compose down --rmi all || true
    BASE=$(awk '/^FROM /{print $2; exit}' Dockerfile)
    docker image rm "$BASE" 2>/dev/null || true
    echo "Removed $NAME.service and its images. Delete $DIR to also remove cached models and config;"
    echo "'docker builder prune' frees leftover build cache."
    ;;
  *)
    echo "usage: $0 install|uninstall" >&2
    exit 1
    ;;
esac

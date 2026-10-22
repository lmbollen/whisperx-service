#!/usr/bin/env bash
# Install / remove whisperx-service as a systemd unit that runs docker compose
# from this directory.
set -euo pipefail

NAME=whisperx
UNIT=/etc/systemd/system/$NAME.service
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

case "${1:-}" in
  install)
    mkdir -p "$DIR/cache"
    [ -f "$DIR/.env" ] || cp "$DIR/.env.example" "$DIR/.env"
    DOCKER=$(command -v docker)
    sudo_ tee "$UNIT" >/dev/null <<UNIT
[Unit]
Description=whisperX ASR webservice (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DIR
Environment=UID=$(id -u) GID=$(id -g)
ExecStart=$DOCKER compose up -d --build --remove-orphans
ExecStop=$DOCKER compose down
# First start builds the image, which can take a while
TimeoutStartSec=0

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
    (cd "$DIR" && docker compose down --rmi all) || true
    echo "Removed $NAME.service and image. Delete $DIR to remove models/config too."
    ;;
  *)
    echo "usage: $0 install|uninstall" >&2
    exit 1
    ;;
esac

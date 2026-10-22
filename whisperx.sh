#!/usr/bin/env bash
# Install / remove whisperx-service as a systemd unit that runs docker compose
# from this directory.
set -euo pipefail

NAME=whisperx
UNIT=/etc/systemd/system/$NAME.service
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
die() { echo "error: $*" >&2; exit 1; }
step() { echo "==> $*"; }
# Ask for the sudo password once, up front, with a prompt that says why
need_sudo() {
  [ "$(id -u)" -eq 0 ] && return
  sudo -n true 2>/dev/null && return
  echo "sudo is needed to $1."
  sudo -v -p "[sudo] password for %u: "
}

case "${1:-}" in
  install)
    # The container runs as the invoking user so ./cache stays owned by them,
    # also when this script is run through sudo.
    RUN_UID=${SUDO_UID:-$(id -u)}
    RUN_GID=${SUDO_GID:-$(id -g)}
    [ "$RUN_UID" -ne 0 ] || die "run as your normal user (or via sudo), not as root"

    DOCKER=$(command -v docker) || die "docker not found"
    need_sudo "install the systemd unit"

    step "Checking for docker compose (as root, like the service runs it)"
    # A plugin only in ~/.docker/cli-plugins would pass as you but fail as root
    sudo_ "$DOCKER" compose version \
      || die "'docker compose' (v2 plugin) not available to root, see README prerequisites"

    step "Preparing ./cache and .env"
    install -d -o "$RUN_UID" -g "$RUN_GID" "$DIR/cache"
    [ -f "$DIR/.env" ] || install -o "$RUN_UID" -g "$RUN_GID" -m 600 "$DIR/.env.example" "$DIR/.env"

    step "Building the image (the first build downloads ~5 GB and can take several minutes)"
    (cd "$DIR" && sudo_ "$DOCKER" compose build)

    step "Writing $UNIT"
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
    step "Enabling and starting $NAME.service"
    sudo_ systemctl daemon-reload
    sudo_ systemctl enable --now "$NAME.service"
    echo
    echo "Done. The API comes up at http://localhost:9000/docs within a few seconds;"
    echo "models are downloaded on the first request. Follow it with: journalctl -u $NAME -f"
    ;;
  uninstall)
    need_sudo "remove the systemd unit and images"
    if [ -f "$UNIT" ]; then
      step "Stopping and removing $NAME.service"
      sudo_ systemctl disable --now "$NAME.service" || true
      sudo_ rm -f "$UNIT"
      sudo_ systemctl daemon-reload
    fi
    cd "$DIR"
    step "Removing the container and images"
    sudo_ docker compose down --rmi all || true
    BASE=$(awk '/^FROM /{print $2; exit}' Dockerfile)
    sudo_ docker image rm "$BASE" 2>/dev/null || true
    echo
    echo "Removed $NAME.service and its images. Delete $DIR to also remove cached models and config;"
    echo "'docker builder prune' frees leftover build cache."
    ;;
  *)
    echo "usage: $0 install|uninstall" >&2
    exit 1
    ;;
esac

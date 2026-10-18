#!/usr/bin/env bash
set -e

source "$HOME/projects/podman-sh-lib/lib/podman.sh"

QUADLET_DIR="$HOME/.config/containers/systemd"
USER_UNIT_DIR="$HOME/.config/systemd/user"
PROJECT_DIR="$HOME/projects/forgejo-iac"
DATA_DIR="/srv/forgejo-data"

base_log_step "Preparing directories and files."
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/db"
mkdir -p "$DATA_DIR/data"
mkdir -p "$DATA_DIR/backups"

base_log_step "Correct rights."
chmod 755 "$DATA_DIR/backups"
chmod 644 "$PROJECT_DIR/forgejo.env"
chmod +x "$PROJECT_DIR/backup-forgejo.sh"

base_log_step "Containers and networks. Creating Quadlet symlinks."

ln -sf "$PROJECT_DIR/forgejo-internal.network" "$QUADLET_DIR/"
ln -sf "$PROJECT_DIR/forgejo-db.container" "$QUADLET_DIR/"
ln -sf "$PROJECT_DIR/forgejo-server.container" "$QUADLET_DIR/"

base_log_step "Services and timers. Creating systemd unit symlinks."

ln -sf "$PROJECT_DIR/forgejo-backup.service" "$USER_UNIT_DIR/"
ln -sf "$PROJECT_DIR/forgejo-backup.timer" "$USER_UNIT_DIR/"

base_log_step "Reloading systemd user configuration"
systemctl --user daemon-reload

base_log_step "Restart user services"
systemctl --user restart forgejo-server.service

base_log_step "Start timers"
systemctl --user enable --now forgejo-backup.timer

base_log_step "Check status... Please, waiting."
sleep 3
systemctl --user status forgejo-server.service --no-pager
podman ps --filter name=forgejo-server
systemctl --user list-timers --no-pager

base_log_ok "Service deployed."
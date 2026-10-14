#!/usr/bin/env bash
set -e

PODMAN_SH_LIB="$HOME/projects/podman-sh-lib"
source "$PODMAN_SH_LIB/lib/podman.sh"

BACKUP_DIR="/srv/forgejo-data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
KEEP=3
INNER_BACKUP_DIR="/data/backups"
APP_INI="/data/gitea/conf/app.ini"

base_log_step "Preparing directories and files."
mkdir -p "$BACKUP_DIR"

if ! podman ps --format '{{.Names}}' | grep -q "^forgejo-server$"; then
    base_log_error "Container forgejo-server not started. Backup stopped." >&2
    exit 1
fi

if ! podman ps --format '{{.Names}}' | grep -q "^forgejo-db$"; then
    base_log_error "Container forgejo-db not started. Backup stopped." >&2
    exit 1
fi

base_log_step "Run backup and rotation."

base_log_info "Create target directory inside container"
podman exec -u git forgejo-server mkdir -p "$INNER_BACKUP_DIR"
podman exec -u root forgejo-server chown git:git "$INNER_BACKUP_DIR"

base_log_info "Create backup (DB + repos + LFS + attachments)"
podman exec -u git forgejo-server forgejo dump -c "$APP_INI" --file "$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_info "Copy to host"
podman cp "forgejo-server:$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip" "$BACKUP_DIR/"

base_log_warn "Remove from container to avoid disk bloat"
podman exec -u git forgejo-server rm -f "$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_info "Rotation on host: keep only N latest"
find "$BACKUP_DIR" -type f -name "forgejo-backup-*.zip" -printf '%T@ %p\n' \
    | sort -rn | tail -n +$((KEEP + 1)) | cut -d' ' -f2- \
    | xargs -r rm -f

MSG="Backup completed and saved to $BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_ok "$MSG"

source "$HOME/projects/notify-sh-lib/lib/email.sh"
email_send "genre-grunt-dander@duck.com" "Systemd notify - forgejo backup" "$MSG" 
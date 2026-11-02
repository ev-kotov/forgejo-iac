#!/usr/bin/env bash
set -e

source "$HOME/projects/podman-sh-lib/lib/podman.sh"

base_log_step "Preparing directories and files."
BACKUP_DIR="/srv/forgejo-data/backups"
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
INNER_BACKUP_DIR="/data/backups"
podman exec -u root forgejo-server mkdir -p "$INNER_BACKUP_DIR"
podman exec -u root forgejo-server chown git:git "$INNER_BACKUP_DIR"
podman exec -u root forgejo-server chmod 755 "$INNER_BACKUP_DIR"
podman exec -u root forgejo-server chmod 755 /data

base_log_info "Create backup (DB + repos + LFS + attachments)"
APP_INI="/data/gitea/conf/app.ini"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
podman exec -u git forgejo-server forgejo dump -c "$APP_INI" --file "$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_info "Copy to host"
podman cp "forgejo-server:$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip" "$BACKUP_DIR/"

podman_marker_set "$BACKUP_DIR/.last-dump-is-ok"

base_log_warn "Remove from container to avoid disk bloat"
podman exec -u git forgejo-server rm -f "$INNER_BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_info "Rotation on host: keep only N latest"
KEEP=3
find "$BACKUP_DIR" -type f -name "forgejo-backup-*.zip" -printf '%T@ %p\n' \
    | sort -rn | tail -n +$((KEEP + 1)) | cut -d' ' -f2- \
    | xargs -r rm -f

MSG="Backup completed and saved to $BACKUP_DIR/forgejo-backup-$TIMESTAMP.zip"

base_log_ok "$MSG"

source "$HOME/projects/notify-sh-lib/lib/email.sh"

set -a
source "$HOME/projects/forgejo-iac/forgejo.env"
set +a

email_send "$EMAIL" "Systemd notify - forgejo backup" "$MSG" 

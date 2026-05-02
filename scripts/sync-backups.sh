#!/bin/sh
set -eu

BACKUP_ROOT="${BACKUP_ROOT:-backups}"
BACKUP_REMOTE="${BACKUP_REMOTE:-}"
RCLONE="${RCLONE:-rclone}"

if [ -z "$BACKUP_REMOTE" ]; then
	echo "Set BACKUP_REMOTE, for example: r2:writefreely-backups" >&2
	exit 2
fi

if ! command -v "$RCLONE" >/dev/null 2>&1; then
	echo "rclone is not installed or RCLONE points to a missing command" >&2
	exit 127
fi

if [ ! -d "$BACKUP_ROOT" ]; then
	echo "Backup directory does not exist: ${BACKUP_ROOT}" >&2
	exit 2
fi

echo "Syncing ${BACKUP_ROOT}/ to ${BACKUP_REMOTE}"
"$RCLONE" sync "${BACKUP_ROOT}/" "$BACKUP_REMOTE" \
	--create-empty-src-dirs \
	--checksum \
	--transfers "${RCLONE_TRANSFERS:-4}" \
	--checkers "${RCLONE_CHECKERS:-8}"

echo "Backup sync complete"

#!/bin/sh
set -eu
umask 077

COMPOSE="${COMPOSE:-docker compose}"
DOCKER="${DOCKER:-docker}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-writefreely-platform}"
BACKUP_ROOT="${BACKUP_ROOT:-backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_DIR:-${BACKUP_ROOT}/${STAMP}}"

env_default() {
	key="$1"
	default="$2"
	eval "current=\${$key:-}"

	if [ -n "$current" ]; then
		printf "%s" "$current"
		return
	fi

	if [ -f .env ]; then
		value="$(awk -F= -v key="$key" '$0 !~ /^[[:space:]]*#/ && $1 == key { sub(/^[^=]*=/, ""); print; exit }' .env)"
		if [ -n "$value" ]; then
			printf "%s" "$value"
			return
		fi
	fi

	printf "%s" "$default"
}

MYSQL_DATABASE="$(env_default MYSQL_DATABASE writefreely)"
MYSQL_USER="$(env_default MYSQL_USER writefreely)"
MYSQL_PASSWORD="$(env_default MYSQL_PASSWORD writefreely)"
HELPER_IMAGE="${HELPER_IMAGE:-caddy:2.10-alpine}"
BACKUP_UID="${BACKUP_UID:-$(id -u)}"
BACKUP_GID="${BACKUP_GID:-$(id -g)}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "Writing database backup to ${BACKUP_DIR}/mysql.sql"
# shellcheck disable=SC2086
$COMPOSE exec -T db mysqldump \
	--single-transaction \
	--quick \
	--no-tablespaces \
	--user="$MYSQL_USER" \
	--password="$MYSQL_PASSWORD" \
	"$MYSQL_DATABASE" > "${BACKUP_DIR}/mysql.sql"

backup_volume() {
	volume="$1"
	output="$2"

	echo "Writing volume backup to ${BACKUP_DIR}/${output}"
	# shellcheck disable=SC2086
	$DOCKER run --rm \
		-v "${PROJECT_NAME}_${volume}:/volume:ro" \
		-v "$PWD/${BACKUP_DIR}:/backup:Z" \
		"$HELPER_IMAGE" \
		sh -c "tar -czf '/backup/${output}' -C /volume . && chown ${BACKUP_UID}:${BACKUP_GID} '/backup/${output}'"
}

backup_volume writefreely_data writefreely_data.tgz
backup_volume caddy_data caddy_data.tgz

cat > "${BACKUP_DIR}/manifest.txt" <<EOF
created_at=${STAMP}
project_name=${PROJECT_NAME}
mysql_database=${MYSQL_DATABASE}
writefreely_volume=${PROJECT_NAME}_writefreely_data
caddy_volume=${PROJECT_NAME}_caddy_data
EOF
chmod 600 "${BACKUP_DIR}/manifest.txt"

echo "Backup complete: ${BACKUP_DIR}"

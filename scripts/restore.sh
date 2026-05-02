#!/bin/sh
set -eu

COMPOSE="${COMPOSE:-docker compose}"
DOCKER="${DOCKER:-docker}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$PWD")}"
BACKUP_DIR="${1:-${BACKUP:-}}"

if [ -z "$BACKUP_DIR" ]; then
	echo "Usage: $0 backups/<timestamp>" >&2
	exit 2
fi

if [ ! -f "${BACKUP_DIR}/mysql.sql" ]; then
	echo "Missing ${BACKUP_DIR}/mysql.sql" >&2
	exit 2
fi

if [ -f .env ]; then
	set -a
	# shellcheck disable=SC1091
	. ./.env
	set +a
fi

MYSQL_DATABASE="${MYSQL_DATABASE:-writefreely}"
MYSQL_USER="${MYSQL_USER:-writefreely}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-writefreely}"
HELPER_IMAGE="${HELPER_IMAGE:-caddy:2.10-alpine}"

restore_volume() {
	archive="$1"
	volume="$2"

	if [ ! -f "${BACKUP_DIR}/${archive}" ]; then
		echo "Missing ${BACKUP_DIR}/${archive}" >&2
		exit 2
	fi

	echo "Restoring ${PROJECT_NAME}_${volume} from ${archive}"
	# shellcheck disable=SC2086
	$DOCKER run --rm \
		-v "${PROJECT_NAME}_${volume}:/volume" \
		-v "$PWD/${BACKUP_DIR}:/backup:ro,Z" \
		"$HELPER_IMAGE" \
		sh -c "find /volume -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar -xzf /backup/${archive} -C /volume"
}

echo "Stopping services that write to persistent volumes"
# shellcheck disable=SC2086
$COMPOSE stop writefreely caddy

restore_volume writefreely_data.tgz writefreely_data
restore_volume caddy_data.tgz caddy_data

echo "Starting database"
# shellcheck disable=SC2086
$COMPOSE up -d db

echo "Restoring MySQL database ${MYSQL_DATABASE}"
# shellcheck disable=SC2086
$COMPOSE exec -T db mysql \
	--user="$MYSQL_USER" \
	--password="$MYSQL_PASSWORD" \
	"$MYSQL_DATABASE" < "${BACKUP_DIR}/mysql.sql"

echo "Starting application services"
# shellcheck disable=SC2086
$COMPOSE up -d writefreely caddy

echo "Restore complete"

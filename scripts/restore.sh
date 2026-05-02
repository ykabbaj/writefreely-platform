#!/bin/sh
set -eu

COMPOSE="${COMPOSE:-docker compose}"
DOCKER="${DOCKER:-docker}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-writefreely-platform}"
BACKUP_DIR="${1:-${BACKUP:-}}"

if [ -z "$BACKUP_DIR" ]; then
	echo "Usage: $0 backups/<timestamp>" >&2
	exit 2
fi

if [ ! -f "${BACKUP_DIR}/mysql.sql" ]; then
	echo "Missing ${BACKUP_DIR}/mysql.sql" >&2
	exit 2
fi

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

wait_for_database() {
	# shellcheck disable=SC2086
	until $COMPOSE exec -T db mysqladmin ping \
		--host=127.0.0.1 \
		--user="$MYSQL_USER" \
		--password="$MYSQL_PASSWORD" \
		--silent >/dev/null 2>&1; do
		echo "Waiting for MySQL..."
		sleep 2
	done
}

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
wait_for_database

echo "Restoring MySQL database ${MYSQL_DATABASE}"
# shellcheck disable=SC2086
$COMPOSE exec -T db mysql \
	--host=127.0.0.1 \
	--user="$MYSQL_USER" \
	--password="$MYSQL_PASSWORD" \
	"$MYSQL_DATABASE" < "${BACKUP_DIR}/mysql.sql"

echo "Starting application services"
# shellcheck disable=SC2086
$COMPOSE up -d writefreely caddy

echo "Restore complete"

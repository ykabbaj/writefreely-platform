#!/bin/sh
set -eu

COMPOSE="${COMPOSE:-docker compose}"
DOCKER="${DOCKER:-docker}"
RESTORE_TEST_PROJECT_NAME="${RESTORE_TEST_PROJECT_NAME:-writefreely-platform-restore-test}"
RESTORE_TEST_HTTP_PORT="${RESTORE_TEST_HTTP_PORT:-18081}"
RESTORE_TEST_HTTPS_PORT="${RESTORE_TEST_HTTPS_PORT:-18444}"
RESTORE_TEST_TIMEOUT_SECONDS="${RESTORE_TEST_TIMEOUT_SECONDS:-180}"
RESTORE_TEST_BACKUP_ROOT="${RESTORE_TEST_BACKUP_ROOT:-backups/restore-test}"
RESTORE_TEST_URL="${RESTORE_TEST_URL:-https://localhost:${RESTORE_TEST_HTTPS_PORT}/}"
RESTORE_TEST_BACKUP_DIR="${RESTORE_TEST_BACKUP_DIR:-${RESTORE_TEST_BACKUP_ROOT}/$(date -u +%Y%m%dT%H%M%SZ)}"
RESTORE_TEST_CLEAN_BACKUP="${RESTORE_TEST_CLEAN_BACKUP:-true}"

export COMPOSE_PROJECT_NAME="$RESTORE_TEST_PROJECT_NAME"
export HTTP_PORT="$RESTORE_TEST_HTTP_PORT"
export HTTPS_PORT="$RESTORE_TEST_HTTPS_PORT"
export CADDY_SITE_ADDRESS="${CADDY_SITE_ADDRESS:-https://localhost}"
export WRITEFREELY_HOST="${WRITEFREELY_HOST:-https://localhost:${RESTORE_TEST_HTTPS_PORT}}"

cleanup() {
	if [ "${RESTORE_TEST_KEEP_STACK:-false}" != "true" ]; then
		# shellcheck disable=SC2086
		$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
	fi
}

wait_for_site() {
	started_at="$(date +%s)"

	while :; do
		if curl -ksSf --max-time 5 "$RESTORE_TEST_URL" >/dev/null 2>&1; then
			return 0
		fi

		now="$(date +%s)"
		if [ "$((now - started_at))" -ge "$RESTORE_TEST_TIMEOUT_SECONDS" ]; then
			echo "Timed out waiting for ${RESTORE_TEST_URL}" >&2
			# shellcheck disable=SC2086
			$COMPOSE ps >&2 || true
			# shellcheck disable=SC2086
			$COMPOSE logs --tail=200 >&2 || true
			return 1
		fi

		sleep 5
	done
}

trap cleanup EXIT INT TERM

# shellcheck disable=SC2086
$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true

echo "Starting restore-test source stack ${RESTORE_TEST_PROJECT_NAME}"
# shellcheck disable=SC2086
$COMPOSE up -d --build
wait_for_site

echo "Creating test backup at ${RESTORE_TEST_BACKUP_DIR}"
COMPOSE="$COMPOSE" \
DOCKER="$DOCKER" \
BACKUP_DIR="$RESTORE_TEST_BACKUP_DIR" \
scripts/backup.sh

echo "Recreating empty volumes"
# shellcheck disable=SC2086
$COMPOSE down -v --remove-orphans

echo "Restoring backup into fresh volumes"
COMPOSE="$COMPOSE" \
DOCKER="$DOCKER" \
BACKUP="$RESTORE_TEST_BACKUP_DIR" \
scripts/restore.sh

wait_for_site

echo "Restore test passed"

if [ "$RESTORE_TEST_CLEAN_BACKUP" = "true" ]; then
	rm -rf "$RESTORE_TEST_BACKUP_DIR"
fi

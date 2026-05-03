#!/bin/sh
set -eu

COMPOSE="${COMPOSE:-docker compose}"
SMOKE_PROJECT_NAME="${SMOKE_PROJECT_NAME:-writefreely-platform-smoke}"
SMOKE_HTTP_PORT="${SMOKE_HTTP_PORT:-18080}"
SMOKE_HTTPS_PORT="${SMOKE_HTTPS_PORT:-18443}"
SMOKE_TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-180}"
SMOKE_URL="${SMOKE_URL:-https://localhost:${SMOKE_HTTPS_PORT}/}"

export COMPOSE_PROJECT_NAME="$SMOKE_PROJECT_NAME"
export HTTP_PORT="$SMOKE_HTTP_PORT"
export HTTPS_PORT="$SMOKE_HTTPS_PORT"
export CADDY_SITE_ADDRESS="${CADDY_SITE_ADDRESS:-https://localhost}"
export WRITEFREELY_HOST="${WRITEFREELY_HOST:-https://localhost:${SMOKE_HTTPS_PORT}}"

cleanup() {
	if [ "${SMOKE_KEEP_STACK:-false}" != "true" ]; then
		# shellcheck disable=SC2086
		$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
	fi
}

wait_for_site() {
	started_at="$(date +%s)"

	while :; do
		if curl -ksSf --max-time 5 "$SMOKE_URL" >/dev/null 2>&1; then
			return 0
		fi

		now="$(date +%s)"
		if [ "$((now - started_at))" -ge "$SMOKE_TIMEOUT_SECONDS" ]; then
			echo "Timed out waiting for ${SMOKE_URL}" >&2
			# shellcheck disable=SC2086
			$COMPOSE ps >&2 || true
			# shellcheck disable=SC2086
			$COMPOSE logs --tail=200 >&2 || true
			return 1
		fi

		sleep 5
	done
}

check_security_headers() {
	headers="$(curl -ksSI --max-time 5 "$SMOKE_URL" | tr -d '\r')"

	printf "%s\n" "$headers" | grep -qi '^Strict-Transport-Security:' || {
		echo "Missing Strict-Transport-Security header" >&2
		return 1
	}

	printf "%s\n" "$headers" | grep -qi '^X-Content-Type-Options: nosniff$' || {
		echo "Missing X-Content-Type-Options nosniff header" >&2
		return 1
	}

	printf "%s\n" "$headers" | grep -qi '^X-Frame-Options: DENY$' || {
		echo "Missing X-Frame-Options DENY header" >&2
		return 1
	}
}

trap cleanup EXIT INT TERM

# shellcheck disable=SC2086
$COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true

echo "Starting smoke-test stack ${SMOKE_PROJECT_NAME}"
# shellcheck disable=SC2086
$COMPOSE up -d --build

echo "Waiting for ${SMOKE_URL}"
wait_for_site
check_security_headers

echo "Smoke test passed"

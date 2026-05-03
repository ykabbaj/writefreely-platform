#!/bin/sh
set -eu

COMPOSE="${COMPOSE:-docker compose}"

# shellcheck disable=SC2086
$COMPOSE exec -T writefreely sh -eu -c '
	if [ -z "${WRITEFREELY_ADMIN_USER:-}" ] || [ -z "${WRITEFREELY_ADMIN_PASSWORD:-}" ]; then
		echo "WRITEFREELY_ADMIN_USER and WRITEFREELY_ADMIN_PASSWORD must be set" >&2
		exit 2
	fi

	case "$WRITEFREELY_ADMIN_USER" in
		admin|Admin|ADMIN)
			echo "admin is a reserved WriteFreely username; set WRITEFREELY_ADMIN_USER to another value" >&2
			exit 3
			;;
	esac

	credential="${WRITEFREELY_ADMIN_USER}:${WRITEFREELY_ADMIN_PASSWORD}"

	if writefreely -c /data/config.ini user reset-pass "$credential"; then
		echo "Reset admin password for ${WRITEFREELY_ADMIN_USER}"
	else
		echo "Admin user does not exist; creating ${WRITEFREELY_ADMIN_USER}"
		writefreely -c /data/config.ini user create --admin "$credential"
	fi
'

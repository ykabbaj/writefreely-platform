#!/bin/sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"

if [ -f "$ENV_FILE" ] && [ "${INIT_FORCE:-false}" != "true" ]; then
	echo "${ENV_FILE} already exists. Set INIT_FORCE=true to regenerate it." >&2
	exit 2
fi

if [ ! -f .env.example ]; then
	echo "Missing .env.example" >&2
	exit 2
fi

random_hex() {
	if command -v openssl >/dev/null 2>&1; then
		openssl rand -hex 32
	else
		od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
	fi
}

set_env() {
	key="$1"
	value="$2"
	tmp="${ENV_FILE}.tmp"

	awk -v key="$key" -v value="$value" '
		BEGIN { updated = 0 }
		$0 ~ "^" key "=" {
			print key "=" value
			updated = 1
			next
		}
		{ print }
		END {
			if (updated == 0) {
				print key "=" value
			}
		}
	' "$ENV_FILE" > "$tmp"
	mv "$tmp" "$ENV_FILE"
}

cp .env.example "$ENV_FILE"
chmod 600 "$ENV_FILE"

set_env MYSQL_ROOT_PASSWORD "$(random_hex)"
set_env MYSQL_PASSWORD "$(random_hex)"
set_env WRITEFREELY_ADMIN_PASSWORD "$(random_hex)"

echo "Created ${ENV_FILE} with generated database and admin passwords."
echo "Review ${ENV_FILE}, then run: make up"

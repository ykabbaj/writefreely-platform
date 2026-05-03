#!/bin/sh
set -eu

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_TARGET="${DEPLOY_TARGET:-}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/writefreely-platform}"
DEPLOY_REF="${DEPLOY_REF:-main}"
DEPLOY_REPO="${DEPLOY_REPO:-https://github.com/ykabbaj/writefreely-platform.git}"
WRITEFREELY_IMAGE="${WRITEFREELY_IMAGE:-ghcr.io/ykabbaj/writefreely-platform:latest}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.env}"
GHCR_USERNAME="${GHCR_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"
SSH="${SSH:-ssh}"

local_env_value() {
	key="$1"
	eval "current=\${$key:-}"

	if [ -n "$current" ]; then
		printf "%s" "$current"
		return
	fi

	if [ -f "$DEPLOY_ENV_FILE" ]; then
		awk -F= -v key="$key" '$0 !~ /^[[:space:]]*#/ && $1 == key { sub(/^[^=]*=/, ""); print; exit }' "$DEPLOY_ENV_FILE"
	fi
}

DEPLOY_SITE_ADDRESS="${DEPLOY_SITE_ADDRESS:-$(local_env_value CADDY_SITE_ADDRESS)}"
DEPLOY_HOST_URL="${DEPLOY_HOST_URL:-$(local_env_value WRITEFREELY_HOST)}"
DEPLOY_SITE_NAME="${DEPLOY_SITE_NAME:-$(local_env_value WRITEFREELY_SITE_NAME)}"
DEPLOY_ADMIN_USER="${DEPLOY_ADMIN_USER:-$(local_env_value WRITEFREELY_ADMIN_USER)}"
DEPLOY_OPEN_REGISTRATION="${DEPLOY_OPEN_REGISTRATION:-$(local_env_value WRITEFREELY_OPEN_REGISTRATION)}"
DEPLOY_SINGLE_USER="${DEPLOY_SINGLE_USER:-$(local_env_value WRITEFREELY_SINGLE_USER)}"
DEPLOY_FEDERATION="${DEPLOY_FEDERATION:-$(local_env_value WRITEFREELY_FEDERATION)}"
DEPLOY_PUBLIC_STATS="${DEPLOY_PUBLIC_STATS:-$(local_env_value WRITEFREELY_PUBLIC_STATS)}"

if [ -z "$DEPLOY_TARGET" ]; then
	if [ -z "$DEPLOY_HOST" ]; then
		echo "Usage: DEPLOY_HOST=<host> [DEPLOY_USER=root] [WRITEFREELY_IMAGE=...] make deploy" >&2
		exit 2
	fi

	DEPLOY_TARGET="${DEPLOY_USER}@${DEPLOY_HOST}"
fi

if [ "$DEPLOY_SITE_ADDRESS" = "https://localhost" ] || [ "$DEPLOY_HOST_URL" = "https://localhost" ]; then
	echo "Refusing deploy with localhost site values from ${DEPLOY_ENV_FILE}." >&2
	echo "Set production CADDY_SITE_ADDRESS and WRITEFREELY_HOST in ${DEPLOY_ENV_FILE}," >&2
	echo "or override with DEPLOY_SITE_ADDRESS and DEPLOY_HOST_URL." >&2
	exit 3
fi

quote() {
	printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

remote_env="DEPLOY_PATH=$(quote "$DEPLOY_PATH") DEPLOY_REF=$(quote "$DEPLOY_REF") DEPLOY_REPO=$(quote "$DEPLOY_REPO") WRITEFREELY_IMAGE=$(quote "$WRITEFREELY_IMAGE") DEPLOY_SITE_ADDRESS=$(quote "$DEPLOY_SITE_ADDRESS") DEPLOY_HOST_URL=$(quote "$DEPLOY_HOST_URL") DEPLOY_SITE_NAME=$(quote "$DEPLOY_SITE_NAME") DEPLOY_ADMIN_USER=$(quote "$DEPLOY_ADMIN_USER") DEPLOY_OPEN_REGISTRATION=$(quote "$DEPLOY_OPEN_REGISTRATION") DEPLOY_SINGLE_USER=$(quote "$DEPLOY_SINGLE_USER") DEPLOY_FEDERATION=$(quote "$DEPLOY_FEDERATION") DEPLOY_PUBLIC_STATS=$(quote "$DEPLOY_PUBLIC_STATS") GHCR_USERNAME=$(quote "$GHCR_USERNAME") GHCR_TOKEN=$(quote "$GHCR_TOKEN")"

echo "Deploying ${WRITEFREELY_IMAGE} to ${DEPLOY_TARGET}:${DEPLOY_PATH}"

# shellcheck disable=SC2086
$SSH "$DEPLOY_TARGET" "$remote_env sh -s" <<'REMOTE'
set -eu

missing_tools=""
for tool in git docker make; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		missing_tools="${missing_tools} ${tool}"
	fi
done

if [ -n "$missing_tools" ]; then
	echo "Missing required tools on the VM:${missing_tools}" >&2
	echo "Install Git, Docker, Docker Compose, and Make before deploying." >&2
	echo "See docs/vps.md for VPS bootstrap commands." >&2
	exit 127
fi

if [ ! -d "$DEPLOY_PATH/.git" ]; then
	echo "Cloning repository"
	mkdir -p "$(dirname "$DEPLOY_PATH")"
	git clone "$DEPLOY_REPO" "$DEPLOY_PATH"
fi

cd "$DEPLOY_PATH"

echo "Updating repository"
git fetch --prune --tags origin
git checkout "$DEPLOY_REF"
if git symbolic-ref -q HEAD >/dev/null; then
	git pull --ff-only origin "$DEPLOY_REF"
fi

if [ ! -f .env ]; then
	echo "Creating .env"
	make init
fi

set_env() {
	key="$1"
	value="$2"
	tmp=".env.tmp"

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
	' .env > "$tmp"
	mv "$tmp" .env
	chmod 600 .env
}

[ -n "$DEPLOY_SITE_ADDRESS" ] && set_env CADDY_SITE_ADDRESS "$DEPLOY_SITE_ADDRESS"
[ -n "$DEPLOY_HOST_URL" ] && set_env WRITEFREELY_HOST "$DEPLOY_HOST_URL"
[ -n "$DEPLOY_SITE_NAME" ] && set_env WRITEFREELY_SITE_NAME "$DEPLOY_SITE_NAME"
[ -n "$DEPLOY_ADMIN_USER" ] && set_env WRITEFREELY_ADMIN_USER "$DEPLOY_ADMIN_USER"
[ -n "$DEPLOY_OPEN_REGISTRATION" ] && set_env WRITEFREELY_OPEN_REGISTRATION "$DEPLOY_OPEN_REGISTRATION"
[ -n "$DEPLOY_SINGLE_USER" ] && set_env WRITEFREELY_SINGLE_USER "$DEPLOY_SINGLE_USER"
[ -n "$DEPLOY_FEDERATION" ] && set_env WRITEFREELY_FEDERATION "$DEPLOY_FEDERATION"
[ -n "$DEPLOY_PUBLIC_STATS" ] && set_env WRITEFREELY_PUBLIC_STATS "$DEPLOY_PUBLIC_STATS"

env_value() {
	key="$1"
	awk -F= -v key="$key" '$0 !~ /^[[:space:]]*#/ && $1 == key { sub(/^[^=]*=/, ""); print; exit }' .env
}

site_address="$(env_value CADDY_SITE_ADDRESS)"
host_url="$(env_value WRITEFREELY_HOST)"
admin_password="$(env_value WRITEFREELY_ADMIN_PASSWORD)"
admin_user="$(env_value WRITEFREELY_ADMIN_USER)"
mysql_password="$(env_value MYSQL_PASSWORD)"
mysql_root_password="$(env_value MYSQL_ROOT_PASSWORD)"

if [ "$site_address" = "https://localhost" ] || [ "$host_url" = "https://localhost" ]; then
	echo "Refusing deploy with localhost site values." >&2
	echo "Pass DEPLOY_SITE_ADDRESS=<domain> and DEPLOY_HOST_URL=https://<domain>." >&2
	exit 3
fi

case "$admin_password:$mysql_password:$mysql_root_password" in
	*change-this*)
		echo "Refusing deploy with default credentials in .env." >&2
		exit 3
		;;
esac

case "$admin_user" in
	admin|Admin|ADMIN)
		echo "Refusing deploy with reserved WriteFreely admin username: ${admin_user}" >&2
		echo "Set WRITEFREELY_ADMIN_USER to a non-reserved username, such as owner." >&2
		exit 3
		;;
esac

echo "Rendering release Compose config"
WRITEFREELY_IMAGE="$WRITEFREELY_IMAGE" make config >/dev/null

if [ -n "$GHCR_USERNAME" ] && [ -n "$GHCR_TOKEN" ]; then
	echo "Logging in to GHCR"
	printf "%s" "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin >/dev/null
else
	echo "Clearing stale GHCR credentials"
	docker logout ghcr.io >/dev/null 2>&1 || true
fi

echo "Pulling image"
docker pull "$WRITEFREELY_IMAGE"

echo "Starting stack"
WRITEFREELY_IMAGE="$WRITEFREELY_IMAGE" make up

echo "Service state"
WRITEFREELY_IMAGE="$WRITEFREELY_IMAGE" make ps
REMOTE

#!/bin/sh
set -eu

CONFIG_FILE="${WRITEFREELY_CONFIG_FILE:-/data/config.ini}"
INIT_MARKER="/data/.initialized"
ADMIN_MARKER="/data/.admin-created"
WRITEFREELY_BIN="${WRITEFREELY_BIN:-/usr/local/bin/writefreely}"

db_host="${WRITEFREELY_DB_HOST:-db}"
db_port="${WRITEFREELY_DB_PORT:-3306}"
db_name="${WRITEFREELY_DB_NAME:-writefreely}"
db_user="${WRITEFREELY_DB_USER:-writefreely}"
db_password="${WRITEFREELY_DB_PASSWORD:-writefreely}"
site_name="${WRITEFREELY_SITE_NAME:-MyBlog}"
site_host="${WRITEFREELY_HOST:-https://localhost}"
app_port="${WRITEFREELY_PORT:-8080}"

bool() {
	case "${1:-false}" in
		true|TRUE|1|yes|YES) printf "true" ;;
		*) printf "false" ;;
	esac
}

hash_seed() {
	head -c 32 /dev/urandom | base64
}

set_config_value() {
	section="$1"
	key="$2"
	padding="$3"
	value="$4"
	tmp="${CONFIG_FILE}.tmp"
	line="${key}${padding}= ${value}"

	awk -v section="[$section]" -v key="$key" -v line="$line" '
		$0 ~ /^\[/ {
			in_section = ($0 == section)
		}
		in_section && $0 ~ "^" key "[[:space:]]*=" {
			print line
			next
		}
		{ print }
	' "$CONFIG_FILE" > "$tmp"
	mv "$tmp" "$CONFIG_FILE"
}

sync_env_config() {
	set_config_value "database" "username" " " "$db_user"
	set_config_value "database" "password" " " "$db_password"
	set_config_value "database" "database" " " "$db_name"
	set_config_value "database" "host" "     " "$db_host"
	set_config_value "database" "port" "     " "$db_port"

	set_config_value "app" "site_name" "             " "$site_name"
	set_config_value "app" "host" "                  " "$site_host"
	set_config_value "app" "single_user" "           " "$(bool "${WRITEFREELY_SINGLE_USER:-false}")"
	set_config_value "app" "open_registration" "     " "$(bool "${WRITEFREELY_OPEN_REGISTRATION:-false}")"
	set_config_value "app" "federation" "            " "$(bool "${WRITEFREELY_FEDERATION:-false}")"
	set_config_value "app" "public_stats" "          " "$(bool "${WRITEFREELY_PUBLIC_STATS:-false}")"
	set_config_value "app" "private" "               " "$(bool "${WRITEFREELY_PRIVATE:-false}")"
	set_config_value "app" "local_timeline" "        " "$(bool "${WRITEFREELY_LOCAL_TIMELINE:-false}")"
}

wait_for_database() {
	until mysqladmin ping \
		--host="$db_host" \
		--port="$db_port" \
		--user="$db_user" \
		--password="$db_password" \
		--silent >/dev/null 2>&1; do
		echo "Waiting for MySQL at ${db_host}:${db_port}..."
		sleep 2
	done
}

write_config() {
	mkdir -p /data/keys
	cat > "$CONFIG_FILE" <<EOF
[server]
hidden_host          =
port                 = ${app_port}
bind                 = 0.0.0.0
tls_cert_path        =
tls_key_path         =
autocert             = false
templates_parent_dir =
static_parent_dir    =
pages_parent_dir     =
keys_parent_dir      = /data
hash_seed            = $(hash_seed)
gopher_port          = 0

[database]
type     = mysql
filename =
username = ${db_user}
password = ${db_password}
database = ${db_name}
host     = ${db_host}
port     = ${db_port}
tls      = false

[app]
site_name             = ${site_name}
site_description      =
host                  = ${site_host}
theme                 = write
editor                =
disable_js            = false
webfonts              = true
landing               =
simple_nav            = false
wf_modesty            = false
chorus                = false
forest                = false
disable_drafts        = false
single_user           = $(bool "${WRITEFREELY_SINGLE_USER:-false}")
open_registration     = $(bool "${WRITEFREELY_OPEN_REGISTRATION:-false}")
open_deletion         = false
min_username_len      = 3
max_blogs             = 5
federation            = $(bool "${WRITEFREELY_FEDERATION:-false}")
public_stats          = $(bool "${WRITEFREELY_PUBLIC_STATS:-false}")
monetization          = false
notes_only            = false
private               = $(bool "${WRITEFREELY_PRIVATE:-false}")
local_timeline        = $(bool "${WRITEFREELY_LOCAL_TIMELINE:-false}")
user_invites          =
default_visibility    =
update_checks         = false
disable_password_auth = false

[email]
domain          =
mailgun_private =

[oauth.slack]
client_id          =
client_secret      =
team_id            =
callback_proxy     =
callback_proxy_api =

[oauth.writeas]
client_id          =
client_secret      =
auth_location      =
token_location     =
inspect_location   =
callback_proxy     =
callback_proxy_api =

[oauth.gitlab]
client_id          =
client_secret      =
host               =
display_name       =
callback_proxy     =
callback_proxy_api =

[oauth.gitea]
client_id          =
client_secret      =
host               =
display_name       =
callback_proxy     =
callback_proxy_api =

[oauth.generic]
client_id          =
client_secret      =
host               =
display_name       =
callback_proxy     =
callback_proxy_api =
token_endpoint     =
inspect_endpoint   =
auth_endpoint      =
scope              =
allow_disconnect   = false
map_user_id        =
map_username       =
map_display_name   =
map_email          =
EOF
}

wait_for_database

if [ ! -x "$WRITEFREELY_BIN" ]; then
	echo "WriteFreely binary not found or not executable at ${WRITEFREELY_BIN}" >&2
	exit 127
fi

if [ ! -f "$CONFIG_FILE" ]; then
	echo "Creating WriteFreely config at ${CONFIG_FILE}"
	write_config
else
	echo "Updating WriteFreely config from environment"
	sync_env_config
fi

if [ ! -f "$INIT_MARKER" ]; then
	echo "Initializing WriteFreely database and keys"
	"$WRITEFREELY_BIN" -c "$CONFIG_FILE" db init || echo "Database init skipped or failed; continuing to migrations"
	"$WRITEFREELY_BIN" -c "$CONFIG_FILE" keys generate
	touch "$INIT_MARKER"
fi

echo "Running WriteFreely database migrations"
"$WRITEFREELY_BIN" -c "$CONFIG_FILE" db migrate

if [ -n "${WRITEFREELY_ADMIN_USER:-}" ] && [ -n "${WRITEFREELY_ADMIN_PASSWORD:-}" ] && [ ! -f "$ADMIN_MARKER" ]; then
	echo "Creating WriteFreely admin user ${WRITEFREELY_ADMIN_USER}"
	"$WRITEFREELY_BIN" -c "$CONFIG_FILE" user create --admin "${WRITEFREELY_ADMIN_USER}:${WRITEFREELY_ADMIN_PASSWORD}" || true
	touch "$ADMIN_MARKER"
fi

exec "$@"

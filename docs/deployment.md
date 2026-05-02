# VPS Deployment

This guide describes deploying WriteFreely Platform on a single Linux host with
Docker Compose, Caddy, MySQL, backups, and restore checks.

## Host Requirements

- A VPS or server with Docker Engine and Docker Compose installed.
- A domain name for the blog.
- Inbound TCP `80` and `443` open to the host.
- Inbound UDP `443` open when possible for HTTP/3.
- Enough disk space for Docker volumes and local backup retention.
- Optional: `rclone` configured for off-host backup sync.

## DNS

Create an `A` or `AAAA` record for the blog domain that points to the Docker
host.

Example:

```text
blog.example.com -> 203.0.113.10
```

Caddy can issue public HTTPS certificates only after DNS resolves to the host
and ports `80` and `443` are reachable.

## Initial Setup

Clone the repository on the host:

```sh
git clone <repo-url> writefreely-platform
cd writefreely-platform
```

Create the environment file with generated passwords:

```sh
make init
```

Edit `.env` and set the public domain values:

```env
CADDY_SITE_ADDRESS=blog.example.com
WRITEFREELY_HOST=https://blog.example.com
WRITEFREELY_SITE_NAME=MyBlog
```

Review the other knobs before first boot:

```env
WRITEFREELY_OPEN_REGISTRATION=false
WRITEFREELY_SINGLE_USER=false
WRITEFREELY_FEDERATION=false
WRITEFREELY_PUBLIC_STATS=false
```

Keep `.env` out of git. It contains database and admin credentials.

## Start The Stack

Start the services:

```sh
make up
```

Watch startup logs:

```sh
make logs
```

The first boot creates `/data/config.ini`, initializes the MySQL schema,
generates WriteFreely keys, runs migrations, and creates the configured admin
user.

Check service state:

```sh
make ps
```

Then open the configured `WRITEFREELY_HOST` in a browser.

## Local Runtime Verification

Run the disposable smoke test before changing production settings:

```sh
make smoke-test
```

The smoke test starts the stack with a separate Compose project name and test
ports, waits for HTTPS to respond, and tears down its test volumes afterward.

## Backups

Create a backup:

```sh
make backup
```

Each backup directory contains:

- `mysql.sql`
- `writefreely_data.tgz`
- `caddy_data.tgz`
- `manifest.txt`

Sync backups off-host with `rclone`:

```sh
make sync-backups BACKUP_REMOTE=remote:path
```

Examples:

```sh
make sync-backups BACKUP_REMOTE=s3:my-bucket/writefreely
make sync-backups BACKUP_REMOTE=b2:my-writefreely-backups
make sync-backups BACKUP_REMOTE=backup-server:/srv/backups/writefreely
```

Local backups are useful for fast recovery, but off-host copies are required
for host loss or disk failure.

## Restore Testing

Run an end-to-end restore check:

```sh
make restore-test
```

The restore test uses a separate Compose project name and ports. It boots a
disposable stack, creates a backup, deletes the test volumes, restores into
fresh volumes, waits for the site to respond, and tears the test stack down.

To keep the test stack for inspection:

```sh
RESTORE_TEST_KEEP_STACK=true make restore-test
```

## Upgrades

Before changing `WRITEFREELY_VERSION`, create and sync a backup:

```sh
make backup
make sync-backups BACKUP_REMOTE=remote:path
```

Then edit `.env`, rebuild, and restart:

```sh
make build
make up
make logs
```

See `docs/upgrade.md` for rollback steps.

## Operational Knobs

These settings are safe to tune through `.env` and are synced into the
WriteFreely config on container start:

- `WRITEFREELY_SITE_NAME`
- `WRITEFREELY_HOST`
- `WRITEFREELY_OPEN_REGISTRATION`
- `WRITEFREELY_SINGLE_USER`
- `WRITEFREELY_FEDERATION`
- `WRITEFREELY_PUBLIC_STATS`

Some settings affect how users discover and join the instance. Review them
before exposing the site publicly.

## Useful Commands

```sh
make config
make ps
make logs
make shell
make db-shell
make backup
make restore BACKUP=backups/<timestamp>
```

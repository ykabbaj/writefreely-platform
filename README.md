# writefreely-docker

This repository contains a Docker Compose deployment for running WriteFreely
behind Caddy with a MySQL database.

## What Is Here

- `docker-compose.yml` is the root Compose entrypoint for the local/standalone
  deployment.
- `docker/caddy/` contains the Caddy reverse proxy configuration.
- `docker/writefreely/` contains the custom WriteFreely image and startup
  entrypoint.
- `scripts/` contains backup and restore helpers.
- `docs/` contains production operations notes.
- `assets/themes/` contains WriteFreely custom CSS themes.

## Docker Compose

Copy the example environment file and change the passwords before exposing the
service anywhere public:

```sh
cp .env.example .env
docker compose up --build
```

For local testing, the default Caddy address is `https://localhost`. Caddy will
serve HTTPS with its local certificate authority, so your browser may warn until
you trust that CA or bypass the warning.

For a real domain, point DNS at the Docker host and set:

```env
CADDY_SITE_ADDRESS=blog.example.com
WRITEFREELY_HOST=https://blog.example.com
```

Then run:

```sh
docker compose up -d --build
```

Caddy can automatically obtain and renew public HTTPS certificates when the
domain resolves to the host and inbound ports `80` and `443` reach the Caddy
container.

The first start creates `/data/config.ini`, initializes the MySQL schema,
generates WriteFreely keys, and creates the admin user from
`WRITEFREELY_ADMIN_USER` / `WRITEFREELY_ADMIN_PASSWORD`.

Useful shortcuts:

```sh
make up
make logs
make backup
make sync-backups BACKUP_REMOTE=remote:path
make restore BACKUP=backups/20260502T120000Z
```

See `docs/production-checklist.md` before exposing the service publicly.
See `docs/upgrade.md` before changing WriteFreely versions, and
`docs/restore-test.md` for the restore verification procedure.

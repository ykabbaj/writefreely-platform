# Production Checklist

Use this checklist before exposing the Compose deployment to the public
internet.

## Domain And HTTPS

- Point the blog domain's `A` or `AAAA` record at the Docker host.
- Set `CADDY_SITE_ADDRESS` to the public domain, for example
  `blog.example.com`.
- Set `WRITEFREELY_HOST` to the canonical HTTPS URL, for example
  `https://blog.example.com`.
- Make sure inbound TCP `80` and `443` reach the Caddy container.
- Keep UDP `443` open when possible so Caddy can serve HTTP/3.
- Check Caddy logs after first boot to confirm certificate issuance.

## Secrets

- Copy `.env.example` to `.env`.
- Replace all default passwords before public use.
- Keep `.env` out of git.
- Use a long random `MYSQL_ROOT_PASSWORD`.
- Use a long random `MYSQL_PASSWORD`.
- Use a long random `WRITEFREELY_ADMIN_PASSWORD`.

## Operations

- Start the stack with `make up`.
- Watch logs with `make logs`.
- Check service state with `make ps`.
- Back up before upgrades with `make backup`.
- Test restores periodically on a non-production host.
- Review `docs/upgrade.md` before changing versions.
- Review `docs/restore-test.md` before testing disaster recovery.
- Review `docs/deployment.md` before the first VPS deployment.

## Backups

The backup script writes:

- `mysql.sql`
- `writefreely_data.tgz`
- `caddy_data.tgz`
- `manifest.txt`

Store copies away from the Docker host. The local `backups/` directory is useful
for immediate recovery, but it is not a disaster recovery plan by itself.

To sync local backups off-host with `rclone`, configure an rclone remote and
run:

```sh
make sync-backups BACKUP_REMOTE=remote:path
```

Examples:

```sh
make sync-backups BACKUP_REMOTE=b2:my-writefreely-backups
make sync-backups BACKUP_REMOTE=s3:my-bucket/writefreely
make sync-backups BACKUP_REMOTE=backup-server:/srv/backups/writefreely
```

## Upgrades

- Read the WriteFreely release notes before changing `WRITEFREELY_VERSION`.
- Run `make backup`.
- Change `WRITEFREELY_VERSION` in `.env`.
- Run `make build`.
- Run `make up`.
- Check logs and the site before removing older backups.

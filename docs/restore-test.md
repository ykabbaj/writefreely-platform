# Restore Test Procedure

Use this to prove that backups can rebuild the blog from empty Docker volumes.
The automated path runs against a disposable Compose project:

```sh
make restore-test
```

To test the published GHCR image instead of the local build definition:

```sh
WRITEFREELY_IMAGE=ghcr.io/ykabbaj/writefreely-platform:v0.1.0 make release-restore-test
```

Successful automated test backups are removed. Failed test backups are kept
under `backups/restore-test/` so the failed state can be inspected.

The manual procedure below is useful when testing a specific production backup
on a separate host.

## Create A Backup

```sh
make backup COMPOSE="sudo docker compose" DOCKER="sudo docker"
```

For a release-image deployment, use the matching release-aware target:

```sh
make release-backup
```

Record the generated directory, for example:

```text
backups/20260502T101131Z
```

## Recreate Volumes

This deletes the local Compose volumes for the project.

```sh
sudo docker compose down -v
sudo docker compose up -d
```

Wait until the services are running:

```sh
sudo docker compose ps
```

## Restore

```sh
make restore BACKUP=backups/<timestamp> COMPOSE="sudo docker compose" DOCKER="sudo docker"
```

For a release-image deployment, use the matching release-aware target so the
restored app starts from the published image:

```sh
make release-restore BACKUP=backups/<timestamp>
```

## Verify

- Existing users can log in.
- Existing posts and pages are present.
- The custom theme is still applied.
- Caddy starts without certificate or config errors.
- `make backup` still succeeds after the restore.

## Cleanup

If this was a disposable test environment, tear it down:

```sh
sudo docker compose down -v
```

# Upgrade Procedure

Use this process when changing `WRITEFREELY_VERSION`, `GO_VERSION`, or any
runtime dependency.

## Before Upgrading

1. Read the WriteFreely release notes for the target version.
2. Confirm the current stack is healthy:

   ```sh
   make ps
   ```

3. Create a backup:

   ```sh
   make backup DOCKER="sudo docker"
   ```

4. Sync the backup off-host if an rclone remote is configured:

   ```sh
   make sync-backups BACKUP_REMOTE=remote:path
   ```

## Upgrade Published Image

1. Update the image tag used by the deployment:

   ```sh
   WRITEFREELY_IMAGE=ghcr.io/ykabbaj/writefreely-platform:v0.1.0 make up
   ```

2. Watch logs until the app is healthy:

   ```sh
   make logs
   ```

3. Verify the site in a browser.

## Upgrade Local Image Build

1. Change `WRITEFREELY_VERSION` in `.env`, or `GO_VERSION` in
   `docker/writefreely/Dockerfile`.
2. Rebuild the app image:

   ```sh
   make dev-build
   ```

3. Recreate the services:

   ```sh
   make dev-up
   ```

4. Watch logs until the app is healthy:

   ```sh
   make logs
   ```

5. Verify the site in a browser.
6. Verify the container config:

   ```sh
   sudo docker compose exec writefreely grep -E 'host|site_name|open_registration' /data/config.ini
   ```

## Rollback

1. Set `WRITEFREELY_VERSION` back to the previous value in `.env`.
2. Rebuild and restart:

   ```sh
   make dev-build
   make dev-up
   ```

3. If the upgrade changed data in a bad way, restore the backup taken before
   the upgrade:

   ```sh
   make restore BACKUP=backups/<timestamp> DOCKER="sudo docker"
   ```

Keep the pre-upgrade backup until the upgraded site has run cleanly for a few
days.

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
   make backup COMPOSE="sudo docker compose" DOCKER="sudo docker"
   ```

4. Sync the backup off-host if an rclone remote is configured:

   ```sh
   make sync-backups BACKUP_REMOTE=remote:path
   ```

## Upgrade

1. Change `WRITEFREELY_VERSION` in `.env`, or `GO_VERSION` in
   `docker/writefreely/Dockerfile`.
2. Rebuild the app image:

   ```sh
   make build COMPOSE="sudo docker compose"
   ```

3. Recreate the services:

   ```sh
   make up COMPOSE="sudo docker compose"
   ```

4. Watch logs until the app is healthy:

   ```sh
   make logs COMPOSE="sudo docker compose"
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
   make build COMPOSE="sudo docker compose"
   make up COMPOSE="sudo docker compose"
   ```

3. If the upgrade changed data in a bad way, restore the backup taken before
   the upgrade:

   ```sh
   make restore BACKUP=backups/<timestamp> COMPOSE="sudo docker compose" DOCKER="sudo docker"
   ```

Keep the pre-upgrade backup until the upgraded site has run cleanly for a few
days.

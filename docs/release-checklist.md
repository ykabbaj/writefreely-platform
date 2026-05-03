## Release Checklist

Use this before tagging or pushing operational changes.

- Run the complete local release check:

  ```sh
  make release-check
  ```

- Run `docker compose config`.
- Run the release-image compose config:

  ```sh
  docker compose -f docker-compose.yml -f docker-compose.release.yml config
  ```

- Run shell syntax checks:

  ```sh
  sh -n docker/writefreely/entrypoint.sh
  sh -n scripts/init.sh
  sh -n scripts/backup.sh
  sh -n scripts/restore.sh
  sh -n scripts/restore-test.sh
  sh -n scripts/smoke-test.sh
  sh -n scripts/sync-backups.sh
  ```

- Run Make dry-runs:

  ```sh
  make -n init
  make -n backup
  make -n restore BACKUP=backups/example
  make -n restore-test
  make -n dev-build
  make -n dev-restore BACKUP=backups/example
  make -n dev-restore-test
  make -n smoke-test
  make -n sync-backups BACKUP_REMOTE=example:writefreely
  ```

- Run the runtime smoke test against the published image:

  ```sh
  make smoke-test
  ```

- Run local image checks before tagging source-build changes:

  ```sh
  make dev-smoke-test
  make dev-restore-test
  ```

- Confirm GitHub Actions passes on the pushed branch.
- For runtime changes, take a backup before deploying.
- For backup or restore changes, run the restore test procedure.

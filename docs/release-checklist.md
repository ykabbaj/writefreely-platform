# Release Checklist

Use this before tagging or pushing operational changes.

- Run the complete local release check:

  ```sh
  make release-check
  ```

- Run `docker compose config`.
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
  make -n smoke-test
  make -n sync-backups BACKUP_REMOTE=example:writefreely
  ```

- Run the runtime smoke test:

  ```sh
  make smoke-test
  ```

- Confirm GitHub Actions passes on the pushed branch.
- For runtime changes, take a backup before deploying.
- For backup or restore changes, run the restore test procedure.

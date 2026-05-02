# Release Checklist

Use this before tagging or pushing operational changes.

- Run `docker compose config`.
- Run shell syntax checks:

  ```sh
  sh -n docker/writefreely/entrypoint.sh
  sh -n scripts/backup.sh
  sh -n scripts/restore.sh
  sh -n scripts/sync-backups.sh
  ```

- Run Make dry-runs:

  ```sh
  make -n backup
  make -n restore BACKUP=backups/example
  make -n sync-backups BACKUP_REMOTE=example:writefreely
  ```

- Confirm GitHub Actions passes on the pushed branch.
- For runtime changes, take a backup before deploying.
- For backup or restore changes, run the restore test procedure.

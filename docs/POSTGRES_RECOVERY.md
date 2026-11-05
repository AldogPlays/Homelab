# PostgreSQL Backup and Recovery — TrueNAS Homelab

[Overview](../README.md) · [Backups and snapshots](backups.md) · [Operations](operations.md)

Use this runbook to select, check, and restore the PostgreSQL backups configured on November 4, 2026. Check container versions and backup availability before use. A full restore test has not yet been performed.

## Scope and schedules

- Host: `truenas` (TrueNAS SCALE), pool: `tank`.
- Logical backups: `/mnt/tank/backups/databases/<app>/<UTC_TIMESTAMP>/`.
- Backup task: TrueNAS Cron Job `PostgreSQL Database Backups`, daily at **03:15 America/Los_Angeles**.
- Retention task: TrueNAS Cron Job `PostgreSQL Backup Retention`, daily at **04:15 America/Los_Angeles**. Retains 30 days and always preserves at least the three newest complete sets per app.
- Both scripts use `/mnt/tank/backups/.postgres-backup.lock` to avoid overlapping runs.
- Backup script: `/mnt/tank/backups/bin/postgres-backup.sh`.
- Retention script: `/mnt/tank/backups/bin/postgres-retention.sh`.
- Versioned script sources: `/mnt/tank/stacks/scripts/`.
- **Local-only protection:** database dumps and ZFS snapshots are on `tank`; there is no offsite copy yet.
- **Restore test:** not yet performed. Archive/checksum checks do not prove a full restore will succeed.

## Databases

| App | Database container | PostgreSQL version at backup setup | Related application data |
| --- | --- | --- | --- |
| Nextcloud | `ix-nextcloud-postgres-1` | 17.11 | `tank/appdata/nextcloud`, `tank/data/files` |
| Immich | `ix-immich-pgvecto-1` | 18.4 with VectorChord 1.1.1 | `tank/appdata/immich`, `tank/data/photos` |
| Vaultwarden | `ix-vaultwarden-postgres-1` | 18.6 | `tank/appdata/vaultwarden` |
| Joplin | `ix-joplin-postgres-1` | 18.6 | `tank/appdata/joplin` |
| LubeLogger | `ix-lubelogger-postgres-1` | 18.6 | `tank/appdata/lubelogger` |

Confirm container image versions before a future restore. Immich requires an appropriate PostgreSQL image with its extension support; a plain PostgreSQL image may not be sufficient.

Each completed timestamped directory contains:

- `database.dump`: PostgreSQL custom-format archive (`pg_dump -Fc`).
- `globals.sql`: roles and other cluster-global objects (`pg_dumpall --globals-only`); **sensitive**—may contain password hashes.
- `SHA256SUMS`: checksums for the other two files.

Files are root-owned and protected by restrictive permissions. Keep them that way.

## Find a backup (read-only)

List completed backup directories:

```bash
sudo find /mnt/tank/backups/databases -mindepth 3 -maxdepth 3 \
  -type f -name SHA256SUMS -printf '%h\n' | sort
```

Choose the desired app and UTC timestamp. Example (replace with the actual path):

```bash
backup_set=/mnt/tank/backups/databases/nextcloud/20261105T002105Z
```

Check file integrity:

```bash
sudo bash -c 'cd -- "$1" && sha256sum -c SHA256SUMS' _ "$backup_set"
```

Both checksums must report `OK`. To inspect the archive without writing to any database:

```bash
sudo dd if="$backup_set/database.dump" status=none |
  sudo docker exec -i ix-nextcloud-postgres-1 pg_restore --list |
  sed -n '1,25p'
```

The `pg_restore --list` operation only displays the archive contents. Replace the PostgreSQL container with the matching app's container if inspecting another app's backup.

## Recovery procedure (deliberately manual)

1. **Identify the failure and recovery time.** Check the latest verified dump and the available ZFS snapshots. Determine whether application files must also be recovered.
2. **Preserve evidence.** Do not delete the existing database, overwrite application files, or roll back an entire parent dataset. Retain the damaged state until a recovery copy is available.
3. **Prepare a separate, empty PostgreSQL instance** using the appropriate major version and extensions. Verify its container name and isolation. Do not target a production database container while testing.
4. **Restore globals first, then the archive.** Run these commands only after setting `backup_set`, `restore_container`, and `restore_admin` to verified values for the separate target:

   ```bash
   # EXAMPLE: isolated target only — never point this at production casually.
   sudo dd if="$backup_set/globals.sql" status=none |
     sudo docker exec -i "$restore_container" \
       psql -X -v ON_ERROR_STOP=1 -U "$restore_admin" -d postgres

   sudo dd if="$backup_set/database.dump" status=none |
     sudo docker exec -i "$restore_container" \
       pg_restore --create --exit-on-error -U "$restore_admin" -d postgres
   ```

   The restored database name comes from the archive. Restoring globals can encounter role-name conflicts in a nonempty target; investigate rather than bypassing errors. For a database-only recovery where ownership/roles differ, design an explicit alternative before executing.

5. **Validate the restored database.** Check that the expected database, tables, and records exist. Where practical, start a disposable application instance against the restored copy and verify actual functionality.
6. **Recover application files only if needed.** Use TrueNAS **Datasets → Snapshots** to inspect or clone the relevant *child* dataset (`tank/data/files`, `tank/data/photos`, or the affected app's dataset). Align file timestamps with the database backup to avoid inconsistent application state. Prefer copying required files from a snapshot/clone rather than rolling back `tank/data` or `tank/appdata` wholesale.
7. **Plan production cutover separately.** Stop the affected app, confirm a current safety copy, and use a reviewed application-specific procedure to replace its data. Then restart and validate the app. Preserve the previous state until successful.

## Follow-up checks

- Confirm the unattended 03:15 backup creates new timestamped sets and verify one with `sha256sum -c`.
- Confirm the 04:15 retention task remains enabled; the retention script supports `--dry-run` for inspection.
- Review disk use with `sudo zfs list -r tank/backups`.
- Configure TrueNAS alert email and verify delivery. Keep Cron Job **Hide Standard Error** unchecked.
- Add a snapshot policy for `tank/backups` if desired; remember that snapshots retain deleted files until the snapshots expire.
- Arrange an offsite copy of the backups and necessary application data, then test a complete recovery.

## References

- PostgreSQL: https://www.postgresql.org/docs/18/app-pgrestore.html
- PostgreSQL `psql` error handling: https://www.postgresql.org/docs/18/app-psql.html
- TrueNAS snapshot management: https://www.truenas.com/docs/scale/26/datasets/snapshots/managesnapshots/

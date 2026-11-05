# PostgreSQL recovery

> [Overview](../README.md) · [Backups and snapshots](backups.md) · [Operations](operations.md)

Use this runbook to select, check, and restore the PostgreSQL backups configured on November 4, 2026. Check container versions and backup availability before use. A full restore test has not yet been performed.

## Before starting

Run the inspection commands on the **TrueNAS host**. Completed sets live at `/mnt/tank/backups/databases/<app>/<UTC_TIMESTAMP>/`. [Backups and snapshots](backups.md) is the reference for schedules, retention, installed scripts, and coverage.

Database recovery also needs compatible PostgreSQL versions/extensions, application files, and required external configuration. Use a separate empty database instance for the restore test; preserve production state until validation and a deliberate cutover.

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

## Record the recovery result

- Record the selected backup timestamp, checksum/archive results, and target PostgreSQL version/extensions.
- Record application-level validation and any required file recovery, without including credentials or private records.
- Update [backup verification status](backups.md#protection-at-a-glance) after a successful test; remaining protection work belongs in the [roadmap](roadmap.md#recovery-verification-and-independent-backups).

## References

- [PostgreSQL `pg_restore`](https://www.postgresql.org/docs/18/app-pgrestore.html)
- [PostgreSQL `psql` error handling](https://www.postgresql.org/docs/18/app-psql.html)
- [TrueNAS snapshot management](https://www.truenas.com/docs/scale/26/datasets/snapshots/managesnapshots/)

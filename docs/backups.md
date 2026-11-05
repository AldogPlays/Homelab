# Backups and snapshots

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Database recovery](POSTGRES_RECOVERY.md) · [Roadmap](roadmap.md)

Snapshot policies and daily PostgreSQL backup/retention jobs were configured on November 4, 2026. Some execution timestamps fall on November 5 UTC. Initial snapshots and a manual database backup succeeded; unattended execution and pruning still need verification.

Protection is local to `tank`: ZFS snapshots preserve filesystem history, and logical PostgreSQL exports provide database backup archives. Neither supplies an independent copy if the entire pool or host is lost. Email alerts, an offsite copy, and a full restore test are not yet in place.

## Snapshot policy

Ten enabled tasks use `auto-%Y-%m-%d_%H-%M` naming, recursive snapshots, and `allow_empty: true`. Schedules below follow the TrueNAS local timezone, America/Los_Angeles.

| Dataset scope | Schedule | Retention |
| --- | --- | --- |
| `tank/appdata`, including its app datasets | Hourly, minute 0 | 2 days |
| Same | Daily, midnight | 30 days |
| Same | Sunday, midnight | 8 weeks |
| `tank/data`, excluding `tank/data/media` and `tank/data/games` | Hourly, minute 0 | 2 days |
| Same exclusions | Daily, midnight | 30 days |
| Same exclusions | Sunday, midnight | 12 weeks |
| Same exclusions | First day of month, midnight | 12 months |
| `tank/data/media` | Daily, midnight | 14 days |
| `tank/stacks` | Daily, midnight | 30 days |
| `tank/stacks` | First day of month, midnight | 12 months |

The first hourly execution created snapshots of `appdata` and its app datasets, plus `data`, `files`, and `photos`, at 15:00 on November 4. Daily, weekly, and monthly execution still need checking. A newly created snapshot can show `USED 0B` before changes cause it to retain blocks; this does not mean the source dataset is empty.

The ten-task policy excludes `tank/data/games` and does not cover `tank/backups`. Crafty server content lives under `tank/appdata/crafty-4`, covered by the appdata policy. An optional daily snapshot of `tank/backups` around 04:30 with seven-day retention remains a proposal.

## PostgreSQL logical backups

The [backup script](../scripts/postgres-backup.sh) covers Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. The [recovery runbook](POSTGRES_RECOVERY.md) lists containers, version requirements, integrity checks, and the manual restore procedure.

| Item | Configuration |
| --- | --- |
| Backup command | `/mnt/tank/backups/bin/postgres-backup.sh` |
| Backup schedule | Daily, 03:15, as root |
| Retention command | `/mnt/tank/backups/bin/postgres-retention.sh --delete` |
| Retention schedule | Daily, 04:15, as root |
| Versioned sources | Repository `scripts/` directory |
| Backup root | `/mnt/tank/backups/databases` |
| Shared lock | `/mnt/tank/backups/.postgres-backup.lock` |
| Protected directories | Root-owned, mode `700` |
| Installed operational scripts | Root-owned, mode `700` |

The jobs invoke protected installed copies of the scripts. Editing the versioned source does not itself update those copies or change the TrueNAS cron configuration.

Each completed set has this layout:

```text
/mnt/tank/backups/databases/<app>/<YYYYMMDDTHHMMSSZ>/
├── database.dump
├── globals.sql
└── SHA256SUMS
```

`database.dump` is a custom-format `pg_dump -Fc` archive. `globals.sql` contains PostgreSQL global objects and can include sensitive role password hashes. The script creates the files privately, renders the archive through `pg_restore -f /dev/null`, generates and checks hashes, then publishes the completed temporary directory by rename. Archive rendering and hashes do not prove that a full application restore will succeed.

A manual run successfully produced all five sets at `20261105T002105Z` (November 4 afternoon in Pacific time). The backup and retention cron jobs are enabled; their unattended execution still needs checking.

## Retention

The [retention script](../scripts/postgres-retention.sh) targets completed timestamped directories older than 30 days, preserving at least the three newest structurally complete sets per app. It checks for exactly the three expected nonempty regular files and rejects symlinks or extra entries. It does not recompute hashes when choosing sets to retain or delete.

Dry run is the default; deletion requires `--delete`. Manual dump files, pre-migration archives, hidden partial directories, and other names are outside its timestamp-directory selection. The initial dry run found zero eligible sets. Deletion of an expired set has not yet been tested.

Snapshots of a backup dataset, if added later, can retain blocks after the retention script removes files. Account for both policies when assessing storage use.

## Check the setup

Run on the **TrueNAS host**. These queries read policy/state without changing it:

```bash
sudo midclt call pool.snapshottask.query | jq \
  '[.[] | {dataset,recursive,exclude,lifetime_value,lifetime_unit,enabled,schedule}]'

sudo zfs list -t snapshot -r -o name,creation,used \
  tank/appdata tank/data tank/stacks

sudo midclt call cronjob.query | jq \
  '[.[] | select(.description == "PostgreSQL Database Backups" or
                .description == "PostgreSQL Backup Retention") |
    {description,enabled,user,schedule}]'

sudo find /mnt/tank/backups/databases -mindepth 3 -maxdepth 3 \
  -type f -name SHA256SUMS -printf '%h\n' | sort
```

Use the [runbook's checksum and archive checks](POSTGRES_RECOVERY.md#find-a-backup-read-only) on a selected set. A backup-directory listing alone does not prove integrity or execution by cron.

## Follow-up verification

- Verify an unattended backup run and a retention run with expired candidates.
- Test a full isolated database restore and application-level recovery.
- Create offsite copies or replication of backups and required application/user data.
- Configure and test TrueNAS alert-email delivery. Keeping cron stderr visible alone does not establish notification delivery.
- Decide whether to add a snapshot policy for `tank/backups`.

The initial manual backup and policy setup are complete; these checks follow as the new schedules run. Recovery requires the appropriate database version/extensions and the related files and secrets; a database dump alone does not reconstruct the entire service.

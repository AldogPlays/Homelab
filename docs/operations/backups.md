# Backups and snapshots

> [Homelab](../../README.md) · [Documentation](../README.md) · [Roadmap](../roadmap.md)

The lab has two forms of local recovery:

- **ZFS snapshots** preserve filesystem state at a point in time, providing earlier versions of files.
- **PostgreSQL exports** are archives of database contents that PostgreSQL tools can restore into a database instance.

The policies were configured on November 4, 2026; some execution timestamps fall on November 5 UTC.

> [!IMPORTANT]
> Both are stored locally on `tank`. Neither provides a copy that survives loss of that pool.

**On this page:** [Coverage](#protection-at-a-glance) · [Snapshots](#snapshot-policy) · [Database exports](#postgresql-logical-backups) · [Retention](#retention) · [Verification](#check-the-setup)

## Protection at a glance

| Layer | Purpose | Verification status |
| --- | --- | --- |
| Mirrored data drives | Survive a single data-drive failure | Configured; does not provide file history or an independent copy |
| ZFS snapshots | Recover earlier filesystem state | First hourly snapshots observed; later schedules need checking |
| PostgreSQL exports | Recover application databases | Manual run produced all five sets; unattended execution and expired-set pruning need checking |
| Independent backup | Recover after loss of the pool or host | No offsite copy yet |

A full restore test and email alerts are still outstanding. Use the [recovery runbook](postgres-recovery.md) to inspect or restore a database set, and the [roadmap](../roadmap.md#recovery-verification-and-independent-backups) for remaining recovery work.

## Snapshot policy

Ten enabled tasks cover application state, selected user data, media, and repository history. All schedules use the TrueNAS local timezone, America/Los_Angeles.

### Application state

**Scope:** `tank/appdata`, including its app datasets.

| Schedule | Retention |
| --- | --- |
| Hourly, minute 0 | 2 days |
| Daily, midnight | 30 days |
| Sunday, midnight | 8 weeks |

### User data

**Scope:** `tank/data`, excluding `tank/data/media` and `tank/data/games` from every schedule below.

| Schedule | Retention |
| --- | --- |
| Hourly, minute 0 | 2 days |
| Daily, midnight | 30 days |
| Sunday, midnight | 12 weeks |
| First day of month, midnight | 12 months |

### Media and repository history

| Dataset scope | Schedule | Retention |
| --- | --- | --- |
| `tank/data/media` | Daily, midnight | 14 days |
| `tank/stacks` | Daily, midnight | 30 days |
| `tank/stacks` | First day of month, midnight | 12 months |

### Task behavior and verification

Tasks use `auto-%Y-%m-%d_%H-%M` naming, recursive snapshots, and `allow_empty: true`. Recursive tasks include child datasets except the listed exclusions. Retention is how long each task keeps its snapshots; it is separate from the database-export retention policy below.

The first hourly execution created snapshots of `appdata` and its app datasets, plus `data`, `files`, and `photos`, at 15:00 on November 4. Daily, weekly, and monthly execution still need checking.

A newly created snapshot can show `USED 0B` before changes cause it to retain blocks; this does not mean the source dataset is empty.

### Coverage gaps

The policy excludes `tank/data/games` and does not cover `tank/backups`. Crafty server content lives in appdata and is covered there. A daily backup-dataset snapshot with seven-day retention is an option under consideration, not an enabled task.

## PostgreSQL logical backups

The [backup script](../../scripts/postgres-backup.sh) covers Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. The [recovery runbook](postgres-recovery.md) lists containers, version requirements, integrity checks, and the manual restore procedure.

| Item | Configuration |
| --- | --- |
| Backup command | `/mnt/tank/backups/bin/postgres-backup.sh` |
| Backup schedule | Daily, 03:15, as root |
| Retention command | `/mnt/tank/backups/bin/postgres-retention.sh --delete` |
| Retention schedule | Daily, 04:15, as root |
| Versioned sources | Repository `scripts/` directory |
| Backup root | `/mnt/tank/backups/databases` |
| Protected directories | Root-owned, mode `700` |
| Installed operational scripts | Root-owned, mode `700` |

The jobs share a lock to prevent overlapping backup and retention runs. They invoke protected installed copies of the scripts. Editing the versioned source does not itself update those copies or change the TrueNAS cron configuration.

### Archive layout and validation

Each completed set has this layout:

```text
/mnt/tank/backups/databases/<app>/<YYYYMMDDTHHMMSSZ>/
├── database.dump
├── globals.sql
└── SHA256SUMS
```

`database.dump` is a custom-format `pg_dump -Fc` archive. `globals.sql` contains PostgreSQL global objects and can include sensitive role password hashes.

Before marking a set complete, the script:

1. Creates the files privately.
2. Reads and converts the archive through `pg_restore -f /dev/null`, discarding the generated SQL.
3. Generates and checks hashes.
4. Renames the temporary directory to its completed timestamped name.

Reading the archive and checking hashes do not prove that a full application restore will succeed.

### Execution status

A manual run successfully produced all five sets at `20261105T002105Z` (November 4 afternoon in Pacific time). The backup and retention cron jobs are enabled; their unattended execution still needs checking.

## Retention

The [retention script](../../scripts/postgres-retention.sh) follows these rules:

| Rule | Behavior |
| --- | --- |
| Age | Targets completed timestamped directories older than 30 days |
| Minimum history | Preserves at least the three newest structurally complete sets per app |
| File structure | Requires exactly the three expected nonempty regular files; rejects symlinks and extra entries |
| Integrity | Does not recompute hashes when choosing sets to retain or delete |

Here, structurally complete means the expected files are present. It does not mean the database has passed a restore test.

Dry run is the default; deletion requires `--delete`. Manual dump files, pre-migration archives, hidden partial directories, and other names are outside its timestamp-directory selection.

**Verification status:** The initial dry run found zero eligible sets. Deletion of an expired set has not yet been tested.

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

Use the [runbook's checksum and archive checks](postgres-recovery.md#find-a-backup-read-only) on a selected set. A backup-directory listing alone does not prove integrity or execution by cron.

Recovery also requires compatible database versions/extensions and the related application files and credentials. A database dump alone does not reconstruct the entire service. Record new verification results here and keep remaining work in the [roadmap](../roadmap.md#recovery-verification-and-independent-backups).

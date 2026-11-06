# Backups and snapshots

> [Homelab](../../README.md) · [Documentation](../README.md)

I use two kinds of local recovery:

- **ZFS snapshots** preserve filesystem state at a point in time, providing earlier versions of files.
- **PostgreSQL exports** are archives of database contents that PostgreSQL tools can restore into a database instance.

I set these up on November 4, 2026. Some execution timestamps fall on November 5 UTC.

> [!IMPORTANT]
> Both are stored locally on `tank`. Neither provides a copy that survives loss of that pool.

## Protection at a glance

| Layer | Purpose | Verification status |
| --- | --- | --- |
| Mirrored data drives | Survive a single data-drive failure | Configured; does not provide file history or an independent copy |
| ZFS snapshots | Recover earlier filesystem state | First hourly snapshots observed; daily, weekly, and monthly runs unverified |
| PostgreSQL exports | Recover application databases | Manual run produced all five sets; unattended execution and expired-set pruning unverified |
| Independent backup | Recover after loss of the pool or host | No offsite copy |

I haven't completed a full restore test or configured email alerts. The [recovery notes](postgres-recovery.md) cover inspecting a backup and restoring it into a separate test instance.

## Snapshot policy

I have ten enabled snapshot tasks covering app state, selected user data, media, and the repository. They all use the TrueNAS local timezone, America/Los_Angeles.

<details>
<summary>Snapshot schedules and settings</summary>

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

The first hourly execution created snapshots of `appdata` and its app datasets, plus `data`, `files`, and `photos`, at 15:00 on November 4. I haven't verified daily, weekly, or monthly execution.

A newly created snapshot can show `USED 0B` before changes cause it to retain blocks; this does not mean the source dataset is empty.

</details>

### Coverage gaps

The policy excludes `tank/data/games` and does not cover `tank/backups`. Crafty server content lives in appdata and is covered there.

## PostgreSQL logical backups

My [backup script](../../scripts/postgres-backup.sh) exports the databases for Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. The [recovery notes](postgres-recovery.md) list the containers, version requirements, integrity checks, and manual restore procedure. These exports can contain sensitive role password hashes.

<details>
<summary>Database backup jobs and archive format</summary>

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

</details>

### Execution status

My manual run produced all five sets at `20261105T002105Z` (November 4 afternoon in Pacific time). The backup and retention cron jobs are enabled, but I haven't verified their unattended execution.

## Retention

My [retention script](../../scripts/postgres-retention.sh) targets completed sets older than 30 days while keeping at least the three newest structurally complete sets per app. It defaults to a dry run; deletion requires `--delete`.

<details>
<summary>Retention rules and exclusions</summary>

| Rule | Behavior |
| --- | --- |
| Age | Targets completed timestamped directories older than 30 days |
| Minimum history | Preserves at least the three newest structurally complete sets per app |
| File structure | Requires exactly the three expected nonempty regular files; rejects symlinks and extra entries |
| Integrity | Does not recompute hashes when choosing sets to retain or delete |

Here, structurally complete means the expected files are present. It does not mean the database has passed a restore test.

Dry run is the default; deletion requires `--delete`. Manual dump files, pre-migration archives, hidden partial directories, and other names are outside its timestamp-directory selection.

</details>

**Verification status:** The initial dry run found zero eligible sets. Deletion of an expired set has not yet been tested.

Snapshots can retain blocks after files are removed, so snapshot retention and file retention have to be accounted for separately when assessing storage use. This policy does not snapshot the backup dataset.

## Check the setup

The first manual backup and hourly snapshots worked. I haven't checksum-checked a newly scheduled backup set or tested expired-set deletion. A directory listing alone doesn't prove a backup is intact or that cron ran it.

<details>
<summary>Read-only commands and verification notes</summary>

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

Recovery also requires compatible database versions/extensions and the related application files and credentials. A database dump alone does not reconstruct the entire service. An independent recovery copy needs the necessary databases, files, secrets, and CA state, with recovery tested from that copy. I keep verification results here. For email-alert checks, keep cron stderr visible and verify actual delivery; configured alerts alone would not prove that messages arrive.

</details>

# Backups and snapshots

> [Homelab](../README.md)

I use two kinds of local recovery:

- **ZFS snapshots** preserve filesystem state at a point in time, providing earlier versions of files.
- **PostgreSQL exports** are archives of database contents that PostgreSQL tools can restore into a database instance.

I set up snapshots and PostgreSQL backups on November 4, 2026, then added retention during the November 4–5 work. Schedules use America/Los_Angeles; backup-directory timestamps ending in `Z` use UTC.

> [!IMPORTANT]
> Both are stored locally on `tank`. Neither provides a copy that survives loss of that pool.

## Protection at a glance

| Layer | Purpose | Verification status |
| --- | --- | --- |
| Mirrored data drives | Survive a single data-drive failure | Configured; does not provide file history or an independent copy |
| ZFS snapshots | Recover earlier filesystem state | I checked the first hourly snapshots; daily, weekly, and monthly runs still need checking |
| PostgreSQL exports | Recover application databases | My manual run produced all five sets; I haven’t checked unattended runs or expired-set pruning |
| Independent backup | Recover after loss of the pool or host | No offsite copy |

I put off the full restore test and didn’t deploy the temporary test app. I haven’t tested email alerts. The [recovery notes](postgres-recovery.md) cover inspecting a backup and restoring it into a separate test instance.

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

The policy excludes `tank/data/games` and does not cover `tank/backups`. Crafty server content lives in appdata and is covered there. I considered a daily 04:30 snapshot of the backup dataset with seven-day retention, but I haven’t verified that it is enabled.

## PostgreSQL logical backups

My [backup script](../scripts/postgres-backup.sh) exports the databases for Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. The [recovery notes](postgres-recovery.md) list the containers, version requirements, integrity checks, and manual restore procedure. These exports can contain sensitive role password hashes.

<details>
<summary>Database backup jobs and archive format</summary>

| Item | Configuration |
| --- | --- |
| Backup command | `/mnt/tank/backups/bin/postgres-backup.sh` |
| Backup schedule | Daily, 03:15, as root |
| Backup cron job | ID `2`, `PostgreSQL Database Backups` |
| Retention command | `/mnt/tank/backups/bin/postgres-retention.sh --delete` |
| Retention schedule | Daily, 04:15, as root |
| Retention cron job | ID `3`, `PostgreSQL Backup Retention` |
| Cron output settings | Hide stdout; leave stderr visible |
| Versioned sources | Repository `scripts/` directory |
| Backup root | `/mnt/tank/backups/databases` |
| Protected directories | Root-owned, mode `700` |
| Installed operational scripts | Root-owned, mode `700` |

The jobs share `/mnt/tank/backups/.postgres-backup.lock` to prevent overlapping backup and retention runs. They invoke protected installed copies of the scripts. Editing the versioned source does not itself update those copies or change the TrueNAS cron configuration.

In TrueNAS, `stdout: true` and `stderr: false` are **suppression flags**: stdout is hidden and stderr is not hidden. These settings do not prove that failure email is configured or delivered.

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

My manual five-app run succeeded, and I enabled both cron jobs. I haven’t verified unattended execution.

<details>
<summary>What I checked and the one-off backups I kept</summary>

Here’s what I checked during setup:

| Check | What I got | What I still need to test |
| --- | --- | --- |
| Initial Nextcloud export, November 4 at 15:44 Pacific | `manual-20261104-154425.dump`, about 3.8 MiB; export and archive rendering exited `0` | One database archive, outside the three-file set format |
| Five-app manual backup run | All five sets succeeded at `20261105T002105Z` (November 4, 16:21:05 Pacific), including archive rendering and checksum checks | No full database or application restore |
| Backup and retention schedules | Both enabled in middleware; retention command included `--delete` | I haven’t checked an unattended run |
| Initial retention dry run | `Finished: --dry-run; eligible backup sets: 0` | No expired-set deletion exercised |

I also found one-off migration archives under appdata: `immich/backups/pre-migration.sql.gz`, `nextcloud/backups/pre-migration.dump`, `nextcloud/backups/cutover-20261103-090936.dump`, and `vaultwarden/backups/pre-migration.dump`. These and my manual Nextcloud dump sit outside daily retention. I need to check that they are still present and intact before relying on them.

</details>

## Retention

My [retention script](../scripts/postgres-retention.sh) targets completed sets older than 30 days while keeping at least the three newest structurally complete sets per app. It defaults to a dry run; deletion requires `--delete`.

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
    {id,description,command,enabled,user,schedule,stdout,stderr}]'

sudo find /mnt/tank/backups/databases -mindepth 3 -maxdepth 3 \
  -type f -name SHA256SUMS -printf '%h\n' | sort
```

Use the [runbook's checksum and archive checks](postgres-recovery.md#find-a-backup-read-only) on a selected set. A backup-directory listing alone does not prove integrity or execution by cron.

I installed and ran the scripts, but haven’t compared the installed retention copy byte for byte with its source. I can compare both source/install pairs without executing either script:

```bash
# TrueNAS host
sudo sha256sum /mnt/tank/stacks/scripts/postgres-backup.sh \
  /mnt/tank/backups/bin/postgres-backup.sh
sudo sha256sum /mnt/tank/stacks/scripts/postgres-retention.sh \
  /mnt/tank/backups/bin/postgres-retention.sh
```

Each source/install pair should match if the installed copy is current. A mismatch calls for reviewing the differences before a separate deployment change.

Recovery also requires compatible database versions/extensions and the related application files and credentials. A database dump alone does not reconstruct the entire service. An independent recovery copy needs the necessary databases, files, secrets, and CA state, with recovery tested from that copy. I keep verification results here. For email-alert checks, keep cron stderr visible and verify actual delivery; configured alerts alone would not prove that messages arrive.

</details>

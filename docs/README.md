# My homelab notes

> [Homelab](../README.md)

These are my notes on the hardware, apps, and maintenance behind the lab. They cover what I've recorded through November 4, 2026 Pacific time (November 5 UTC), rather than a fresh check of every running service.

| What I'm looking for | Notes |
| --- | --- |
| Hardware, storage, and paths | [Infrastructure](setup/infrastructure.md) |
| Networks, DNS, HTTPS, and remote access | [Networking](setup/networking.md) |
| Apps, dependencies, clients, and media storage | [Services](setup/services.md) |
| Open WebUI, Strata, and the AI host | [Local AI](setup/local-ai.md) |
| AI timings, test limits, and the benchmark command | [Q2_0 benchmark](benchmarks/q2-0.md) |
| Shell contexts, app inspection, deployment, and Git | [Operations](operations/README.md) |
| Problems I've run into and how I checked them | [Troubleshooting](operations/troubleshooting.md) |
| Snapshot schedules, database backups, and retention | [Backups](operations/backups.md) |
| Selecting, checking, and restoring a database backup | [PostgreSQL recovery](operations/postgres-recovery.md) |
| Hardware reuse, subscriptions, and other choices | [Decisions and lessons](history/decisions-and-lessons.md) |
| Completed migrations and what I kept or discarded | [Migration history](history/migrations.md) |

For a first look, I'd start with infrastructure, networking, and services. For recovery, read the backup coverage before using the PostgreSQL recovery notes. My snapshots and database exports are both on `tank`; I don't have an offsite copy.

<details>
<summary>About these notes</summary>

I keep the current setup in the setup guides, procedures in operations, and completed changes in history. The benchmark page holds the single recorded performance baseline. I link to those pages instead of maintaining separate copies of the same details.

The Compose files are the reference for image versions, ports, mounts, and service identities. The [Caddyfile](../caddy/Caddyfile) defines web names and proxy destinations. Runtime settings also affect application behavior. Prometheus's full Strata definition lives on that host, outside this repository.

I keep verification limits and unresolved causes alongside the relevant details. When updating these notes, I record what was actually checked, keep useful incident history, and check links if a page moves.

Commands say where they run. Read the warnings and replace example values before using them. Credentials, private keys, application state, and user data stay outside these notes and Git.

</details>

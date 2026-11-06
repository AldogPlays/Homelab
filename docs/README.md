# Documentation

> [Homelab](../README.md) · [Roadmap](roadmap.md)

These are my notes on how the lab fits together, how I maintain it, and what I learned along the way. For a first look, read infrastructure, networking, and services in that order. For a specific job, use the tables below.

The recorded state runs through November 4, 2026 Pacific time (November 5 UTC). A setting recorded here is not a fresh check of the running service. Each guide keeps its verification limits beside the relevant details.

## Understand the setup

| Guide | What it covers |
| --- | --- |
| [Infrastructure](setup/infrastructure.md) | Hardware, storage roles, ZFS datasets, and host/container paths |
| [Networking and access](setup/networking.md) | Network segments, addresses, local DNS, private HTTPS, and WireGuard |
| [Services and clients](setup/services.md) | All 15 Compose stacks, dependencies, everyday clients, media storage, and the download VPN |
| [Local AI](setup/local-ai.md) | Open WebUI and Strata, model settings, runtime paths, and startup |
| [Q2_0 standard benchmark](benchmarks/q2-0.md) | Timing definitions, measured results, test limits, provenance, and the repeat-run command |

## Maintain and recover

| Guide | What it covers |
| --- | --- |
| [Operations](operations/README.md) | Shell contexts, routine inspection, the deployment workflow, and Git authentication |
| [Troubleshooting](operations/troubleshooting.md) | Caddy configuration visibility, interrupted copies, permissions, Prometheus connectivity, and delayed WebUI replies |
| [Backups and snapshots](operations/backups.md) | Protection coverage, schedules, retention, and verification status |
| [PostgreSQL recovery](operations/postgres-recovery.md) | Backup selection, integrity checks, an isolated restore, and application validation |

For a recovery, read the coverage and limits in **Backups and snapshots**, then follow **PostgreSQL recovery** for a database restore. Both local snapshots and database exports live on `tank`; there is no offsite copy yet.

## Decisions, history, and next steps

| Guide | What it covers |
| --- | --- |
| [Decisions and lessons](history/decisions-and-lessons.md) | Hardware reuse, storage and deployment choices, subscriptions replaced, and maintenance lessons |
| [Migration history](history/migrations.md) | Completed cutovers, what was retained or discarded, observed outcomes, and unresolved causes |
| [Roadmap](roadmap.md) | Outstanding checks and planned improvements, starting with recovery verification |

## Keeping these notes useful

I keep current setup details in the setup guides, procedures in operations, completed changes in history, and unfinished work in the roadmap. The benchmark page holds the single recorded performance baseline. Short summaries elsewhere link back to those details.

Compose files remain the reference for image versions, ports, mounts, and service identities; the [Caddyfile](../caddy/Caddyfile) defines web names and proxy destinations. Runtime settings can also affect application behavior. Prometheus's full Strata deployment definition lives on that host, outside this repository.

When something changes, update its main guide and record what was actually checked. Keep assumptions, suspected causes, and future plans explicit. Preserve useful incident history even after the service works again, and check links when moving a page.

Commands state where they run. Read their surrounding warnings and replace example values before use. Credentials, private keys, application state, and user data stay outside these notes and Git.

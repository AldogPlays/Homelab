# Operations

> [Homelab](../../README.md) · [Documentation](../README.md) · [Roadmap](../roadmap.md)

This is my starting point for routine inspection and authorized deployment work. The task table also links to focused troubleshooting procedures. Commands identify where they run; check container names against the current deployment before using an example.

## Start here

| Task or symptom | Procedure |
| --- | --- |
| Find a file in the right shell | [Host and container paths](#find-the-right-path) |
| Check an app's status, mounts, or configuration | [Inspect a TrueNAS app](#inspect-a-truenas-app) |
| Prepare and deploy a change | [Deployment workflow](#deployment-workflow) |
| Caddy cannot see an edited route | [Compare host and container files](troubleshooting.md#caddy-route-present-on-host-but-missing-in-container) |
| A long media transfer stopped | [Interrupted media copy](troubleshooting.md#interrupted-media-copy) |
| An application cannot access its files | [Storage permissions](troubleshooting.md#storage-permissions) |
| Git authentication fails | [Git authentication](#git-authentication) |
| Strata is healthy but its API is unreachable | [Prometheus diagnostics](troubleshooting.md#prometheus-healthy-container-unreachable-api) |
| Open WebUI shows replies late | [Compare backend and browser timing](troubleshooting.md#open-webui-replies-appear-late) |
| Recover a database | [PostgreSQL recovery](postgres-recovery.md) |

Use [backups](backups.md#check-the-setup) to check protection jobs and [networking](../setup/networking.md) for the address/DNS reference.

## Find the right path

| Context | Repository | Application state |
| --- | --- | --- |
| TrueNAS host | `/mnt/tank/stacks` | `/mnt/tank/appdata/<app>` |
| code-server | `/workspace` | Its own persistent state is `/config` |
| Caddy container | Caddyfile at `/etc/caddy/Caddyfile` | `/data` and `/config` |
| Prometheus AI host | Strata Compose at `/srv/ai/strata/compose.yaml` | `/srv/ai/strata/data` |

A host path and a container path can name the same underlying files differently. For example, `/mnt/tank/stacks/caddy/Caddyfile` on TrueNAS appears as `/workspace/caddy/Caddyfile` in code-server and `/etc/caddy/Caddyfile` in Caddy.

`/workspace` is a code-server mount, not a TrueNAS host path. A missing path in the wrong shell does not establish that the host file is missing.

## Inspect a TrueNAS app

Run these commands on the **TrueNAS host**, replacing the example app/container names as appropriate:

```bash
sudo docker ps --filter name=ix-navidrome \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

sudo docker inspect ix-navidrome-navidrome-1 \
  --format 'Image: {{.Config.Image}} | User: {{.Config.User}}'

sudo docker inspect ix-navidrome-navidrome-1 \
  --format '{{range .Mounts}}{{println .Source " -> " .Destination}}{{end}}'

sudo docker compose -f /mnt/tank/stacks/navidrome/compose.yaml config --quiet
```

These inspect status, selected metadata, mounts, and Compose validity. They do not deploy the source file. Avoid sharing full environment dumps or unreviewed request logs, which can include credentials or session tokens.

## Deployment workflow

Apps are deployed through TrueNAS **Apps → Install via YAML** with an on-disk include:

```yaml
include:
  - path: /mnt/tank/stacks/<app>/compose.yaml
```

The placeholder must be replaced with the app directory. Keep app directories at their established repository paths so includes continue to resolve.

Documentation work does not authorize deployment changes. Changes to Compose, Dockerfiles, Caddy configuration, maintenance scripts, or live infrastructure require explicit authorization.

### For an authorized deployment change

1. Inspect the current image, ports, service identity, mounts, database dependencies, and data.
2. Read the relevant Compose source and identify required external settings without printing credentials.
3. Prepare an application-consistent backup and validate the proposed configuration and permissions.
4. Deploy through TrueNAS, then verify application behavior and persistence.
5. For migrations, retain the previous state until the replacement is verified.

The `tank/Apps` migration is complete, and that dataset has been deleted. Use current backups for recovery. The [migration history](../history/migrations.md) describes what was retained, reset, and retired.

## Git authentication

Use the checkout's existing authentication. This code-server checkout uses a persistent SSH deploy key selected by repository-local `core.sshCommand`. Other environments may have their own HTTPS authentication; that is not a reason to change this checkout's working SSH setup. An explicit SSH override once bypassed code-server's working key selection and caused `Permission denied (publickey)`.

Inspect repository state in **code-server**:

```bash
git -C /workspace status --short --branch
git -C /workspace diff --check
```

Preserve working credential helpers and SSH configuration. If authentication fails, inspect the relevant local configuration without sharing key contents or credential-bearing URLs. Review explicit file diffs before committing; `.gitignore` cannot detect a secret embedded inside a tracked file.

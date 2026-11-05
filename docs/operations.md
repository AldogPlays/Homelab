# Operations and troubleshooting

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Networking](networking.md) · [Services](services.md) · [Database recovery](POSTGRES_RECOVERY.md)

Use this page for routine inspection, deployment, and focused troubleshooting. Commands identify where they run; check container names against the current deployment before using an example. Historical incidents explain the diagnostics, but do not establish a current outage.

## Start here

| Task or symptom | Procedure |
| --- | --- |
| Find a file in the right shell | [Host and container paths](#find-the-right-path) |
| Check an app's status, mounts, or configuration | [Inspect a TrueNAS app](#inspect-a-truenas-app) |
| Prepare and deploy a change | [Deployment workflow](#deployment-workflow) |
| Caddy cannot see an edited route | [Compare host and container files](#caddy-route-present-on-host-but-missing-in-container) |
| A long media transfer stopped | [Interrupted media copy](#interrupted-media-copy) |
| An application cannot access its files | [Storage permissions](#storage-permissions) |
| Git authentication fails | [Git authentication](#git-authentication) |
| Strata is healthy but its API is unreachable | [Prometheus diagnostics](#prometheus-healthy-container-unreachable-api) |
| Open WebUI shows replies late | [Compare backend and browser timing](#open-webui-replies-appear-late) |
| Recover a database | [PostgreSQL recovery](POSTGRES_RECOVERY.md) |

Use [backups](backups.md#check-the-setup) to check protection jobs and [networking](networking.md) for the address/DNS reference.

## Find the right path

| Context | Repository | Application state |
| --- | --- | --- |
| TrueNAS host | `/mnt/tank/stacks` | `/mnt/tank/appdata/<app>` |
| code-server | `/workspace` | Its own persistent state is `/config` |
| Caddy container | Caddyfile at `/etc/caddy/Caddyfile` | `/data` and `/config` |
| Prometheus AI host | Strata Compose at `/srv/ai/strata/compose.yaml` | `/srv/ai/strata/data` |

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

Documentation work does not authorize deployment changes. Changes to Compose, Dockerfiles, Caddy configuration, maintenance scripts, or live infrastructure require explicit authorization. For an authorized deployment change:

1. Inspect the current image, ports, service identity, mounts, database dependencies, and data.
2. Read the relevant Compose source and identify required external settings without printing credentials.
3. Prepare an application-consistent backup and validate the proposed configuration and permissions.
4. Deploy through TrueNAS, then verify application behavior and persistence.
5. For migrations, retain the previous state until the replacement is verified.

The `tank/Apps` migration is complete, and that dataset has been deleted. Use current backups for recovery. The [migration history](migrations.md) describes what was retained, reset, and retired.

## Caddy route present on host but missing in container

**Symptom:** Jellyfin worked through its HTTP port, but private HTTPS failed with `SSL_ERROR_INTERNAL_ERROR_ALERT`. A reload reported unchanged configuration even though the editor showed a new route.

Compare the file in all three contexts:

```bash
# TrueNAS host
sudo rg -n 'jellyfin.home.arpa' /mnt/tank/stacks/caddy/Caddyfile

# code-server terminal
rg -n 'jellyfin.home.arpa' /workspace/caddy/Caddyfile

# TrueNAS host, reading the container's view
sudo docker exec ix-caddy-caddy-1 \
  grep -n 'jellyfin.home.arpa' /etc/caddy/Caddyfile
```

Use `grep -n` on the host/editor if `rg` is unavailable. During the incident, the host and editor contained the route while the container did not. Caddy was bound to an individual file, as it remains in the [Compose definition](../caddy/compose.yaml).

An editor save that replaces the host file may leave the single-file bind attached to old contents. That was the suspected cause here, but it was not proven. HTTPS was restored; the exact fix is not documented. Check host and container contents before choosing a remedy, and preserve Caddy's data and configuration.

For a recurrence, establish which file Caddy can actually see before changing certificates or backend ports. Read-only validation on TrueNAS:

```bash
sudo docker exec ix-caddy-caddy-1 \
  caddy validate --config /etc/caddy/Caddyfile
```

A successful syntax check does not prove the file contains the intended route. Preserve Caddy's existing CA state; only the public root certificate belongs on clients.

## Interrupted media copy

During the Audiobookshelf migration, a browser-shell timeout left the destination incomplete. No `rsync` process remained. An incremental `rsync` resumed the transfer and subsequent comparisons verified copied application state.

For a long transfer, run it in a persistent session and verify that the transfer itself is inside that session. After a disconnect, inspect the process and destination before launching another copy. A final incremental run can transfer only a small fraction of the total library; its percentage is not a complete migration check.

Preserve application-referenced container paths while changing host storage. Audiobookshelf's old-looking internal library path is deliberate; see [the migration details](migrations.md#audiobookshelf-preserve-the-container-path).

## Storage permissions

Code-server uses editor UID `3000`, GID `3001`. Several applications use `568:568`; PostgreSQL uses `999:999`, Crafty uses `1000:1000`, and Joplin Server uses `1001:1001`. Check the current Compose source and running identity rather than applying one ownership rule to all appdata.

POSIX ownership and mode output alone did not explain all effective access because datasets could have ACLs. Check access as the application's actual identity, including relevant supplementary groups. A successful test on a directory establishes only that directory's access, not every nested file's permissions.

A qBittorrent migration issue combined an incorrect save path with insufficient directory access. Both needed correction. Check the host-to-container mapping, application save path, and service-user access together.

## Git authentication

Use the checkout's existing authentication. Code-server used a persistent SSH deploy key and repository-local `core.sshCommand`; other environments can use HTTPS authentication. An explicit SSH override once bypassed code-server's working key selection and caused `Permission denied (publickey)`.

Inspect repository state in **code-server**:

```bash
git -C /workspace status --short --branch
git -C /workspace diff --check
```

Preserve working credential helpers and SSH configuration. If authentication fails, inspect the relevant local configuration without sharing key contents or credential-bearing URLs. Review explicit file diffs before committing; `.gitignore` cannot detect a secret embedded inside a tracked file.

## Prometheus: healthy container, unreachable API

**Symptom:** Strata was healthy inside Docker, but `docker port strata` showed no active publication and the host health URL refused connections. Desired `HostConfig.PortBindings` still listed the expected address.

Read-only checks on **Prometheus**:

```bash
ip -4 -br addr
ip -4 route
findmnt --mountpoint /srv/ai
sudo docker ps -a --filter name=strata
sudo docker port strata
sudo docker inspect strata \
  --format 'NetworkMode={{.HostConfig.NetworkMode}} PortBindings={{json .HostConfig.PortBindings}}'
sudo systemctl status strata-compose.service --no-pager
sudo journalctl -u strata-compose.service -b --no-pager -n 60
curl -fsS --max-time 10 http://10.10.10.20:8080/health
```

Recreating the container restored the published port. The systemd unit now waits for the Ethernet address and runs Compose with `--force-recreate`. A manual service start, health request, and startup after reboot have all succeeded. The unit lives at `/etc/systemd/system/strata-compose.service` on Prometheus.

Startup ordering and network reconfiguration were suspected contributors, not proven root causes. Distinguish a missing port publication from a model still loading: some early checks failed only a few seconds after recreation and passed once the model was ready. Docker process restart policy also does not establish recovery from a process that stays alive but becomes unhealthy.

## Open WebUI replies appear late

During initial use, some replies appeared delayed in Open WebUI while backend requests had already completed. The cause was not isolated. Compare backend completion with visible answer timing; reasoning and tool activity can precede the final answer. Separate those timings before attributing the delay to model generation or changing the serving configuration.

# Operations and troubleshooting

[Overview](../README.md) · [Services](services.md) · [Migration history](migrations.md) · [Database recovery](POSTGRES_RECOVERY.md)

Use this reference to inspect apps, navigate host and container paths, and troubleshoot issues encountered during the 2026 refactor. Each command identifies where it runs. Check container names against the current deployment before using an example.

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

For a future migration, first inspect the actual image, ports, service identity, bind mounts, database dependencies, and existing data. Prepare an application-consistent backup, copy or initialize state according to the intended migration, validate permissions and Compose syntax, and deploy through TrueNAS. Verify application behavior and persistence before retiring the old source.

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

A successful syntax check does not prove the file contains the intended route. Preserve `/mnt/tank/appdata/caddy/data`, which contains CA state; only the public root certificate belongs on clients.

## Interrupted media copy

During the Audiobookshelf migration, a browser-shell timeout left the destination incomplete. No `rsync` process remained. An incremental `rsync` resumed the transfer and subsequent comparisons verified copied application state.

For a long transfer, run it in a persistent session and verify that the transfer itself is inside that session. After a disconnect, inspect the process and destination before launching another copy. A final incremental run can transfer only a small fraction of the total library; its percentage is not a complete migration check.

Preserve application-referenced container paths while changing host storage. Audiobookshelf's old-looking internal library path is deliberate; see [the migration details](migrations.md#audiobookshelf-preserve-the-container-path).

## Storage permissions

The migration used app-specific access checks rather than recursively changing all of `appdata`. Code-server's editor identity differs from the common application UID `568`, PostgreSQL UID `999`, and other service identities specified in the Compose files.

POSIX ownership and mode output alone did not explain all effective access because datasets could have ACLs. Check access as the application's actual identity, including relevant supplementary groups. A successful test on a directory establishes only that directory's access, not every nested file's permissions.

A qBittorrent migration issue combined an incorrect save path with insufficient directory access. Both needed correction. Check the host-to-container mapping, application save path, and service-user access together.

## Git SSH authentication

The code-server workflow used a persistent repository deploy key outside Git and a repository-local `core.sshCommand`. An explicit SSH override once bypassed that working selection and caused `Permission denied (publickey)`.

Inspect repository status/configuration in **code-server** without printing key contents:

```bash
git -C /workspace status --short --branch
git -C /workspace config --local --get core.sshCommand
git -C /workspace diff --check
```

Preserve the working SSH configuration. Private keys, application secrets, and personal automation instructions stay outside the repository. Review explicit file diffs before committing; `.gitignore` cannot detect a secret embedded inside a tracked file.

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

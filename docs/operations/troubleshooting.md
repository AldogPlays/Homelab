# Troubleshooting

> [Homelab](../../README.md) · [Documentation](../README.md) · [Roadmap](../roadmap.md)

These procedures come from problems I encountered while building and migrating the lab. Check the shell context and current container names before using a command.

> [!NOTE]
> The incidents below are historical examples. They explain the diagnostics and do not establish a current outage.

**On this page:** [Caddy](#caddy-route-present-on-host-but-missing-in-container) · [Media transfers](#interrupted-media-copy) · [Permissions](#storage-permissions) · [Prometheus API](#prometheus-healthy-container-unreachable-api) · [WebUI timing](#open-webui-replies-appear-late)

## Caddy route present on host but missing in container

**Symptom:** Jellyfin worked through its HTTP port, but private HTTPS failed with `SSL_ERROR_INTERNAL_ERROR_ALERT`. A reload reported unchanged configuration even though the editor showed a new route.

### Compare the three file views

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

Use `grep -n` on the host/editor if `rg` is unavailable.

### Interpret the result

During the incident, the host and editor contained the route while the container did not. Caddy was bound to an individual file, as it remains in the [Compose definition](../../caddy/compose.yaml).

An editor save that replaces the host file may leave the single-file bind attached to old contents. That was the suspected cause here, but it was not proven. HTTPS was restored; the exact fix is not documented. Check host and container contents before choosing a remedy, and preserve Caddy's data and configuration.

### Validate the container's configuration

For a recurrence, establish which file Caddy can actually see before changing certificates or backend ports. Read-only validation on TrueNAS:

```bash
sudo docker exec ix-caddy-caddy-1 \
  caddy validate --config /etc/caddy/Caddyfile
```

A successful syntax check does not prove the file contains the intended route. Preserve Caddy's existing CA state; only the public root certificate belongs on clients.

## Interrupted media copy

During the Audiobookshelf migration, a browser-shell timeout left the destination incomplete. No `rsync` process remained. An incremental `rsync` resumed the transfer and subsequent comparisons verified copied application state.

For a long transfer, run it in a persistent session and verify that the transfer itself is inside that session. After a disconnect, inspect the process and destination before launching another copy. A final incremental run can transfer only a small fraction of the total library; its percentage is not a complete migration check.

Preserve application-referenced container paths while changing host storage. Audiobookshelf's old-looking internal library path is deliberate; see [the migration details](../history/migrations.md#audiobookshelf-preserve-the-container-path).

## Storage permissions

UID and GID are the numeric user and group IDs used for filesystem access. The recorded identities are:

| Service | UID:GID |
| --- | --- |
| code-server editor | `3000:3001` |
| Several applications | `568:568` |
| PostgreSQL | `999:999` |
| Crafty | `1000:1000` |
| Joplin Server | `1001:1001` |

Check the current Compose source and running identity rather than applying one ownership rule to all appdata.

POSIX ownership and mode output alone did not explain all effective access because datasets could have ACLs. Check access as the application's actual identity, including relevant supplementary groups. A successful test on a directory establishes only that directory's access, not every nested file's permissions.

A qBittorrent migration issue combined an incorrect save path with insufficient directory access. Both needed correction. Check the host-to-container mapping, application save path, and service-user access together.

## Prometheus: healthy container, unreachable API

**Symptom:** Strata was healthy inside Docker, but `docker port strata` showed no active port publication and the host health URL refused connections.

Port publication is Docker's mapping from a host address/port to a container port. Desired `HostConfig.PortBindings` still listed the expected address, but that configuration alone did not prove the mapping was active.

### Check the host and container

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

### Recorded resolution and limits

Recreating the container restored the published port. The systemd unit now waits for the Ethernet address and runs Compose with `--force-recreate`. A manual service start, health request, and startup after reboot have all succeeded. The unit lives at `/etc/systemd/system/strata-compose.service` on Prometheus.

Startup ordering and network reconfiguration were suspected contributors, not proven root causes. Distinguish a missing port publication from a model still loading: some early checks failed only a few seconds after recreation and passed once the model was ready. Docker process restart policy also does not establish recovery from a process that stays alive but becomes unhealthy.

## Open WebUI replies appear late

**Symptom:** During initial use, some replies appeared delayed in Open WebUI while backend requests had already completed. The cause was not isolated.

**Compare:** Backend completion and visible answer timing. Reasoning and tool activity can precede the final answer. Separate those timings before attributing the delay to model generation or changing the serving configuration.

The [benchmark timing definitions](../benchmarks/q2-0.md#how-to-read-the-timings) explain first-token versus first-answer latency; those measurements bypass Open WebUI and cannot diagnose a browser delay on their own.

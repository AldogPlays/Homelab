# Troubleshooting

> [Homelab](../README.md)

These are problems I ran into while setting up and migrating the lab, along with the checks I used. Check which shell a command belongs in and confirm the current container names before using it.

> [!NOTE]
> These are past incidents, not a list of current outages. I've kept the uncertain causes and missing details explicit.

## Caddy route present on host but missing in container

Jellyfin worked through its HTTP port, but I got `SSL_ERROR_INTERNAL_ERROR_ALERT` over private HTTPS. I got an unchanged-configuration message from Caddy on reload even though my editor showed the new route.

The host and editor had the route, but the container did not. A stale file bind after an editor save was a suspected cause, not a proven one. HTTPS was restored, but I didn't record the exact fix. Preserve Caddy's existing data, configuration, and CA state; only the public root certificate belongs on clients.

<details>
<summary>Compare the files and validate Caddy</summary>

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

During the incident, the host and editor contained the route while the container did not. Caddy was bound to an individual file, as it remains in the [Compose definition](../caddy/compose.yaml).

An editor save that replaces the host file may leave the single-file bind attached to old contents. That was the suspected cause here, but it was not proven. HTTPS was restored; the exact fix is not documented. Check host and container contents before choosing a remedy, and preserve Caddy's data and configuration.

### Validate the container's configuration

For a recurrence, establish which file Caddy can actually see before changing certificates or backend ports. Read-only validation on TrueNAS:

```bash
sudo docker exec ix-caddy-caddy-1 \
  caddy validate --config /etc/caddy/Caddyfile
```

A successful syntax check does not prove the file contains the intended route. Preserve Caddy's existing CA state; only the public root certificate belongs on clients.

</details>

## Nextcloud untrusted domain

After I changed the LAN address, Nextcloud showed **Access through untrusted domain** at `http://10.10.10.10:30027`. On November 3, I fixed it by updating the allowed hosts and CLI URL.

<details>
<summary>The settings I changed and how I check them</summary>

| Runtime setting | Value I set |
| --- | --- |
| `trusted_domains` | `nextcloud.home.arpa`, `10.10.10.10:30027` |
| `overwrite.cli.url` | `https://nextcloud.home.arpa` |

These settings live in Nextcloud's persistent configuration. Inspect them on the **TrueNAS host**:

```bash
sudo docker exec -u www-data ix-nextcloud-nextcloud-1 \
  php /var/www/html/occ status

sudo docker exec -u www-data ix-nextcloud-nextcloud-1 \
  php /var/www/html/occ config:system:get trusted_domains

sudo docker exec -u www-data ix-nextcloud-nextcloud-1 \
  php /var/www/html/occ config:system:get overwrite.cli.url
```

I checked Nextcloud `35.0.2`: it was installed, maintenance mode was off, and no database upgrade was needed. I could then open my authenticated dashboard at the direct IP. That HTTP check didn’t test DNS, TLS, or the proxy; I checked private HTTPS access from my phone separately in my [network notes](networking.md#local-and-remote-service-access).

</details>

## Open WebUI startup: connection refused

When I first deployed Open WebUI, Compose validation passed but `http://10.10.10.10:30070/health` still refused connections. Later, I got `{"status":true}` twice and could use the app. The initial refusal alone didn’t tell me whether the problem was the Compose file, initialization, or the model backend.

<details>
<summary>Startup checks and persistent state</summary>

Read-only checks on the **TrueNAS host**:

```bash
sudo docker compose -f /mnt/tank/stacks/open-webui/compose.yaml config --quiet
sudo docker ps -a --filter name=ix-open-webui \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ss -ltn | grep ':30070 '
curl -fsS --max-time 10 http://10.10.10.10:30070/health
```

Check deployment state and allow initialization to complete before repeating the health request. Compose validation establishes configuration validity; a successful health response establishes WebUI availability. Test its connection to Strata separately using the [local AI guide](local-ai.md#serving-layout).

Persistent backend data is under `/mnt/tank/appdata/open-webui/data`. Preserve the existing `WEBUI_SECRET_KEY` in `/mnt/tank/appdata/open-webui/secrets/open-webui.env`; setup verified a root-owned mode `600` file in a mode `700` secrets directory.

</details>

## Interrupted media copy

My browser shell timed out during the Audiobookshelf move, leaving an incomplete destination and no `rsync` process running. I resumed it with an incremental `rsync` and compared the copied app state afterward.

For a long transfer, run it in a persistent session and verify that the transfer itself is inside that session. After a disconnect, inspect the process and destination before launching another copy. A final incremental run can transfer only a small fraction of the total library; its percentage is not a complete migration check.

Preserve application-referenced container paths while changing host storage. Audiobookshelf's old-looking internal library path is deliberate; see [the migration details](migrations.md#audiobookshelf-preserve-the-container-path).

## Storage permissions

UID and GID are the numeric user and group IDs used for filesystem access. These are the identities I used:

<details>
<summary>Service identities</summary>

| Service | UID:GID |
| --- | --- |
| code-server editor | `3000:3001` |
| Several applications | `568:568` |
| PostgreSQL | `999:999` |
| Crafty | `1000:1000` |
| Joplin Server | `1001:1001` |

</details>


Check the current Compose source and running identity rather than applying one ownership rule to all appdata.

POSIX ownership and mode output alone did not explain all effective access because datasets could have ACLs. Check access as the application's actual identity, including relevant supplementary groups. A successful test on a directory establishes only that directory's access, not every nested file's permissions.

A qBittorrent migration issue combined an incorrect save path with insufficient directory access. Both needed correction. Check the host-to-container mapping, application save path, and service-user access together.

## Prometheus: healthy container, unreachable API

Strata was healthy inside Docker, but `docker port strata` showed no active port publication and the host health URL refused connections.

Port publication is Docker's mapping from a host address/port to a container port. Desired `HostConfig.PortBindings` still listed the expected address, but that configuration alone did not prove the mapping was active.

Recreating the container restored the port, and the systemd startup unit now waits for Ethernet and recreates it. I verified manual startup, the health request, and startup after reboot. Startup ordering and network changes were suspected contributors, not proven causes.

<details>
<summary>Prometheus checks and what resolved the incident</summary>

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

### What fixed it and what I haven’t tested

Recreating the container restored the published port. The systemd unit now waits for the Ethernet address and runs Compose with `--force-recreate`. A manual service start, health request, and startup after reboot have all succeeded. The unit lives at `/etc/systemd/system/strata-compose.service` on Prometheus.

Startup ordering and network reconfiguration were suspected contributors, not proven root causes. Distinguish a missing port publication from a model still loading: some early checks failed only a few seconds after recreation and passed once the model was ready. Docker process restart policy also does not establish recovery from a process that stays alive but becomes unhealthy.

</details>

## Open WebUI replies appear late

When I first used Open WebUI, some replies appeared late even though the backend requests had finished. I didn't isolate the cause.

The useful comparison is when the backend finishes versus when the answer becomes visible. Reasoning and tool activity can come before the final answer, so those timings need separating before blaming model generation or changing the serving configuration.

The [benchmark timing definitions](q2-benchmark.md#how-to-read-the-timings) explain first-token versus first-answer latency; those measurements bypass Open WebUI and cannot diagnose a browser delay on their own.

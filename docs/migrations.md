# Migration history

> [Homelab](../README.md)

In late October and early November 2026, I moved the lab from application-specific storage under `tank/Apps` to Git-managed Compose definitions, separate application state, and shared user-data datasets. TrueNAS continued to manage the application lifecycle.

These are the moves I've completed, including the network and AI-host changes. The [hardware](infrastructure.md), [network](networking.md), and [service notes](services.md) describe the current setup. Some November 5 UTC timestamps fall on November 4 in Pacific time.

## Milestones

| Period | Change |
| --- | --- |
| Late October–early November 2026 | Moved apps to Git-managed definitions and separated state from user data |
| November 3 | Deleted the legacy `tank/Apps` dataset after dependency checks |
| Early November | Replaced the eero with Hermes and moved Prometheus from Windows to Ubuntu |
| November 4–5 | Added snapshot policies and daily PostgreSQL backup/retention jobs |
| November 4 Pacific / November 5 UTC | Completed the standard Q2_0 benchmark |
| By November 6 | Compared six standard AI runs and retained Coder IQ1_M with RAM-resident experts as the baseline |

## Deployment and storage refactor

I separated the versioned definitions, app state, and user data. That [storage layout](infrastructure.md#storage-layout) is still what I use.

I deployed the apps through TrueNAS **Install via YAML**, loading their Compose files from the repository. I could edit and version the configuration while keeping deployment and app management in TrueNAS. Each app directory stayed at the repository root because another `stacks/` directory inside the repo would have changed the existing include paths.

I gave code-server a dedicated editor identity instead of the NAS administrator's identity and checked workspace access with write tests. The other apps kept their own service identities. I did not apply one ownership rule to the whole tree.

## Application moves

I kept the app data I needed and deliberately started fresh where I didn't need the old state. Some moves also needed path, port, or permission fixes. The details below record what I kept, what I discarded, and what I actually checked.

<details>
<summary>Application-by-application migration details</summary>

| Application | Approach | Outcome |
| --- | --- | --- |
| SearXNG | Fresh installation; old unused settings were disposable | Replacement service working |
| qBittorrent | Fresh torrent state and settings, retaining Gluetun/PIA and dynamic port forwarding | Matching VPN egress, forwarded listening port, VPN interface, and scoped storage access verified; save path corrected |
| Actual Budget | Stopped the old app, copied its state, compared source and destination, checked service-user access | Existing budget worked in the replacement |
| Audiobookshelf | Moved books to shared media and copied configuration/metadata | Existing library, artwork, and playback history visible |
| Navidrome | Moved music to shared media and copied application state | Replacement working with read-only music access |
| Jellyfin | Fresh installation, deliberately omitting old users, libraries, settings, and history | First-run setup completed; direct HTTP and later private HTTPS worked |
| Crafty 4 | Retained server content; deliberately omitted old backups | Replacement server storage present; old backups were not transferred |
| Nextcloud, Immich, Vaultwarden, Joplin, LubeLogger | Moved to the new application/user-data layout | Host mounts pointed to the new paths and all apps remained running after legacy storage retirement |
| Open WebUI | Added after the main application moves | Health endpoint returned `{"status":true}` |

### Audiobookshelf: preserve the container path

I moved the host storage while keeping the application's stored library path valid.

Audiobookshelf's database already referred to its original library path. I changed the host source while keeping the container destination:

```text
Host source:           /mnt/tank/data/media/audiobooks
Container destination: /mnt/tank/Apps/audiobookshelf/audiobooks
```

The old-looking destination is intentional and remains in the [Compose source](../audiobookshelf/compose.yaml). It does not mount the retired host `tank/Apps` dataset. Changing that destination would require coordinating Audiobookshelf's stored library references.

The initial media transfer stopped when the browser shell timed out. Inspection showed no remaining `rsync` process and an incomplete destination. An incremental copy resumed the transfer, followed by state comparisons and access checks. Its progress percentage described that incremental run, not the completeness of the entire migration.

### Navidrome: distinguish host and application ports

Navidrome's external port stayed `30043`, while its internal listening port changed from the old `30043` setting to `4533`. The replacement mapped `10.10.10.10:30043` to container port `4533` and mounted music read-only at `/music`.

### qBittorrent: validate each part of the workflow

My early network checks confirmed VPN egress and a PIA-assigned port, but the forwarding callback returned `403 Forbidden`. A later check showed the listening port matching PIA's forwarded port, with qBittorrent bound to `tun0`. Localhost authentication bypass was enabled at that point for callbacks in the shared network namespace.

The storage checks found two separate problems: the default save path still pointed to `/downloads`, while the actual mount was `/data/torrents`, and UID `568` could not write to the torrent directory. A nonrecursive ownership correction on the specific empty torrent directories and a Web UI save-path correction resolved both issues.

Those checks covered routing, forwarding, and storage access. They did not establish download/seeding or VPN-recovery behavior; those require their own tests after relevant changes.

### Nextcloud: repair URLs after the network change

Direct access on the new LAN initially produced an untrusted-domain error. Updating allowed hosts and the CLI URL for the new address and private HTTPS name restored access to the authenticated dashboard.

The verified allowed hosts were `nextcloud.home.arpa` and `10.10.10.10:30027`, with `overwrite.cli.url` set to `https://nextcloud.home.arpa`. The former LAN and Tailscale entries were removed. [Troubleshooting](troubleshooting.md#nextcloud-untrusted-domain) records the checks and the distinction between direct-HTTP and later HTTPS evidence.

DAVx5 setup was also resolved. It now works on my phone through the private HTTPS URL; the precise authorization fix and contact-group setting are not documented.

</details>

## Private HTTPS

Caddy's internal CA provided private HTTPS, with local DNS names standardized on application names such as `actual-budget.home.arpa` and `navidrome.home.arpa`. Purpose-based labels such as Budget and Music were used for bookmarks. Earlier aliases such as `code.home.arpa` and `search.home.arpa` were superseded.

Jellyfin exposed a useful troubleshooting case: direct HTTP worked, but HTTPS failed during the TLS handshake. The host's Caddyfile contained the route while the container's file did not. A stale single-file bind mount after an editor save was suspected, but the mechanism was not proven. HTTPS was restored; the exact fix is not documented. See [operations](troubleshooting.md#caddy-route-present-on-host-but-missing-in-container) for the diagnostic sequence.

## Retiring legacy storage

On November 3, I retired the legacy `tank/Apps` dataset after the app moves. Before deleting it, I checked:

- Host bind sources for both running and stopped containers.
- TrueNAS shares, cron jobs, rsync/cloud-sync/replication/snapshot tasks, and startup scripts that referenced the old path.
- Textual references in the Compose repository.
- Explicit decisions to discard old Jellyfin media and old Crafty backups.

The remaining Compose reference was Audiobookshelf's container destination, not a host dependency. I checked `zfs list tank/Apps` afterward and got “dataset does not exist.” All 14 installed apps were still `RUNNING` in my middleware query.

Some reclaimed space had been retained by legacy snapshots, explaining why ZFS `USED` figures had exceeded file-level `du` totals. File-level deletion and pool-level space reclamation were separate checks.

Right after the cleanup, I checked `zpool list tank`: the `5.45T` pool was `ONLINE`, with `978G` allocated and `4.50T` free. I also checked that the old dataset was gone and the apps were still running.

## Networking and service changes

I replaced the eero with Hermes, the Flint 2 running OpenWrt, set up the trusted, IoT, and guest networks, and switched remote access to WireGuard. I no longer use Tailscale, AdGuard Home, File Browser, Jackett, or FlareSolverr.

I moved Joplin sync from Nextcloud to Joplin Server and verified Immich, Bitwarden, and DAVx5 over private HTTPS on my phone. The [network notes](networking.md) have the current connection details.

## Prometheus: move to Ubuntu

I moved Prometheus from Windows to bare-metal Ubuntu Server in early November 2026. I mounted a dedicated ext4 logical volume (LV) at `/srv/ai` for model and runtime data.

<details>
<summary>CPU threads, Ethernet, and startup fixes</summary>

### CPU threads

Simultaneous multithreading (SMT) lets a CPU core expose more than one hardware thread. I initially saw only eight threads in Linux and SMT set to `notsupported`, despite no explicit `nosmt` kernel option. After a BIOS change, I had eight cores / sixteen threads and SMT `on`. I suspected Gigabyte X3D Turbo Mode, but didn’t isolate the responsible setting.

### Ethernet and routing

Ethernet initially had link without IPv4 DHCP configured in Netplan. Enabling DHCP and moving the reserved address to Ethernet restored access. Route metrics were then adjusted to prefer Ethernet while retaining Wi-Fi fallback.

### Container startup

Strata sometimes lost active port publication during the network/reboot work. Recreation restored it, and a systemd unit was added to wait for Ethernet and recreate the container. Startup after reboot was tested successfully; [operations](troubleshooting.md#prometheus-healthy-container-unreachable-api) preserves the diagnostic sequence.

The resulting Q2_0 setup completed the [original standard benchmark](q2-benchmark.md). Later comparisons covered another Q2_0 run, a fresh restart, and three Coder IQ1_M configurations. I settled on Coder with `KV=int8`, `spec=4`, and RAM-resident experts. I kept those settings after quick and thorough tuning, but haven’t repeated the full standard suite since thorough tuning. The [benchmark history](benchmarks.md) preserves the results and limits.

</details>

## Recovery work after migration

On November 4, I enabled ten periodic snapshot tasks and saw the first hourly snapshots. I then added PostgreSQL-native logical backups for Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. A manual run produced all five sets successfully, and I configured the backup and retention cron jobs afterward.

I put off the temporary restore-test app and offsite work. These protect data locally on `tank`. I haven't configured email alerts, made an offsite copy, or completed a full restore test. My [backup notes](backups.md) have the coverage, schedules, and verification steps.

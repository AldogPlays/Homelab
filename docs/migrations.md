# Migration history

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Operations](operations.md) · [Backups and snapshots](backups.md)

In late October and early November 2026, I moved the lab from application-specific storage under `tank/Apps` to Git-managed Compose definitions, separate application state, and shared user-data datasets. TrueNAS continued to manage the application lifecycle.

This page records completed changes, including the later network and AI-host work. Use [infrastructure](infrastructure.md), [networking](networking.md), and [services](services.md) for today's setup. Some November 5 UTC timestamps fall on November 4 in Pacific time.

## Milestones

| Period | Change |
| --- | --- |
| Late October–early November 2026 | Moved apps to Git-managed definitions and separated state from user data |
| November 3 | Deleted the legacy `tank/Apps` dataset after dependency checks |
| Early November | Replaced the eero with Hermes and moved Prometheus from Windows to Ubuntu |
| November 4 | Added snapshot policies and daily PostgreSQL backup/retention jobs |
| November 4 Pacific / November 5 UTC | Completed the standard Q2_0 benchmark |

## Deployment and storage refactor

The refactor separated versioned definitions, application state, and user data. The resulting [storage layout](infrastructure.md#storage-layout) remains the current design.

Apps were deployed through TrueNAS **Install via YAML**, loading the Compose file stored in the repository. This kept configuration editable and versioned while retaining the TrueNAS Apps interface for deployment and lifecycle management. I kept each app directory at the repository root; adding another `stacks/` directory inside the repo would have changed existing include paths.

Code-server used a dedicated editor identity rather than the NAS administrator's identity. Effective write tests established workspace access. Other applications retained their own service identities; a single ownership rule was not applied to the entire tree.

## Application moves

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

Early checks proved VPN egress and a PIA-assigned port, but the forwarding callback initially returned `403 Forbidden`. A later check showed the listening port matched PIA's forwarded port and qBittorrent was bound to `tun0`. Localhost authentication bypass was enabled at that point for callbacks in the shared network namespace.

Storage checks then found two separate problems: the default save path still pointed to `/downloads`, while the actual mount was `/data/torrents`, and UID `568` could not write to the torrent directory. A nonrecursive ownership correction on the specific empty torrent directories and a Web UI save-path correction resolved both issues. These checks covered routing, forwarding, and storage access; download/seeding and VPN-recovery behavior need their own tests after relevant changes.

### Nextcloud: repair URLs after the network change

Direct access on the new LAN initially produced an untrusted-domain error. Updating allowed hosts and the CLI URL for the new address and private HTTPS name restored access to the authenticated dashboard.

DAVx5 setup was also resolved. It now works on my phone through the private HTTPS URL; the precise authorization fix and contact-group setting are not documented.

## Private HTTPS

Caddy's internal CA provided private HTTPS, with local DNS names standardized on application names such as `actual-budget.home.arpa` and `navidrome.home.arpa`. Purpose-based labels such as Budget and Music were used for bookmarks. Earlier aliases such as `code.home.arpa` and `search.home.arpa` were superseded.

Jellyfin exposed a useful troubleshooting case: direct HTTP worked, but HTTPS failed during the TLS handshake. The host's Caddyfile contained the route while the container's file did not. A stale single-file bind mount after an editor save was suspected, but the mechanism was not proven. HTTPS was restored; the exact fix is not documented. See [operations](operations.md#caddy-route-present-on-host-but-missing-in-container) for the diagnostic sequence.

## Retiring legacy storage

On November 3, I retired the legacy `tank/Apps` dataset after the application moves. Before deletion, I checked:

- Host bind sources for both running and stopped containers.
- TrueNAS shares, cron jobs, rsync/cloud-sync/replication/snapshot tasks, and startup scripts that referenced the old path.
- Textual references in the Compose repository.
- Explicit decisions to discard old Jellyfin media and old Crafty backups.

The remaining Compose reference was Audiobookshelf's container destination, not a host dependency. Subsequent `zfs list tank/Apps` reported that the dataset did not exist, and all 14 installed apps in the accompanying middleware query remained `RUNNING`.

Some reclaimed space had been retained by legacy snapshots, explaining why ZFS `USED` figures had exceeded file-level `du` totals. File-level deletion and pool-level space reclamation were separate checks.

## Networking and service changes

Hermes, the Flint 2 running OpenWrt, replaced the eero as the main router. Trusted, IoT, and guest networks were configured, and WireGuard became the remote-access path. Tailscale, AdGuard Home, File Browser, Jackett, and FlareSolverr are no longer used.

Joplin moved from Nextcloud synchronization to Joplin Server. Immich, Bitwarden, and DAVx5 were verified through private HTTPS on the phone. Current connection details are in [networking and access](networking.md).

## Prometheus: move to Ubuntu

Prometheus moved from Windows to bare-metal Ubuntu Server in early November 2026. A dedicated ext4 LV was mounted at `/srv/ai` for model and runtime data.

Linux initially exposed eight threads with SMT reported as `notsupported`, despite no explicit `nosmt` kernel option. A BIOS change restored eight cores / sixteen threads and SMT `on`. Gigabyte X3D Turbo Mode was suspected, but the exact responsible setting was not established.

Ethernet initially had link without IPv4 DHCP configured in Netplan. Enabling DHCP and moving the reserved address to Ethernet restored access. Route metrics were then adjusted to prefer Ethernet while retaining Wi-Fi fallback.

Strata sometimes lost active port publication during the network/reboot work. Recreation restored it, and a systemd unit was added to wait for Ethernet and recreate the container. Startup after reboot was tested successfully; [operations](operations.md#prometheus-healthy-container-unreachable-api) preserves the diagnostic sequence.

The resulting Q2_0 setup completed the [standard benchmark](local-ai.md#q2_0-standard-benchmark), which is the single performance baseline.

## Recovery work after migration

On November 4, ten periodic snapshot tasks were enabled and the first hourly snapshots were observed. PostgreSQL-native logical backups were then added for Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. A manual run produced all five backup sets successfully; backup and retention cron jobs were configured afterward.

These policies provide local protection on `tank`. Email alerts, an offsite copy, and a full restore test remain outstanding. See [backups](backups.md) for coverage, schedules, and verification steps.

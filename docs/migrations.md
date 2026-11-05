# Migration history

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Operations](operations.md) · [Backups and snapshots](backups.md)

In late October and early November 2026, I moved the lab from application-specific storage under `tank/Apps` to Git-managed Compose definitions, separate application state, and shared user-data datasets. TrueNAS continued to manage the application lifecycle.

This history covers the refactor and its outcomes; see [infrastructure](infrastructure.md) and [services](services.md) for the current setup. Some November 5 UTC timestamps fall on November 4 in Pacific time.

## Deployment and storage refactor

The refactor separated three responsibilities:

| Host location | Purpose |
| --- | --- |
| `/mnt/tank/stacks` | Git repository, Compose definitions, and documentation; mounted at `/workspace` in code-server |
| `/mnt/tank/appdata/<app>` | Persistent application state, databases, configuration, and secrets |
| `/mnt/tank/data` | User files, photos, games, and shared media |

Apps were deployed through TrueNAS **Install via YAML**, loading the Compose file stored in the repository. This kept configuration editable and versioned while retaining the TrueNAS Apps interface for deployment and lifecycle management. I kept each app directory at the repository root; adding another `stacks/` directory inside the repo would have changed existing include paths.

Code-server used a separate `homelab_editor` identity, UID `3000` and GID `3001`, rather than the NAS administrator's identity. Effective write tests established access to the workspace and editor state. Other applications used their own service identities; `568:568` was common but was not applied universally.

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

The initial media transfer stopped when the browser shell timed out. Inspection showed no remaining `rsync` process and an incomplete destination. An incremental copy resumed the transfer, followed by state comparisons and access checks. The final incremental run transferred about 5.6 GB of a roughly 31.6 GB source; its progress percentage described that run, not the completeness of the entire migration.

### Navidrome: distinguish host and application ports

Navidrome's external port stayed `30043`, while its internal listening port changed from the old `30043` setting to `4533`. The replacement mapped `10.10.10.10:30043` to container port `4533` and mounted music read-only at `/music`.

### qBittorrent: validate each part of the workflow

Early checks proved VPN egress and a PIA-assigned port, but the forwarding callback initially returned `403 Forbidden`. A later check showed the listening port matched PIA's forwarded port and qBittorrent was bound to `tun0`. Localhost authentication bypass was enabled at that point for callbacks in the shared network namespace.

Storage checks then found two separate problems: the default save path still pointed to `/downloads`, while the actual mount was `/data/torrents`, and UID `568` could not write to the torrent directory. A nonrecursive ownership correction on the specific empty torrent directories and a Web UI save-path correction resolved both issues. These checks covered routing, forwarding, and storage access; download/seeding and VPN-recovery behavior need their own tests after relevant changes.

### Nextcloud: repair URLs after the network change

Direct access on the new LAN address initially produced an untrusted-domain error. I set the allowed hosts to `nextcloud.home.arpa` and `10.10.10.10:30027`, and the CLI URL to `https://nextcloud.home.arpa`. Direct-IP access then reached the authenticated dashboard.

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

Pool allocation fell to roughly 978 GB at that observation. Some reclaimed space had been retained by legacy snapshots, explaining why ZFS `USED` figures had exceeded file-level `du` totals. These are historical measurements, not current capacity figures.

## Recovery work after migration

On November 4, ten periodic snapshot tasks were enabled and the first hourly snapshots were observed. PostgreSQL-native logical backups were then added for Nextcloud, Immich, Vaultwarden, Joplin, and LubeLogger. A manual run produced all five backup sets successfully; backup and retention cron jobs were configured afterward.

These policies provide local protection on `tank`. Email alerts, an offsite copy, and a full restore test remain outstanding. See [backups](backups.md) for coverage, schedules, and verification steps.

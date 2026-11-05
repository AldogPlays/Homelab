# Decisions and lessons

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Networking](networking.md) · [Migration history](migrations.md) · [Roadmap](roadmap.md)

The lab is built around everyday use, reused hardware, and configuration I can understand and maintain. This page explains the choices and lessons behind it. [Migration history](migrations.md) records the actual cutovers; the other guides describe the current setup.

## Everyday use and cost

The lab grew from services I actually use: Immich for photos, Navidrome for music, Audiobookshelf for purchased audiobooks, Nextcloud for files and personal information, and Vaultwarden for passwords. Joplin, Actual Budget, Minecraft, and vehicle records make it useful beyond media storage. I built [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android) for my own hosted service.

Immich, Navidrome, and Audiobookshelf have taken over photo, music, and audiobook workflows I previously handled through Google Photos, YouTube Music, and Audible.

Reducing subscriptions and controlling where my data lives motivated the project. Maintenance and recovery became my responsibility, while services such as PIA and SimpleFIN still have a place in the setup.

<details>
<summary>Subscription costs avoided</summary>

These are the subscriptions I've replaced. The estimate uses U.S. monthly prices checked October 12, 2026, with assumed tiers rather than my old bills.

| Subscription dropped | Assumed plan | Monthly | Annualized |
| --- | --- | ---: | ---: |
| Google One | 100 GB | $1.99 | $23.88 |
| YouTube Music Premium | Individual | $11.99 | $143.88 |
| Netflix | Standard with ads | $8.99 | $107.88 |
| Disney+ | With ads, new-subscriber rate | $12.49 | $149.88 |
| **Estimated spending avoided** | | **$35.46** | **$425.52** |

The annual figures are 12 monthly payments. These are avoided subscription costs, before tax, discounts, and the cost of running the lab. PIA and SimpleFIN are still part of my setup. My own media library also differs from a streaming service's catalog.

</details>

## Architecture choices

### Reuse hardware, separate workloads

I converted the gaming PC I already owned into a TrueNAS host: more RAM, mirrored data drives, a 2.5 GbE NIC, and no discrete GPU. The original SSD became the boot drive. This made useful storage infrastructure without replacing the whole machine.

Prometheus is a separate AMD machine for GPU-heavy model inference. Open WebUI runs with the other applications on TrueNAS, while Strata serves models from Prometheus. The completed standard benchmark of the working Q2_0 setup provides its performance baseline, with twelve sanity checks passed and request/output limits documented alongside speed.

### Keep configuration editable and deployment visible

I chose TrueNAS-managed custom apps loading on-disk Compose files. The repository holds deployment definitions, while TrueNAS retains lifecycle visibility. This avoided introducing another application-management interface just to edit YAML.

Each stack stays directly under the repository root because working include paths depend on that layout. The host repository is already `/mnt/tank/stacks`.

Code-server uses a dedicated editor identity rather than the NAS administrator's identity. Application access is checked per service and dataset. An ACL can explain effective write access even when basic ownership output looks restrictive; recursively changing all app data would discard that distinction.

### Separate state, user data, and recoverable history

The refactor established `stacks` for configuration, `appdata` for state/secrets, and `data` for user content. The later backup project added a separate `backups` location on the same pool. This makes mounts and protection policies easier to understand, but separation within one pool does not create an independent backup.

The mirror provides disk redundancy. Periodic snapshots add local history, and native PostgreSQL exports create application database archives. Archive parsing and checksum verification check the backup files; a full restore test is still needed to validate recovery. An independent copy remains a separate requirement.

## Maintenance lessons

### Preserve what the application depends on

Audiobookshelf needed its stored library references preserved. The host library moved to shared media, while the container kept its old internal path. A path that looks untidy can encode an application dependency; normalizing it without checking the database would risk breaking the library.

Navidrome kept the same external port while adopting its normal internal port. qBittorrent required both a matching save path and writable storage. These migrations reinforced the distinction between host paths, container paths, host ports, and application listening ports.

Future downloader and library paths should share one media filesystem where hardlinks are intended. Being on the same ZFS pool alone is insufficient when paths cross dataset boundaries. The broader common-container-path design remains a future *Arr integration task.

### Check the layer that actually failed

Jellyfin's HTTPS failure happened before an HTTP request could reach Jellyfin. The host and editor showed a route that Caddy's container could not see. The confirmed discrepancy was stale container-visible configuration; an editor replacement leaving a stale file bind was a plausible explanation, not a proven root cause.

Prometheus exposed another distinction: Docker's desired port-binding configuration could be present while active publication was absent. A healthy model process did not establish that the host API was reachable. Recreation restored publication, and a systemd startup unit was added. Startup after reboot now works.

The [operations reference](operations.md) includes diagnostic commands for both incidents and distinguishes confirmed symptoms from suspected causes.

### Prefer simple, persistent tooling

Code-server settled on a persistent repository SSH deploy key. An explicit override later caused an authentication failure by bypassing that working key selection. Preserve the authentication configured for each checkout rather than assuming all environments use the same method.

Private keys and credential values remain outside Git. Ignore rules help with matching files but cannot identify secrets embedded in otherwise valid configuration. Reviewing the actual diff is part of maintaining a public technical portfolio.

### Consider who a network change affects

Earlier household-wide AdGuard filtering interfered with family use, so filtering was narrowed to personal devices through Tailscale at that stage. Both services are now retired. The lesson is to account for other users and provide practical exceptions.

The original eero-to-switch link illustrated that upgrading a server NIC and switch does not prove throughput across the whole path. The eero is now retired; current capacity should be measured rather than inferred from the old bottleneck or individual link speeds. See [networking](networking.md) for the current layout.

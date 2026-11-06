# Decisions and lessons

> [Homelab](../../README.md) · [Documentation](../README.md)

I built this around services I actually use, hardware I already had, and a setup I could understand and maintain. These are the choices that shaped it and the lessons I took from working on it. The [migration notes](migrations.md) cover the actual moves.

## Everyday use and cost

I use Immich for photos, Navidrome for music, Audiobookshelf for purchased audiobooks, Nextcloud for files and personal information, and Vaultwarden for passwords. Joplin, Actual Budget, Minecraft, and vehicle records make the lab useful beyond media storage. I also built [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android) for my own hosted service.

Immich, Navidrome, and Audiobookshelf have taken over photo, music, and audiobook workflows I previously handled through Google Photos, YouTube Music, and Audible.

I wanted fewer subscriptions and more control over where my data lives. That also made maintenance and recovery my responsibility. I still use services such as PIA and SimpleFIN.

<details>
<summary><strong>Subscription costs avoided</strong></summary>

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

I keep apps and storage on TrueNAS and model inference on Prometheus.

I converted the gaming PC I already owned into a TrueNAS host: more RAM, mirrored data drives, a 2.5 GbE NIC, and no discrete GPU. The original SSD became the boot drive. This made useful storage infrastructure without replacing the whole machine.

Prometheus is a separate AMD machine for GPU-heavy model inference. Open WebUI runs with the other applications on TrueNAS, while Strata serves models from Prometheus. The completed [standard benchmark](../benchmarks/q2-0.md#q2_0-standard-benchmark) of the working Q2_0 setup provides its performance baseline. Twelve sanity checks passed; the guide explains generation speed, the wait for an answer, and the request/output limits together.

### Keep configuration editable and deployment visible

I keep Compose files in Git and manage the apps through TrueNAS.

I chose TrueNAS custom apps that load Compose files from disk. I can edit and version the definitions in Git while keeping app management visible in TrueNAS. I didn't need another management interface just to edit YAML.

Each stack stays directly under the repository root because working include paths depend on that layout. The host repository is already `/mnt/tank/stacks`.

I gave code-server its own editor identity instead of using the NAS administrator's identity. Access is checked per service and dataset. An ACL can allow writes even when basic ownership output looks restrictive, so changing ownership recursively across all app data would lose that distinction.

### Separate state, user data, and recoverable history

I keep configuration, app state, user files, and backups in separate places so their mounts and protection rules are easier to understand.

<details>
<summary>Storage roles and when I added them</summary>

| Location | Role | Introduced |
| --- | --- | --- |
| `stacks` | Configuration | Storage refactor |
| `appdata` | Application state and secrets | Storage refactor |
| `data` | User content | Storage refactor |
| `backups` | Recoverable backup files | Later backup project |

</details>


Those locations still share the same pool. Separating them does not create an independent backup.

The mirror provides disk redundancy. Periodic snapshots add local history, and native PostgreSQL exports create application database archives.

PostgreSQL tools can check that an archive is readable, and checksums detect changes to its files. I haven't completed a full restore test or made an independent copy, so neither recovery nor protection from losing the pool is established by those checks.

## Maintenance lessons

### Preserve what the application depends on

I kept Audiobookshelf's old internal path when I moved the host library to shared media because its database already referred to that path. A path can look untidy and still matter to the app; renaming it without checking the database could break the library.

Navidrome kept the same external port while adopting its normal internal port. qBittorrent required both a matching save path and writable storage. These migrations reinforced the distinction between host paths, container paths, host ports, and application listening ports.

Hardlinks need the downloader and library paths to share one filesystem. Being on the same ZFS pool is not enough when the paths cross dataset boundaries.

### Check the layer that actually failed

When Jellyfin's HTTPS connection failed, it happened before an HTTP request could reach Jellyfin. I found the route in the host file and editor, but Caddy's container could not see it. That confirmed stale container-visible configuration. An editor save leaving a stale file bind was a possible explanation, not a proven cause.

On Prometheus, I found that Docker could list the desired port binding without actually publishing the port. The model could be healthy while its host API was unreachable. Recreating the container restored publication, and I added a systemd startup unit. Startup after reboot now works.

The [troubleshooting guide](../operations/troubleshooting.md) includes diagnostic commands for both incidents and distinguishes confirmed symptoms from suspected causes.

### Prefer simple, persistent tooling

I settled on a persistent repository SSH deploy key for code-server. An explicit override later bypassed the working key selection and broke authentication. Each checkout needs to keep its own working authentication; different environments don't necessarily use the same method.

I keep private keys and credential values outside Git and review the actual diff before publishing. Ignore rules can catch matching files, but they can't detect a secret embedded in otherwise valid configuration.

### Consider who a network change affects

My earlier household-wide AdGuard filtering got in the way of family use, so I narrowed it to my own devices through Tailscale at that stage. Both services are now retired. That taught me to account for other users and provide practical exceptions.

The original eero-to-switch link also showed why a faster server NIC and switch don't prove throughput across the whole connection. The eero is now retired. Its old bottleneck and individual link speeds don't establish current capacity; that takes a measurement. The [network notes](../setup/networking.md) show the current layout.

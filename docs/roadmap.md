# Roadmap

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Backups](backups.md) · [Local AI](local-ai.md)

The application/storage migration, Hermes network setup, phone HTTPS access, and Prometheus reboot startup are complete. Snapshot policies and daily database jobs were added on November 4, 2026. These are the next maintenance and development priorities, with no fixed timeline.

## Recovery verification and independent backups

- Check the first unattended backup runs and checksum-check a newly scheduled set.
- Observe retention once expired candidates exist; the initial dry run correctly had none.
- Test a full isolated database restore and validate the application with its related files.
- Choose an independent backup destination and copy the necessary databases, files, secrets, and CA state; test recovery from that copy.
- Configure email alerts and verify delivery.
- Decide whether to snapshot `tank/backups` and whether `tank/data/games` needs coverage; neither is covered by the ten-task snapshot policy.

Email alerts, an offsite copy, and a full restore test are not yet in place. See [backups](backups.md) for the implemented policy and [the recovery runbook](POSTGRES_RECOVERY.md) for the manual procedure.

## Network follow-ups

Hermes is the GL.iNet Flint 2 main router. Trusted, IoT, and guest networks work, and WireGuard handles remote access. The eero and Tailscale are retired.

- Record physical port assignments, inter-network firewall rules, and measured throughput.
- Review printer and TV-to-Jellyfin access requirements, including device addresses, network placement, and necessary firewall rules.

Phone access for Immich, Bitwarden, and DAVx5 through private HTTPS already works with Caddy's internal CA. Publicly trusted DNS-01 certificates remain an option if a future client requires them.

## Media automation and integrations

No *Arr stack is deployed. Sonarr, Radarr, Prowlarr, and optional request/subtitle services are candidates; the final component list is still a design choice.

Before integration, inspect qBittorrent's actual save paths/categories, preserve Gluetun/PIA forwarding and isolation, and establish consistent container paths within `tank/data/media`. Verify hardlink imports. Existing Jellyfin and qBittorrent stacks are separate working definitions.

Check Fidelity/SimpleFIN compatibility before enabling that integration.

## Local AI benchmarks and maintenance

Prometheus works after reboot with Q2_0, 64K context, and Ethernet preferred over Wi-Fi fallback. The [standard Q2_0 benchmark](local-ai.md#q2_0-standard-benchmark) is complete, with 12/12 sanity checks and no failed requests. It is the single performance baseline.

- Document Prometheus's full systemd, fstab, and Netplan settings for recovery.
- Review routine Ubuntu updates and hardware power-recovery settings as part of maintenance.

RAM and AMD GPU upgrades remain exploratory.

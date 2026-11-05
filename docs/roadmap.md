# Roadmap

> [Overview](../README.md) · [Networking](networking.md) · [Services](services.md) · [Backups](backups.md) · [Local AI](local-ai.md)

Recovery verification is the first priority, followed by network documentation and optional integrations. These are outstanding tasks, with no fixed timeline. The [overview](../README.md#current-status) summarizes completed work; detailed verification results belong in the relevant system guide.

## Recovery verification and independent backups

- [ ] Check the first unattended backup runs and checksum-check a newly scheduled set.
- [ ] Observe retention once expired candidates exist; the initial dry run correctly had none.
- [ ] Test a full isolated database restore and validate the application with its related files.
- [ ] Choose an independent backup destination and copy the necessary databases, files, secrets, and CA state; test recovery from that copy.
- [ ] Configure email alerts and verify delivery; keep cron stderr visible, then test that alerts actually arrive.
- [ ] Decide whether to snapshot `tank/backups` and whether `tank/data/games` needs coverage; neither is covered by the ten-task snapshot policy.

Use [backups](backups.md) for implemented coverage and [the recovery runbook](POSTGRES_RECOVERY.md) for the isolated restore procedure.

## Network follow-ups

The [networking guide](networking.md) records the working layout and access paths.

- [ ] Record physical port assignments, inter-network firewall rules, and measured throughput.
- [ ] Review printer and TV-to-Jellyfin access requirements, including device addresses, network placement, and necessary firewall rules.

Publicly trusted DNS-01 certificates remain an option if a future client requires them; the existing phone HTTPS workflows already work with Caddy's internal CA.

## Media automation and integrations

No *Arr stack is deployed. Sonarr, Radarr, Prowlarr, and optional request/subtitle services are candidates; the final component list is still a design choice.

Before integration, inspect qBittorrent's actual save paths/categories, preserve Gluetun/PIA forwarding and isolation, and establish consistent container paths within `tank/data/media`. Verify hardlink imports. Existing Jellyfin and qBittorrent stacks are separate working definitions.

Check Fidelity/SimpleFIN compatibility before enabling that integration.

## Local AI benchmarks and maintenance

The [standard Q2_0 benchmark](local-ai.md#q2_0-standard-benchmark) is complete and remains the single performance baseline.

- [ ] Document Prometheus's full systemd, fstab, and Netplan settings for recovery.
- [ ] Review routine Ubuntu updates and hardware power-recovery settings as part of maintenance.

RAM and AMD GPU upgrades remain exploratory.

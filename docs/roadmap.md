# Roadmap

> [Homelab](../README.md) · [Documentation](README.md) · [Backups](operations/backups.md)

Recovery verification is the first priority, followed by network documentation and optional integrations. These are outstanding tasks, with no fixed timeline. The [overview](../README.md#current-status) summarizes completed work; detailed verification results belong in the relevant system guide.

**On this page:** [Recovery first](#recovery-verification-and-independent-backups) · [Networking](#network-follow-ups) · [Media and integrations](#media-automation-and-integrations) · [Local AI](#local-ai-benchmarks-and-maintenance)

## Recovery verification and independent backups

### Verify the existing protection

- [ ] Check daily, weekly, and monthly snapshot execution; only the first hourly snapshots have been observed.
- [ ] Check the first unattended backup runs and checksum-check a newly scheduled set.
- [ ] Observe retention once expired candidates exist; the initial dry run correctly had none.
- [ ] Test a full isolated database restore and validate the application with its related files.

### Add independent recovery and alerts

- [ ] Choose an independent backup destination and copy the necessary databases, files, secrets, and CA state; test recovery from that copy.
- [ ] Configure email alerts and verify delivery; keep cron stderr visible, then test that alerts actually arrive.
- [ ] Decide whether to snapshot `tank/backups` and whether `tank/data/games` needs coverage; neither is covered by the ten-task snapshot policy.

Use [backups](operations/backups.md) for implemented coverage and [the recovery runbook](operations/postgres-recovery.md) for the isolated restore procedure.

## Network follow-ups

The [networking guide](setup/networking.md) records the working layout and access paths.

- [ ] Record physical port assignments, inter-network firewall rules, and measured throughput.
- [ ] Review printer and TV-to-Jellyfin access requirements, including device addresses, network placement, and necessary firewall rules.

Publicly trusted certificates obtained through DNS-01 (a DNS-based domain-ownership check) remain an option if a future client requires them; the existing phone HTTPS workflows already work with Caddy's internal CA.

## Media automation and integrations

No *Arr media-automation stack is deployed. Sonarr (TV), Radarr (movies), Prowlarr (indexer management), and optional request/subtitle services are candidates; the final component list is still a design choice.

### Before integrating media automation

- [ ] Inspect qBittorrent's actual save paths/categories.
- [ ] Preserve Gluetun/PIA forwarding and isolation.
- [ ] Test downloads, seeding, and forwarding recovery after relevant changes.
- [ ] Establish consistent container paths within `tank/data/media`.
- [ ] Verify hardlink imports.

Existing Jellyfin and qBittorrent stacks are separate working definitions.

### Budgeting integration

- [ ] Check Fidelity/SimpleFIN compatibility before enabling that integration.

## Local AI benchmarks and maintenance

The [standard Q2_0 benchmark](benchmarks/q2-0.md#q2_0-standard-benchmark) is complete and remains the single performance baseline. It covers short, 4K, and 16K prompts with capped outputs; it does not establish full-64K quality or performance with simultaneous requests.

- [ ] Document Prometheus's full systemd, fstab, and Netplan settings for recovery.
- [ ] Review routine Ubuntu updates and hardware power-recovery settings as part of maintenance.
- [ ] Verify hardware power-outage recovery and recovery from an unhealthy-but-running process separately from the successful reboot test.

RAM and AMD GPU upgrades remain exploratory.

# Infrastructure

[Overview](../README.md) · [Networking](networking.md) · [Services](services.md) · [Local AI](local-ai.md) · [Backups](backups.md)

The lab has a TrueNAS application/storage host, a separate Ubuntu AI host, and Hermes, a GL.iNet Flint 2 running OpenWrt as the main router.

This page covers the machines and storage. Use [networking and access](networking.md) for addresses and connection paths, or [operations](operations.md) for deployment and troubleshooting.

## TrueNAS application and storage host

My former NZXT BLD gaming PC runs TrueNAS Community Edition. The last documented OS release is TrueNAS SCALE 25.10.4.

| Component | Hardware |
| --- | --- |
| CPU | Intel Core i7-9700K, 8 cores, 3.6 GHz base |
| Motherboard | Gigabyte Z390 AORUS PRO WIFI |
| Memory | 32 GB G.SKILL TridentZ RGB DDR4-3200, four 8 GB sticks |
| Boot drive | Intel 665p 1 TB SSD |
| Data drives | Two WD Red Plus 6 TB HDDs in mirrored pool `tank` |
| Added network adapter | Realtek 2.5 GbE NIC; exact model unspecified |
| Case | NZXT H710, black |
| CPU cooler | Deepcool GAMMAX GTE V2 |
| Additional fans | Two NZXT Aer F 120 fans |
| Power supply | be quiet! Pure Power 11 700W CM Gold |
| Accessory | NZXT USB Expansion |

The conversion replaced the original Seagate Barracuda 2 TB HDD, expanded memory from 16 to 32 GB, added the network adapter, and removed the MSI GeForce RTX 2070 SUPER VENTUS OC. I also cleaned the system and repositioned the drive tray for the new disks.

TrueNAS Apps manages the application lifecycle. On-disk Compose files are loaded through **Install via YAML**, keeping deployment definitions in Git. See [operations](operations.md#deployment-workflow) for the include pattern and execution contexts.

## Storage layout

The tree distinguishes ZFS datasets from ordinary directories. `<app>` represents each application's directory or dataset.

```text
tank/                         ZFS pool/root dataset
├── stacks/                   ZFS dataset; this Git repository
│   ├── <app>/                ordinary directory; Compose source
│   ├── docs/                 ordinary directory; documentation
│   └── scripts/              ordinary directory; maintenance script sources
├── appdata/                  ZFS dataset
│   └── <app>/                per-app ZFS dataset; runtime state and secrets
├── data/                     ZFS dataset
│   ├── files/                ZFS dataset; Nextcloud user files
│   ├── photos/               ZFS dataset; Immich photo/video data
│   ├── games/                ZFS dataset; reserved user-data location
│   └── media/                ZFS dataset
│       ├── audiobooks/       ordinary directory
│       ├── music/            ordinary directory
│       └── torrents/         ordinary directory
└── backups/                  ZFS dataset
    ├── databases/            ZFS dataset; per-app backup directories within it
    └── bin/                  ordinary directory; protected operational scripts
```

The pool is mounted beneath `/mnt/tank`. The repository appears at `/workspace` inside code-server. Runtime state, databases, secrets, and user data stay outside Git. Compose references to these paths document the deployment without including their contents.

Crafty's server files live in `appdata/crafty-4/servers`; `data/games` is reserved. The former `tank/Apps` layout is retired; see [migration history](migrations.md) for the cutover and [media storage](services.md#media-storage) for Audiobookshelf's preserved container path.

Media directories share one ZFS filesystem to support the planned downloader/library hardlink workflow. Future movie, TV, and automation paths are plans until configured and checked; the existing qBittorrent source mounts only `media/torrents` at `/data/torrents`. See [services](services.md#media-storage) before designing additional mounts.

## Storage access and protection

Each application has its own service identity and dataset access. POSIX ownership, supplementary groups, and dataset ACLs all matter. The [permissions procedure](operations.md#storage-permissions) explains how to inspect effective access without recursively changing the storage tree.

The mirror protects against a single data-drive failure. [Backups and snapshots](backups.md) covers local history, database exports, exclusions, and recovery limits.

## Prometheus AI host

| Component | Configuration |
| --- | --- |
| Host / OS | `prometheus`, Ubuntu Server 26.04.1 LTS |
| CPU | AMD Ryzen 7 7800X3D, 8 cores / 16 threads after BIOS troubleshooting |
| Motherboard / BIOS | Gigabyte B650I AORUS ULTRA / F43c |
| GPU | PowerColor Radeon RX 7800 XT, 16 GiB VRAM; AMD integrated graphics also present |
| RAM / swap | 32 GB DDR5, about 29 GiB reported usable; 8 GiB swap |
| Storage | Approximately 2 TB NVMe; 100 GB root LV and 1 TB ext4 AI-data LV |
| AI storage mount | `/srv/ai`, on `/dev/ubuntu-vg/ai-data`; mount persistence observed after reboots |
| Ethernet | Intel I225-V, `igc`, `enp13s0`, negotiated 2.5 Gb/s full duplex |

Strata runs in Docker with AMD device access; Open WebUI on TrueNAS connects to it across the LAN. The [local AI guide](local-ai.md) covers model settings, startup, and the benchmark. Ethernet preference and Wi-Fi fallback are documented in [networking](networking.md#network-layout).

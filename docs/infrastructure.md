# Infrastructure

> [Homelab](../README.md)

I use TrueNAS for applications and storage, and Hermes, a GL.iNet Flint 2 running OpenWrt, as the main router. Prometheus is a separate PC being repurposed for game streaming.

The hardware and storage details are below. My [network notes](networking.md) cover addresses and access, and [operations](operations.md) has the commands I use to inspect the setup.

## TrueNAS application and storage host

My former NZXT BLD gaming PC runs TrueNAS Community Edition. The last documented OS release is TrueNAS SCALE 25.10.4.

<details>
<summary>TrueNAS hardware</summary>

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

</details>


For the conversion, I replaced the original Seagate Barracuda 2 TB HDD with the mirrored data drives, expanded the RAM from 16 to 32 GB, and added the network adapter. I removed the MSI GeForce RTX 2070 SUPER VENTUS OC, cleaned the system, and repositioned the drive tray for the new disks.

I manage the apps through TrueNAS **Install via YAML**, which loads the Compose files from this repository. That keeps the definitions in Git and app management in TrueNAS. The [operations notes](operations.md#deployment-workflow) show the include pattern and where the commands run.

## Storage layout

I keep the Compose files in `stacks`, app state and secrets in `appdata`, user files in `data`, and backup files in `backups`. They are all on the same `tank` pool. Runtime state, databases, secrets, and user data stay outside Git.

<details>
<summary>Dataset tree and exact paths</summary>

Two kinds of storage appear in the tree:

- **ZFS dataset:** a separate filesystem with its own properties, permissions, and snapshot policy.
- **Ordinary directory:** a directory inside a dataset, sharing that filesystem.

That boundary matters for snapshots and hardlinks. `<app>` represents each application's directory or dataset.

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

### How the paths map

The pool is mounted beneath `/mnt/tank`. Dataset names, host paths, and container paths refer to different views of the storage:

| Storage | TrueNAS host path | Inside code-server |
| --- | --- | --- |
| Git repository, `tank/stacks` | `/mnt/tank/stacks` | `/workspace` |
| Persistent editor home | `/mnt/tank/appdata/code-server` | `/config` |

For example, `tank/appdata/nextcloud` is a dataset name, while `/mnt/tank/appdata/nextcloud` is its host path.

Runtime state, databases, secrets, and user data stay outside Git. Compose references to these paths document the deployment without including their contents.

### Application-specific paths

Crafty's server files live in `appdata/crafty-4/servers`; `data/games` is reserved. The former `tank/Apps` layout is retired; see [migration history](migrations.md) for the cutover and [media storage](services.md#media-storage) for Audiobookshelf's preserved container path.

The media directories share one ZFS filesystem, so hardlinks can stay within that filesystem. qBittorrent currently mounts only `media/torrents` at `/data/torrents`. The [media storage notes](services.md#media-storage) list the actual mounts.

</details>

## Storage access and protection

Each application has its own service identity and dataset access. Effective access depends on:

- File ownership and Unix permission bits (POSIX permissions).
- Supplementary groups.
- Dataset access control lists (ACLs).

The [permissions procedure](troubleshooting.md#storage-permissions) explains how to inspect effective access without recursively changing the storage tree.

The mirror protects against a single data-drive failure. [Backups and snapshots](backups.md) covers local history, database exports, exclusions, and recovery limits.

## Prometheus

Prometheus is the PC I moved to the living room. I plan to use Windows 11 with Sunshine on it and Moonlight on my desk device, keeping my existing USB-C/Thunderbolt setup. I chose Windows because I want to play Battlefield 6. I want a minimal installation with unwanted apps and background clutter removed.

The target is a 120 FPS stream to a 120 Hz display. That is a goal, not a measured result or a promise that every game will render at 120 FPS. The Windows installation and streaming setup are still pending; I have not recorded the client, monitor resolution, or dock limits yet.

<details>
<summary>Prometheus hardware and storage</summary>

| Component | Configuration |
| --- | --- |
| Host / last recorded OS | `prometheus`, Ubuntu Server 26.04.1 LTS; Windows migration pending |
| CPU | AMD Ryzen 7 7800X3D, 8 cores / 16 threads |
| Motherboard | Gigabyte B650I AORUS ULTRA |
| GPU | PowerColor Radeon RX 7800 XT, 16 GiB VRAM; AMD integrated graphics also present |
| RAM / swap | 32 GB DDR5, about 29 GiB usable; 8 GiB swap |
| Storage | Approximately 2 TB NVMe (`SHPP41-2000GM`); existing Ubuntu partition layout has not been changed |
| Ethernet | Intel I225-V, `igc`, `enp13s0`, negotiated 2.5 Gb/s full duplex |

</details>


The [retirement notes](migrations.md#local-ai-retirement) separate repository cleanup from outstanding host and data removal. The last recorded Ethernet preference and Wi-Fi fallback are documented in [networking](networking.md#network-layout); those OS settings will need revisiting after a Windows installation.

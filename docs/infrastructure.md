# Infrastructure

[Back to overview](../README.md) · [Services](services.md) · [Decisions](decisions-and-lessons.md) · [Roadmap](roadmap.md)

## Current server

My former NZXT BLD gaming PC now runs **TrueNAS SCALE 25.10.4** and hosts the lab's services.

| Component | Current inventory |
| --- | --- |
| CPU | Intel Core i7-9700K, 8 cores, 3.6 GHz base |
| Motherboard | Gigabyte Z390 AORUS PRO WIFI |
| Memory | 32 GB G.SKILL TridentZ RGB DDR4-3200, four matching 8 GB sticks |
| Boot drive | Intel 665p 1 TB SSD, used for the TrueNAS OS |
| Data drives | Two WD Red Plus 6 TB HDDs in a mirrored pool |
| Added network adapter | Realtek 2.5 GbE NIC; exact model not recorded |
| Case | NZXT H710, black |
| CPU cooler | Deepcool GAMMAX GTE V2 |
| Additional fans | Two NZXT Aer F 120 fans |
| Power supply | be quiet! Pure Power 11 700W CM Gold |
| Accessory | NZXT USB Expansion |

## Implemented modifications

- Replaced the original Seagate Barracuda 2 TB HDD with the two 6 TB HDDs.
- Added two matching 8 GB memory sticks, increasing RAM from 16 GB to 32 GB.
- Added the Realtek 2.5 GbE NIC.
- Removed the MSI GeForce RTX 2070 SUPER VENTUS OC.
- Cleaned the system and slightly repositioned the existing drive tray to accommodate the drives.

I'm not planning any further server hardware upgrades right now.

## Storage and recovery

TrueNAS boots from the SSD. The two HDDs form the mirrored data pool; a breakdown of datasets and application storage is still to come.

**No independent backups or snapshots are currently configured.** Mirroring is redundancy within the same system; it does not provide an independent copy or a history of recoverable versions. Improving recovery is the highest-priority item on the [roadmap](roadmap.md).

## Current network

| Component | Current role |
| --- | --- |
| Internet connection | 2 Gb/s fiber service |
| ISP-provided eero 6E | Router and Wi-Fi access for most household clients |
| TP-Link unmanaged switch | Eight 2.5 GbE ports; connects the server and some entertainment devices such as consoles and TVs |
| Tailscale TrueNAS app and client apps | Private access to hosted services |

Most clients use eero Wi-Fi; some consoles and TVs are wired to the switch. Personal devices generally use the LAN when available and Tailscale otherwise. Some use Tailscale automatically, even at home.

The eero-to-switch connection is limited to 1 Gb/s. I haven't documented throughput measurements yet.

Tailscale Serve provides tailnet-only service URLs and HTTPS where needed. One current route uses HTTP. Private addresses and service mappings stay out of this repository.

AdGuard Home is used with Tailscale for personal-device filtering. The eero does not use AdGuard Home as its DNS server, avoiding the family-network interference experienced previously.

## Planned network changes

I want to find or build a router capable of 2.5 Gb/s throughput and possibly use the eero only as a wireless access point. I have a spare older router, but its ports are limited to 1 GbE. I haven't chosen the hardware, OS, or layout for the replacement yet.

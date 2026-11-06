# Homelab

I run my personal cloud on a repurposed gaming PC with [TrueNAS](https://www.truenas.com/truenas-community-edition/). It holds my photos, files, notes, passwords, and media. A second machine, Prometheus, runs local AI models on an AMD GPU.

I started this to replace recurring subscriptions and have more control over my data. These are my notes on what I run, how it works, and what I learned setting it up. The app configurations are here too; my data and credentials stay outside Git.

## Architecture

```mermaid
flowchart LR
    Devices["Personal devices"] --- Router["Hermes<br/>Router"]
    Router --- NAS["TrueNAS<br/>Apps and storage"]
    Router --- AI["Prometheus<br/>Local AI"]

    classDef host fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    classDef router fill:#dcfce7,stroke:#16a34a,color:#14532d
    class NAS,AI host
    class Router router
```

Hermes connects the lab, TrueNAS hosts applications and data, and Prometheus runs local AI. The [networking guide](docs/setup/networking.md) explains network separation and local/remote access.

## What I run

| Area | Services |
| --- | --- |
| Personal cloud | Nextcloud for files, calendar, contacts, and bookmarks; Immich for photos and videos; Vaultwarden for passwords |
| Notes and budgeting | Joplin Server for notes synchronization; Actual Budget with SimpleFIN imports |
| Media | Jellyfin for movies and TV; Audiobookshelf for purchased audiobooks; Navidrome for music |
| Personal projects | Crafty 4 for Minecraft; LubeLogger for truck maintenance, modifications, and fuel |
| Local AI | Open WebUI on TrueNAS, connected to Strata on Prometheus |
| Supporting services | Caddy, code-server, SearXNG, and qBittorrent with Gluetun/PIA |

The [service guide](docs/setup/services.md) covers dependencies, clients, and links to all 15 Compose stacks. The [decisions and lessons](docs/history/decisions-and-lessons.md) explain the hardware reuse, storage design, and subscriptions this setup replaces.

## Documentation

[All my notes are here](docs/README.md): the hardware and network, the apps I use, backups, troubleshooting, and how the lab got to this point.

## Current status

As of November 4, 2026 Pacific time (November 5 UTC), the storage migration, three-network setup, phone HTTPS access, and Prometheus startup after reboot are working. I also finished the standard Q2_0 benchmark.

I set up local snapshots and daily PostgreSQL backup jobs on November 4. The first snapshots and a manual backup worked, but I haven't verified unattended runs or completed a full restore test. Email alerts and an offsite copy aren't set up. The [backup notes](docs/operations/backups.md) explain what is covered.

## Hardware gallery

Click a photo to view it larger.

<table>
  <tr>
    <td width="33%" valign="top">
      <a href="assets/photos/gaming-pc-before-truenas.jpg">
        <img src="assets/photos/gaming-pc-before-truenas.jpg" alt="Original gaming PC with its discrete GPU installed" width="240">
      </a><br>
      <strong>The starting point</strong><br>
      Gaming PC before the TrueNAS conversion.
    </td>
    <td width="33%" valign="top">
      <a href="assets/photos/wd-red-plus-6tb-pair.jpg">
        <img src="assets/photos/wd-red-plus-6tb-pair.jpg" alt="Two boxed WD Red Plus 6 TB hard drives" width="240">
      </a><br>
      <strong>Mirrored storage</strong><br>
      Two 6 TB WD Red Plus data drives.
    </td>
    <td width="33%" valign="top">
      <a href="assets/photos/case-during-conversion.jpg">
        <img src="assets/photos/case-during-conversion.jpg" alt="Disassembled NZXT H710 case during conversion" width="240">
      </a><br>
      <strong>The conversion</strong><br>
      Case disassembled for the upgrades.
    </td>
  </tr>
</table>

# Services and clients

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Decisions](decisions-and-lessons.md) · [Roadmap](roadmap.md)

## Deployment and access

I manage all 15 hosted services through **TrueNAS Apps**. qBittorrent is a custom YAML deployment with **Gluetun** and **Private Internet Access (PIA)**.

Personal devices generally use LAN access when available and Tailscale otherwise; some use Tailscale automatically. Tailscale runs on TrueNAS and client devices, with Serve providing private URLs and HTTPS where needed. Addresses and internal service mappings are omitted.

## Current services

| Service | What I use it for | Clients and integrations |
| --- | --- | --- |
| Actual Budget | Personal budgeting | Bank transaction imports through SimpleFIN |
| AdGuard Home | Reduce tracking and block sites associated with unwanted habits on personal devices | Used with Tailscale; not configured as the eero's DNS server |
| Audiobookshelf | Replaces Audible for purchased audiobooks | [Lissen](https://github.com/GrakovNe/lissen-android) on Android; [OpenAudible](https://github.com/openaudible/openaudible) used to prepare purchased books for import |
| Crafty 4 | Minecraft server for me and my girlfriend | — |
| File Browser | File management and small repairs for media applications and downloads | Jellyfin, Audiobookshelf, Navidrome, and torrent download files |
| FlareSolverr | Supports indexer searches | Works with Jackett for qBittorrent searches |
| Immich | Replaces Google Photos | [Immich Android app](https://github.com/immich-app/immich/tree/main/mobile); all personal devices automatically upload photos and videos |
| Jackett | Indexer support for qBittorrent searches | FlareSolverr and qBittorrent |
| Jellyfin | Movies and TV obtained through qBittorrent; increasingly used by family | [AFinity](https://github.com/MakD/AFinity) on Android, preferred for its feature set |
| LubeLogger | Truck maintenance, modifications, and fuel tracking | My [LubeLogger Android app](https://github.com/AldogPlays/LubeLogger-Android) |
| Navidrome | Replaces YouTube Music | [Navic](https://github.com/ssalggnikool/Navic) on Android |
| Nextcloud | Professional, personal, and educational files; calendar, contacts, and bookmarks | Web interface, occasional [Nextcloud Android](https://github.com/nextcloud/android) file access, [DAVx5](https://github.com/bitfireAT/davx5-ose), [floccus](https://github.com/floccusaddon/floccus), and [Joplin](https://github.com/laurent22/joplin) |
| qBittorrent | Movie and TV downloads only | [qBitController](https://github.com/Bartuzen/qBitController) on Android; custom YAML with Gluetun/PIA; Jackett and FlareSolverr |
| Tailscale | Private access to all hosted services | TrueNAS app, [Tailscale Android](https://github.com/tailscale/tailscale-android) and other client apps, and Serve |
| Vaultwarden | Password manager | [Bitwarden Android](https://github.com/bitwarden/android) and [browser extensions](https://github.com/bitwarden/clients) connected to the self-hosted server |

I've switched away from envelope budgeting in Actual Budget. I'm also waiting for Fidelity compatibility with SimpleFIN to return.

## Client workflows

### Files, notes, and personal information

I mostly use Nextcloud's web interface for files. On my phone, I occasionally use the [Nextcloud Android app](https://github.com/nextcloud/android) to grab a file without opening the browser and getting distracted.

My calendar and contacts sync to my GrapheneOS phone through [DAVx5](https://github.com/bitfireAT/davx5-ose), and bookmarks sync through [floccus](https://github.com/floccusaddon/floccus). I use [Joplin](https://github.com/laurent22/joplin) for class, personal, and professional notes. I like writing in Markdown, and Nextcloud handles the sync.

### Media and photos

On Android, I listen to audiobooks with [Lissen](https://github.com/GrakovNe/lissen-android), music with [Navic](https://github.com/ssalggnikool/Navic), and watch Jellyfin through [AFinity](https://github.com/MakD/AFinity). [qBitController](https://github.com/Bartuzen/qBitController) lets me manage qBittorrent. I used [OpenAudible](https://github.com/openaudible/openaudible) to import my purchased audiobooks into Audiobookshelf.

All my personal devices automatically upload photos and videos to Immich. It's replaced Google Photos for me, though I still need an independent backup of the server.

### Passwords and vehicle records

Vaultwarden is my first password manager, and I use it through [Bitwarden Android](https://github.com/bitwarden/android) and its [browser extensions](https://github.com/bitwarden/clients). For my truck, I use [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android), the client I built for my hosted LubeLogger instance.

## Planned changes

I'd like to add an *Arr stack for media later. Backups and snapshots come first; see the [roadmap](roadmap.md).

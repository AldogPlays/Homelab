# Services and clients

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Decisions](decisions-and-lessons.md) · [Roadmap](roadmap.md)

## Deployment and access

All 15 services in the initial inventory are managed through **TrueNAS Apps**. qBittorrent uses a custom YAML deployment alongside **Gluetun**, with **Private Internet Access (PIA)**. The YAML and credentials are not published here.

Personal devices generally use LAN access when available and Tailscale otherwise; some use Tailscale automatically. Tailscale runs on TrueNAS and client devices, with Serve providing private URLs and HTTPS where needed. Addresses and internal service mappings are omitted.

## Current services

| Service | Actual use | Clients and confirmed integrations |
| --- | --- | --- |
| Actual Budget | Personal budgeting | SimpleFIN imports bank transactions; budgeting mode changed from envelope budgeting, but the exact mode name is unconfirmed |
| AdGuard Home | Reduce tracking and block sites associated with unwanted habits on personal devices | Used with Tailscale; not configured as the eero's DNS server |
| Audiobookshelf | Replaces Audible for purchased audiobooks | [Lissen](https://github.com/GrakovNe/lissen-android) on Android; [OpenAudible](https://github.com/openaudible/openaudible) used to prepare purchased books for import |
| Crafty 4 | Hosts a Minecraft server for me and my girlfriend | Client details not recorded |
| File Browser | File management and small repairs for media applications and downloads | Jellyfin, Audiobookshelf, Navidrome, and torrent download files |
| FlareSolverr | Supports indexer searches | Works with Jackett for qBittorrent searches |
| Immich | Replaces Google Photos | [Immich Android app](https://github.com/immich-app/immich/tree/main/mobile); all personal devices automatically upload photos and videos |
| Jackett | Indexer support for qBittorrent searches | FlareSolverr and qBittorrent |
| Jellyfin | Movies and TV obtained through qBittorrent; increasingly used by family | [AFinity](https://github.com/MakD/AFinity) on Android, preferred for its feature set |
| LubeLogger | Truck maintenance, modifications, and fuel tracking | My actively used [LubeLogger Android app](https://github.com/AldogPlays/LubeLogger-Android) |
| Navidrome | Replaces YouTube Music | [Navic](https://github.com/ssalggnikool/Navic) on Android |
| Nextcloud | Professional, personal, and educational files; calendar, contacts, and bookmarks | Web interface, occasional [Nextcloud Android](https://github.com/nextcloud/android) file access, [DAVx5](https://github.com/bitfireAT/davx5-ose), [floccus](https://github.com/floccusaddon/floccus), and [Joplin](https://github.com/laurent22/joplin) |
| qBittorrent | Movie and TV downloads only | [qBitController](https://github.com/Bartuzen/qBitController) on Android; custom YAML with Gluetun/PIA; Jackett and FlareSolverr |
| Tailscale | Private access to all hosted services | TrueNAS app, [Tailscale Android](https://github.com/tailscale/tailscale-android) and other client apps, and Serve |
| Vaultwarden | Password manager | [Bitwarden Android](https://github.com/bitwarden/android) and [browser extensions](https://github.com/bitwarden/clients) connected to the self-hosted server |

No separate Actual Budget automation workflows have been confirmed. Fidelity integration through SimpleFIN is pending compatibility returning, as reported during the inventory.

## Client workflows

### Files, notes, and personal information

Nextcloud files are primarily accessed through the web interface. The [Nextcloud Android app](https://github.com/nextcloud/android) is used occasionally to retrieve a file, helping me avoid the phone browser and its distractions.

Calendar and contacts sync to my GrapheneOS phone through **[DAVx5](https://github.com/bitfireAT/davx5-ose)**. Bookmarks sync through **[floccus](https://github.com/floccusaddon/floccus)**. **[Joplin](https://github.com/laurent22/joplin)** stores class, personal, and professional notes in Markdown and uses Nextcloud for synchronization. [Joplin](https://github.com/laurent22/joplin) is a client workflow, not an additional confirmed TrueNAS-hosted service.

### Media and photos

**[Lissen](https://github.com/GrakovNe/lissen-android)**, **[Navic](https://github.com/ssalggnikool/Navic)**, and **[AFinity](https://github.com/MakD/AFinity)** connect to Audiobookshelf, Navidrome, and Jellyfin respectively. **[qBitController](https://github.com/Bartuzen/qBitController)** provides Android access to qBittorrent. **[OpenAudible](https://github.com/openaudible/openaudible)** is an import tool for purchased audiobooks, rather than an everyday listening client.

**Immich** receives automatic photo and video uploads from all personal devices. This replaces the Google Photos workflow, but independent protection of the server's stored data remains unfinished.

### Passwords and vehicle records

[Bitwarden Android](https://github.com/bitwarden/android) and [browser extensions](https://github.com/bitwarden/clients) use the self-hosted Vaultwarden server. **[LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android)** is my own application and is in active use with the hosted LubeLogger instance.

## Planned changes

An *Arr stack is planned for the media workflow. Its components and configuration have not been selected or documented. Backup and snapshot improvements are also planned; see the [roadmap](roadmap.md).

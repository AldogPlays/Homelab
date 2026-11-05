# Services and clients

> [Overview](../README.md) · [Infrastructure](infrastructure.md) · [Networking](networking.md) · [Operations](operations.md) · [Backups](backups.md)

TrueNAS hosts the personal cloud, media services, and supporting tools. The 15 stacks below link directly to their Compose definitions. Those files are the reference for image versions, ports, mounts, and the users/groups that containers run as (service identities); the [Caddyfile](../caddy/Caddyfile) defines web names and proxy routes.

For HTTPS, DNS, and remote connections, start with [networking and access](networking.md#local-and-remote-service-access). For deployment or diagnostics, use [operations](operations.md).

**On this page:** [Personal cloud](#personal-cloud) · [Media and games](#media-and-games) · [Supporting services](#supporting-services) · [Clients](#clients-and-everyday-use) · [Maintenance](#configuration-and-maintenance)

## Personal cloud

| Service and source | Purpose | State and dependencies |
| --- | --- | --- |
| [Nextcloud](../nextcloud/compose.yaml) | Files, calendar, contacts, and bookmarks | PostgreSQL 17, Valkey, cron, and a [custom FFmpeg image](../nextcloud/Dockerfile); user files in `data/files` |
| [Immich](../immich/compose.yaml) | Photo and video archive | PostgreSQL/VectorChord, Valkey, and OpenVINO machine learning; media in `data/photos` |
| [Vaultwarden](../vaultwarden/compose.yaml) | Password vault | PostgreSQL and persistent vault data |
| [Joplin Server](../joplin/compose.yaml) | Notes synchronization | PostgreSQL; Joplin clients sync here |
| [Actual Budget](../actual-budget/compose.yaml) | Budgeting with SimpleFIN imports | Persistent application state and a scheduled bank-sync job |
| [LubeLogger](../lubelogger/compose.yaml) | Truck maintenance, modifications, and fuel | PostgreSQL, application files, and data-protection keys |

## Media and games

| Service and source | Purpose | State and dependencies |
| --- | --- | --- |
| [Jellyfin](../jellyfin/compose.yaml) | Movies and TV | Application state and read-only shared media |
| [Audiobookshelf](../audiobookshelf/compose.yaml) | Purchased audiobook library | Configuration/metadata and shared audiobooks |
| [Navidrome](../navidrome/compose.yaml) | Music library | Application state and read-only shared music |
| [Crafty 4](../crafty-4/compose.yaml) | Minecraft server management | Configuration, servers, imports, logs, and backups in appdata |

No *Arr media-automation stack (such as Sonarr or Radarr) is deployed. Its eventual path and hardlink design is covered under [media storage](#media-storage) and the [roadmap](roadmap.md#media-automation-and-integrations).

## Supporting services

| Service and source | Purpose | State and dependencies |
| --- | --- | --- |
| [Caddy](../caddy/compose.yaml) | Private HTTPS reverse proxy | Persistent CA/runtime state and the repository Caddyfile |
| [code-server](../code-server/compose.yaml) | Browser editor and Git workspace | Persistent editor state; repository mounted at `/workspace` |
| [Open WebUI](../open-webui/compose.yaml) | Browser interface to local models | Persistent backend data; Strata runs on [Prometheus](local-ai.md); Ollama integration disabled in source |
| [SearXNG](../searxng/compose.yaml) | Metasearch | External settings and cache |
| [qBittorrent + Gluetun](../qbittorrent/compose.yaml) | Downloads through PIA | Shared network namespace, VPN port forwarding, and torrent storage |

## Clients and everyday use

| Service | Clients and workflow |
| --- | --- |
| Nextcloud | Web/files access, [DAVx5](https://github.com/bitfireAT/davx5-ose) for calendar/contacts, and [floccus](https://github.com/floccusaddon/floccus) for bookmarks |
| Immich | Android photo/video uploads through the private HTTPS URL |
| Vaultwarden | Bitwarden clients through private HTTPS |
| Joplin Server | Joplin clients for class, personal, and professional Markdown notes; Nextcloud is no longer the sync target |
| Audiobookshelf | Lissen on Android; purchased audiobooks prepared with OpenAudible |
| Navidrome | [Navic](https://github.com/ssalggnikool/Navic) on Android |
| Jellyfin | [AFinity](https://github.com/MakD/AFinity) on Android |
| qBittorrent | qBitController |
| LubeLogger | [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android), the client I built for my own server |

These mobile workflows run on GrapheneOS/Android. Immich, Bitwarden, and DAVx5 have been verified through the private HTTPS names.

Actual Budget's [bank-sync script](../actual-budget/scripts/actual-bank-sync.sh) reads externally supplied credentials and runs daily at midnight as root. Fidelity/SimpleFIN compatibility remains a follow-up.

## Configuration and maintenance

For storage mappings, see [Media storage](#media-storage). For downloader networking and callbacks, see [qBittorrent and VPN behavior](#qbittorrent-and-vpn-behavior).

### State and external configuration

Application state lives outside Git in the [storage layout](infrastructure.md#storage-layout). Paths such as `data/files` in the tables are relative to the TrueNAS host's `/mnt/tank`; they are not repository directories.

Compose files reference external environment/secret files or mounted configuration. Start with the relevant stack to identify its required settings; inspect values locally only when needed. Keep credential values, private keys, and environment dumps out of documentation and diagnostic output.

### Check the running application

Public URLs, listen ports, proxy trust, and authentication can depend on runtime settings as well as Compose. The repository describes the intended deployment; verify the running app before changing it. PostgreSQL and cache services have no host port publications in these stacks.

Nextcloud's cron service shares the application's HTML/data mounts. Future moves need an application-consistent file and database plan; old cutover comments in source describe the completed migration.

## Media storage

These host paths are beneath `/mnt/tank`:

| Host source | Container use |
| --- | --- |
| `data/media/audiobooks` | Audiobookshelf's preserved library destination `/mnt/tank/Apps/audiobookshelf/audiobooks` |
| `data/media/music` | Navidrome `/music`, read-only |
| `data/media` | Jellyfin `/media`, read-only |
| `data/media/torrents` | qBittorrent `/data/torrents` |

Audiobookshelf's internal path is intentional: changing it can invalidate stored library references. It does not depend on the retired host dataset. See [the migration](migrations.md#audiobookshelf-preserve-the-container-path).

Media directories share one ZFS filesystem for the planned hardlink workflow. Hardlinks let a download and a library entry refer to the same stored file without keeping a second copy; they cannot cross filesystem boundaries. New movie, TV, and torrent paths should remain ordinary directories within it where hardlinks are intended. A common container `/data` layout is a future *Arr design; qBittorrent currently mounts only the torrents directory.

## qBittorrent and VPN behavior

### Ports and interfaces

qBittorrent shares Gluetun's network namespace: both containers use the same network interfaces and loopback address. Gluetun publishes the Web UI, permits its input port, and obtains a separate torrent listening port through PIA. The Web UI port and the dynamic torrent port serve different purposes.

### Port-forwarding callbacks

When VPN port forwarding starts or stops, Gluetun runs callbacks (the up/down hooks). These call qBittorrent's loopback API, selecting the VPN interface on startup and loopback on teardown. They rely on localhost authentication bypass in the shared namespace. Preserve LAN authentication, and test replacement callbacks before changing loopback authentication.

### Verification after changes

Migration checks verified VPN egress, a listening port matching PIA's assignment, and `tun0` selected. After relevant changes, also test downloads, seeding, and forwarding recovery. A former outbound-subnet exception was removed; new exceptions need a specific, tested purpose.

Compose environment changes take effect when TrueNAS recreates the app. Coordinate qBittorrent and Gluetun because they share the namespace, and allow for interrupted downloads. This outbound VPN is separate from [WireGuard remote access](networking.md#local-and-remote-service-access).

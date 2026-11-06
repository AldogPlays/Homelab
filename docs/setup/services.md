# Services and clients

> [Homelab](../../README.md) · [Documentation](../README.md)

These are the 15 app stacks I run on TrueNAS and the clients I use with them. Each app name links to its Compose file. Those files hold the image versions, ports, mounts, and service identities—the users and groups the containers run as. The [Caddyfile](../../caddy/Caddyfile) holds the web names and proxy routes.

My [network notes](networking.md#local-and-remote-service-access) cover HTTPS, DNS, and remote access. The [operations notes](../operations/README.md) cover deployment and checks.

## Personal cloud

| Service | What I use it for |
| --- | --- |
| [Nextcloud](../../nextcloud/compose.yaml) | Files, calendar, contacts, and bookmarks |
| [Immich](../../immich/compose.yaml) | Photo and video archive |
| [Vaultwarden](../../vaultwarden/compose.yaml) | Password vault |
| [Joplin Server](../../joplin/compose.yaml) | Notes synchronization |
| [Actual Budget](../../actual-budget/compose.yaml) | Budgeting with SimpleFIN imports |
| [LubeLogger](../../lubelogger/compose.yaml) | Truck maintenance, modifications, and fuel |

## Media and games

| Service | What I use it for |
| --- | --- |
| [Jellyfin](../../jellyfin/compose.yaml) | Movies and TV |
| [Audiobookshelf](../../audiobookshelf/compose.yaml) | Purchased audiobook library |
| [Navidrome](../../navidrome/compose.yaml) | Music library |
| [Crafty 4](../../crafty-4/compose.yaml) | Minecraft server management |

Jellyfin and qBittorrent are separate working stacks. I don't run an *Arr media-automation stack such as Sonarr or Radarr.

## Supporting services

| Service | What I use it for |
| --- | --- |
| [Caddy](../../caddy/compose.yaml) | Private HTTPS reverse proxy |
| [code-server](../../code-server/compose.yaml) | Browser editor and Git workspace |
| [Open WebUI](../../open-webui/compose.yaml) | Browser interface to local models |
| [SearXNG](../../searxng/compose.yaml) | Metasearch |
| [qBittorrent + Gluetun](../../qbittorrent/compose.yaml) | Downloads through PIA |

## Clients and everyday use

| Service | Clients and workflow |
| --- | --- |
| Nextcloud | Web/files access, [DAVx5](https://github.com/bitfireAT/davx5-ose) for calendar/contacts, and [floccus](https://github.com/floccusaddon/floccus) for bookmarks |
| Immich | Android photo/video uploads through the private HTTPS URL |
| Vaultwarden | Bitwarden clients through private HTTPS |
| Joplin Server | Joplin clients for class, personal, and professional Markdown notes; Nextcloud is no longer the sync target |
| Actual Budget | [Actual-Android](https://github.com/AldogPlays/Actual-Android), the Android client I built for my own budget server |
| Audiobookshelf | [Lissen](https://github.com/GrakovNe/lissen-android) on Android; purchased audiobooks prepared with OpenAudible |
| Navidrome | [Navic](https://github.com/ssalggnikool/Navic) on Android |
| Jellyfin | [AFinity](https://github.com/MakD/AFinity) on Android |
| LubeLogger | [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android), the client I built for my own server |

I use these mobile clients on GrapheneOS/Android. I've verified Immich, Bitwarden, and DAVx5 through the private HTTPS names.

Actual Budget's [bank-sync script](../../actual-budget/scripts/actual-bank-sync.sh) reads externally supplied credentials and runs daily at midnight as root. I haven't verified Fidelity/SimpleFIN compatibility.

## Media storage

I keep media together under `/mnt/tank/data/media`. Audiobookshelf keeps its old container path because its library references depend on it; changing that path can break the library. It does not depend on the retired host dataset.

<details>
<summary>Media mounts and hardlinks</summary>

These host paths are beneath `/mnt/tank`:

| Host source | Container use |
| --- | --- |
| `data/media/audiobooks` | Audiobookshelf's preserved library destination `/mnt/tank/Apps/audiobookshelf/audiobooks` |
| `data/media/music` | Navidrome `/music`, read-only |
| `data/media` | Jellyfin `/media`, read-only |
| `data/media/torrents` | qBittorrent `/data/torrents` |

Audiobookshelf's internal path is intentional: changing it can invalidate stored library references. It does not depend on the retired host dataset. See [the migration](../history/migrations.md#audiobookshelf-preserve-the-container-path).

The media directories share one ZFS filesystem. Hardlinks let a download and a library entry refer to the same stored file without keeping a second copy; they cannot cross filesystem boundaries. That requires ordinary directories in the same filesystem, including movie, TV, or torrent paths used this way. qBittorrent currently mounts only the torrents directory; a shared container `/data` layout and hardlink imports are not configured or verified here.

</details>

## qBittorrent and VPN behavior

qBittorrent sends downloads through Gluetun and PIA. This is separate from the WireGuard connection I use to access the lab remotely. The forwarding callbacks depend on localhost authentication bypass; LAN authentication needs to stay enabled, and replacement callbacks need testing before changing loopback authentication.

<details>
<summary>VPN ports, callbacks, and checks</summary>

### Ports and interfaces

qBittorrent shares Gluetun's network namespace: both containers use the same network interfaces and loopback address. Gluetun publishes the Web UI, permits its input port, and obtains a separate torrent listening port through PIA. The Web UI port and the dynamic torrent port serve different purposes.

### Port-forwarding callbacks

When VPN port forwarding starts or stops, Gluetun runs callbacks (the up/down hooks). These call qBittorrent's loopback API, selecting the VPN interface on startup and loopback on teardown. They rely on localhost authentication bypass in the shared namespace. Preserve LAN authentication, and test replacement callbacks before changing loopback authentication.

### Verification after changes

Migration checks verified VPN egress, a listening port matching PIA's assignment, and `tun0` selected. After relevant changes, also test downloads, seeding, and forwarding recovery. Check qBittorrent's actual save paths and categories alongside the Compose mounts, and preserve Gluetun/PIA forwarding and isolation. A former outbound-subnet exception was removed; new exceptions need a specific, tested purpose.

Compose environment changes take effect when TrueNAS recreates the app. Coordinate qBittorrent and Gluetun because they share the namespace, and allow for interrupted downloads. This outbound VPN is separate from [WireGuard remote access](networking.md#local-and-remote-service-access).

</details>

## Configuration and maintenance

I keep app state and secrets outside Git. The [media mounts](#media-storage) and [VPN details](#qbittorrent-and-vpn-behavior) are above. Credential values, private keys, and environment dumps stay out of documentation and diagnostic output.

<details>
<summary>Dependencies and configuration notes</summary>

| Service | State and dependencies |
| --- | --- |
| [Nextcloud](../../nextcloud/compose.yaml) | PostgreSQL 17, Valkey, cron, and a [custom FFmpeg image](../../nextcloud/Dockerfile); user files in `data/files` |
| [Immich](../../immich/compose.yaml) | PostgreSQL/VectorChord, Valkey, and OpenVINO machine learning; media in `data/photos` |
| [Vaultwarden](../../vaultwarden/compose.yaml) | PostgreSQL and persistent vault data |
| [Joplin Server](../../joplin/compose.yaml) | PostgreSQL; Joplin clients sync here |
| [Actual Budget](../../actual-budget/compose.yaml) | Persistent application state and a scheduled bank-sync job |
| [LubeLogger](../../lubelogger/compose.yaml) | PostgreSQL, application files, and data-protection keys |
| [Jellyfin](../../jellyfin/compose.yaml) | Application state and read-only shared media |
| [Audiobookshelf](../../audiobookshelf/compose.yaml) | Configuration/metadata and shared audiobooks |
| [Navidrome](../../navidrome/compose.yaml) | Application state and read-only shared music |
| [Crafty 4](../../crafty-4/compose.yaml) | Configuration, servers, imports, logs, and backups in appdata |
| [Caddy](../../caddy/compose.yaml) | Persistent CA/runtime state and the repository Caddyfile |
| [code-server](../../code-server/compose.yaml) | Persistent editor state; repository mounted at `/workspace` |
| [Open WebUI](../../open-webui/compose.yaml) | Persistent backend data; Strata runs on [Prometheus](local-ai.md); Ollama integration disabled in source |
| [SearXNG](../../searxng/compose.yaml) | External settings and cache |
| [qBittorrent + Gluetun](../../qbittorrent/compose.yaml) | Shared network namespace, VPN port forwarding, and torrent storage |

### State and external configuration

Application state lives outside Git in the [storage layout](infrastructure.md#storage-layout). Paths such as `data/files` in the tables are relative to the TrueNAS host's `/mnt/tank`; they are not repository directories.

Compose files reference external environment/secret files or mounted configuration. Start with the relevant stack to identify its required settings; inspect values locally only when needed. Keep credential values, private keys, and environment dumps out of documentation and diagnostic output.

### Check the running application

Public URLs, listen ports, proxy trust, and authentication can depend on runtime settings as well as Compose. The repository describes the intended deployment; verify the running app before changing it. PostgreSQL and cache services have no host port publications in these stacks.

Nextcloud's cron service shares the application's HTML/data mounts. Moving it requires keeping the files and database consistent with each other; old cutover comments in source describe the completed migration.

</details>

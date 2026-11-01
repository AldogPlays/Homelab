# Services and clients

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Decisions](decisions-and-lessons.md) · [Roadmap](roadmap.md)

## Deployment and access

TrueNAS Apps manages hosted services. This repository contains Compose source configurations for code-server, qBittorrent with Gluetun/PIA, SearXNG, and Caddy. Repository configuration alone does not establish which version is deployed or the current service count.

Personal devices generally use LAN access when available and Tailscale otherwise; some use Tailscale automatically. Tailscale runs on TrueNAS and client devices, with [Serve](https://tailscale.com/docs/features/tailscale-serve) providing private URLs and HTTPS where needed. Compose configurations include internal addresses and service mappings. Credentials and runtime state remain outside Git.

## Repository-managed configuration

| Source | Configuration prerequisites |
| --- | --- |
| [code-server](../code-server/compose.yaml) | External authentication file at `/mnt/tank/appdata/code-server/auth.env`; host stacks mounted at `/workspace` |
| [qBittorrent and Gluetun](../qbittorrent/compose.yaml) | External PIA credentials at `/mnt/tank/appdata/qbittorrent/pia.env`; application state and torrent data outside Git |
| [SearXNG](../searxng/compose.yaml) | Configuration and cache under `/mnt/tank/appdata/searxng`; do not commit live settings or secret keys |
| [Caddy](../caddy/compose.yaml) and [Caddyfile](../caddy/Caddyfile) | Local DNS for `test.home.arpa`, `code.home.arpa`, `search.home.arpa`, and `torrents.home.arpa`; clients must trust Caddy's internal CA for HTTPS. CA private keys and runtime storage remain outside Git |

### Caddy and SearXNG access

Caddy serves a test response at `test.home.arpa` and proxies `code.home.arpa`, `search.home.arpa`, and `torrents.home.arpa` to HTTP ports `32443`, `34053`, and `33080` respectively on `10.10.10.10`. All four sites use `tls internal`. Resolve these names to the host address and distribute only the CA public certificate to clients; keep the CA private key in external runtime storage.

The Caddy Compose file publishes TCP port 443 only. Use explicit HTTPS URLs: host port 80 is not published for HTTP redirects, and UDP port 443 is not published for HTTP/3. Verify port availability before deployment. The backend ports remain directly published; Caddy adds no authentication. SearXNG settings, secret key, public base URL, and proxy behavior must be checked in its external configuration without copying that file into Git.

### qBittorrent networking review

qBittorrent shares Gluetun's network namespace. The Web UI is published on `10.10.10.10:33080`; `FIREWALL_INPUT_PORTS` permits that port on Gluetun's default interface. PIA port forwarding separately supplies the torrent listening port. The up/down hooks call the qBittorrent API at `127.0.0.1:33080`, setting the torrent interface to the VPN interface on forwarding startup and to loopback on teardown.

The current Compose configuration removes the previous `FIREWALL_OUTBOUND_SUBNETS: 192.168.4.124/32` exception. The loopback hooks do not require it. Before deploying this change, check whether search integrations, proxies, notifications, or other application settings still depend on that address; its original purpose is unverified. Do not replace it with a broad LAN allowance. See [Gluetun firewall options](https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/firewall.md).

The current hooks follow [Gluetun's qBittorrent example](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md) and require localhost authentication bypass. This grants API access to processes in the shared network namespace. Runtime authentication settings have not been verified. Require authentication for LAN clients, avoid subnet-wide bypass, and retain CSRF and host-header protections. Do not disable localhost bypass independently of replacing and testing the hooks with authenticated requests. Keep any hook credentials and session cookies outside Git and out of command output.

The Caddyfile defines `https://torrents.home.arpa` with an HTTP upstream at `10.10.10.10:33080`. Client HTTPS requires local DNS and trust in Caddy's internal CA; it does not encrypt the upstream connection or remove direct access to the published Web UI port. Runtime Web UI settings and proxy compatibility remain unverified. Verify the active VPN interface, hook success, and forwarding recovery on a later approved deployment; the hooks do not replace Gluetun's firewall protection.

Changing the environment requires recreating Gluetun through the existing deployment mechanism; a plain container restart does not apply Compose environment changes. Coordinate qBittorrent recreation with Gluetun because it shares that namespace. This interrupts downloads. Repository edits alone do not change the running application.

## Current services

| Service | What I use it for | Clients and integrations |
| --- | --- | --- |
| [Actual Budget](https://actualbudget.org/) | Personal budgeting | Bank transaction imports through [SimpleFIN](https://bridge.simplefin.org/) |
| [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) | Reduce tracking and block sites associated with unwanted habits on personal devices | Used with Tailscale; not configured as the eero's DNS server |
| [Audiobookshelf](https://audiobookshelf.org/) | Replaces Audible for purchased audiobooks | [Lissen](https://github.com/GrakovNe/lissen-android) on Android; [OpenAudible](https://github.com/openaudible/openaudible) used to prepare purchased books for import |
| [Crafty 4](https://craftycontrol.com/) | Minecraft server for me and my girlfriend | — |
| [File Browser](https://github.com/filebrowser/filebrowser) | File management and small repairs for media applications and downloads | Jellyfin, Audiobookshelf, Navidrome, and torrent download files |
| [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) | Supports indexer searches | Works with Jackett for qBittorrent searches |
| [Immich](https://immich.app/) | Replaces Google Photos | [Immich Android app](https://github.com/immich-app/immich/tree/main/mobile); all personal devices automatically upload photos and videos |
| [Jackett](https://github.com/Jackett/Jackett) | Indexer support for qBittorrent searches | FlareSolverr and qBittorrent |
| [Jellyfin](https://jellyfin.org/) | Movies and TV obtained through qBittorrent; increasingly used by family | [AFinity](https://github.com/MakD/AFinity) on Android, preferred for its feature set |
| [LubeLogger](https://lubelogger.com/) | Truck maintenance, modifications, and fuel tracking | My [LubeLogger Android app](https://github.com/AldogPlays/LubeLogger-Android) |
| [Navidrome](https://www.navidrome.org/) | Replaces YouTube Music | [Navic](https://github.com/ssalggnikool/Navic) on Android |
| [Nextcloud](https://nextcloud.com/) | Professional, personal, and educational files; calendar, contacts, and bookmarks | Web interface, occasional [Nextcloud Android](https://github.com/nextcloud/android) file access, [DAVx5](https://github.com/bitfireAT/davx5-ose), [floccus](https://github.com/floccusaddon/floccus), and [Joplin](https://github.com/laurent22/joplin) |
| [qBittorrent](https://www.qbittorrent.org/) | Movie and TV downloads only | [qBitController](https://github.com/Bartuzen/qBitController) on Android; custom YAML with Gluetun/PIA; Jackett and FlareSolverr |
| [Tailscale](https://tailscale.com/) | Private access to all hosted services | TrueNAS app, [Tailscale Android](https://github.com/tailscale/tailscale-android) and other client apps, and Serve |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Password manager | [Bitwarden Android](https://github.com/bitwarden/android) and [browser extensions](https://github.com/bitwarden/clients) connected to the self-hosted server |

I've switched away from envelope budgeting in Actual Budget. I'm also waiting for Fidelity compatibility with SimpleFIN to return.

## Client workflows

### Files, notes, and personal information

I mostly use Nextcloud's web interface for files. On my phone, I occasionally use the Nextcloud Android app to grab a file without opening the browser and getting distracted.

My calendar and contacts sync to my [GrapheneOS](https://grapheneos.org/) phone through DAVx5, and bookmarks sync through floccus. I use Joplin for class, personal, and professional notes. I like writing in Markdown, and Nextcloud handles the sync.

### Media and photos

On Android, I listen to audiobooks with Lissen, music with Navic, and watch Jellyfin through AFinity. qBitController lets me manage qBittorrent. I used OpenAudible to import my purchased audiobooks into Audiobookshelf.

All my personal devices automatically upload photos and videos to Immich. It's replaced Google Photos for me, though I still need an independent backup of the server.

### Passwords and vehicle records

Vaultwarden is my first password manager, and I use it through Bitwarden Android and its browser extensions. For my truck, I use [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android), the client I built for my hosted LubeLogger instance.

## Planned changes

I'd like to add an *Arr stack for media later. Backups and snapshots come first; see the [roadmap](roadmap.md).

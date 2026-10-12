# Decisions and lessons

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Roadmap](roadmap.md)

## Ownership through everyday use

This lab is part of my daily routine. Immich replaced Google Photos, Navidrome replaced YouTube Music, and Audiobookshelf lets me listen to my purchased books outside Audible. Nextcloud holds my files and personal information, and Vaultwarden got me using a password manager for the first time.

I started moving these services home because I was tired of subscriptions and uncomfortable trusting large companies with so much of my data.

Self-hosting doesn't give me complete privacy. It does let me choose where more of my data lives and reduce my reliance on third parties. I still use services like SimpleFIN and PIA where they make sense for me.

The tradeoff is that maintenance and recovery are now my responsibility. Backups are the biggest gap I need to address.

## Reusing the gaming PC

I used the gaming PC I already had. I expanded its memory to 32 GB, replaced the original HDD with a mirrored pair, added a 2.5 GbE NIC, and removed the discrete GPU. The original SSD now boots TrueNAS.

It gave the machine a new purpose without replacing the whole system.

## A mirror is only part of storage protection

The two WD Red Plus drives are mirrored, with the OS on a separate SSD. The mirror provides disk redundancy, but it won't recover a deleted file or protect me from losing the whole server. I don't have independent backups or snapshots yet. Fixing that is my highest priority.

## Personal filtering without disrupting the household

I originally used AdGuard Home for the household network, but it interfered with services my family used. Now I use it with Tailscale for my own devices, and the eero doesn't use it as its DNS server.

I can reduce tracking and block sites that encourage habits I'm trying to avoid without making those choices for everyone else. That experience taught me to think about who a network change affects before applying it.

## Private access and practical clients

I generally use the LAN at home and Tailscale when it's unavailable, though some devices use Tailscale automatically. Serve gives me tailnet-only URLs and HTTPS where needed. I want to revisit the network layout more deliberately in a future refactor.

The client apps matter as much as the servers. [DAVx5](https://github.com/bitfireAT/davx5-ose) keeps my calendar and contacts on my phone, [floccus](https://github.com/floccusaddon/floccus) syncs bookmarks, and [Joplin](https://github.com/laurent22/joplin) lets me write notes in Markdown. I built [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android) for a service I actually use. The [Nextcloud Android app](https://github.com/nextcloud/android) also lets me grab a file without getting distracted in my phone's browser.

## Network capacity remains constrained

I have 2 Gb/s fiber, a 2.5 GbE switch, and a 2.5 GbE server NIC, but the eero-to-switch connection is limited to 1 Gb/s. Upgrading individual components doesn't remove every bottleneck in the path.

I'd like to find or build a custom router that can handle 2.5 Gb/s throughput. I haven't chosen the hardware or OS yet.

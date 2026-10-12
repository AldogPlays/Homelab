# Decisions and lessons

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Roadmap](roadmap.md)

## Ownership through everyday use

The lab supports daily activities rather than existing only as an experiment. Immich replaces Google Photos, Navidrome replaces YouTube Music, and Audiobookshelf replaces Audible for my purchased library. Nextcloud holds files and synchronized personal information, while Vaultwarden introduced password management into my routine.

Recurring subscription payments and trusting large companies with important personal data were the reasons I started moving these workflows home. I wanted ownership and control over my data and the tools used to access it.

I do not treat self-hosting as a guarantee of complete privacy. It lets me take smaller steps to reduce reliance on third parties and feel more comfortable with where my data lives. Services such as SimpleFIN and PIA still have a role in the setup.

That control also makes recovery and maintenance my responsibility. The current lack of independent backups is a significant unfinished part of that responsibility.

## Reusing the gaming PC

The existing machine provided the foundation for TrueNAS. I expanded memory to 32 GB, replaced the original HDD with a mirrored pair, added a 2.5 GbE NIC, and removed the discrete GPU. The boot SSD remains in use.

This documents a practical hardware conversion. Power consumption, performance benchmarks, and hardware transcoding configuration have not been measured or recorded here.

## A mirror is only part of storage protection

The two WD Red Plus drives are mirrored, with the OS on a separate SSD. That provides disk redundancy in the data pool, but no independent backups or snapshots are configured. I have identified backup and snapshot implementation as the highest-priority improvement; no recovery testing has been claimed.

## Personal filtering without disrupting the household

Using AdGuard Home for the family's network previously interfered with their services and network use. The current approach uses it with Tailscale for my personal devices, while the eero does not use it as its DNS server.

The lesson is to consider everyone affected by a network change. Restricting filtering to my devices preserves the personal goals of reducing tracking and avoiding unwanted habits without imposing those choices on the household.

## Private access and practical clients

LAN access and Tailscale let me use the same services at home and away. Serve provides tailnet-only URLs and HTTPS where needed. A more deliberate networking refactor is planned; current Serve mappings remain undocumented by service.

Dedicated clients make the services useful in daily life: [DAVx5](https://github.com/bitfireAT/davx5-ose) for calendar and contacts, [floccus](https://github.com/floccusaddon/floccus) for bookmarks, [Joplin](https://github.com/laurent22/joplin) for Markdown notes, and Android clients for media. I also built and use [LubeLogger-Android](https://github.com/AldogPlays/LubeLogger-Android) with my own server. The [Nextcloud Android app](https://github.com/nextcloud/android) gives occasional file access while helping me avoid using the phone browser.

## Network capacity remains constrained

The lab has a 2.5 GbE switch and an added 2.5 GbE server NIC, but the current eero setup is reported to limit the wired router path to 1 Gb/s despite a 2 Gb/s fiber service. Component ratings alone do not establish end-to-end throughput.

A custom router is planned. Its design and measured performance are future work, not present accomplishments.

## What this document does not yet establish

Detailed troubleshooting timelines, benchmark results, restore procedures, and validated security policies have not been supplied. Future entries should capture the actual problem, evidence, change, and outcome when that work occurs.

# Roadmap

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Decisions](decisions-and-lessons.md)

These are the changes I want to make next. Backups come first; the rest doesn't have a fixed order or timeline.

## Highest priority: backups and snapshots

The HDD pool is mirrored, but I currently have **no independent backups or snapshots**.

I need to decide what to back up, where to store it, and how long to keep it. I also want snapshots and a recovery process I can test. I'll document those choices and restore results as I put them in place.

## Networking

- Find or build a custom router capable of 2.5 Gb/s throughput.
- Possibly use the eero solely as a wireless access point.
- Revisit the broader homelab network design during a future refactor.

My spare older router only has 1 GbE ports, so it doesn't meet the throughput goal. I haven't chosen a replacement or custom OS. Reviewing the current Serve setup can wait until the broader refactor.

## Services and integrations

- Add an *Arr stack for media; I haven't chosen the components yet.
- Connect Fidelity through [SimpleFIN](https://bridge.simplefin.org/) when compatibility returns.

## Documentation follow-ups

- Add hardware photos without personal or network details in view.
- Add the dataset and application storage layout.
- Record troubleshooting work and what I learned from it.

I'm not planning more server hardware upgrades right now.

## Keeping the record accurate

As I finish changes, I'll update the relevant docs and remove them from this list. Credentials, personal data, private addresses, and internal service mappings stay out of the public repository.

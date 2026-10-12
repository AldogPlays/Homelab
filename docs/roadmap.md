# Roadmap

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Decisions](decisions-and-lessons.md)

Everything below is **planned or unresolved**, not an implemented feature. There are no committed deadlines, and only backup/recovery work has a confirmed priority.

## Highest priority: backups and snapshots

Current state: the HDD data pool is mirrored, but there are **no independent backups or snapshots**.

The intended improvement is a better backup system and snapshot strategy. Backup destinations, scope, schedules, retention, and recovery procedures have not yet been chosen. Those decisions and evidence of successful recovery should be documented as implementation progresses.

## Networking

- Find or build a custom router capable of 2.5 Gb/s throughput.
- Possibly use the eero solely as a wireless access point.
- Revisit the broader homelab network design during a future refactor.

The current spare older router has 1 GbE ports. No custom OS installation, router selection, or future topology has been confirmed. Current Serve port-to-service mappings are left unresolved for now.

## Services and integrations

- Integrate an *Arr stack into the media workflow; components and deployment details remain undecided.
- Resume Fidelity integration through SimpleFIN if compatibility returns. This is dependent on external compatibility, not a completed integration.

## Documentation follow-ups

- Add real hardware photos when available and reviewed for public sharing.
- Confirm the exact Actual Budget mode name if useful for future documentation.
- Expand implementation and troubleshooting notes as actual work is completed.

No additional TrueNAS server hardware upgrades are currently planned.

## Keeping the record accurate

When an improvement is implemented, update the relevant infrastructure or service document and record the decision and observed outcome. Move it out of this roadmap only when it is actually in use. Keep credentials, personal data, network addresses, tailnet identifiers, and internal service mappings out of public changes.

# Operations

> [Homelab](../README.md)

These are my notes for checking apps, working in the right shell, and deploying an approved change. Each command says where it runs. The container names are examples, so check them against the running setup.

## Start here

| Task or symptom | Procedure |
| --- | --- |
| Find a file in the right shell | [Host and container paths](#find-the-right-path) |
| Check an app's status, mounts, or configuration | [Inspect a TrueNAS app](#inspect-a-truenas-app) |
| Prepare and deploy a change | [Deployment workflow](#deployment-workflow) |
| Caddy cannot see an edited route | [Compare host and container files](troubleshooting.md#caddy-route-present-on-host-but-missing-in-container) |
| Nextcloud rejects a hostname or IP | [Check allowed hosts](troubleshooting.md#nextcloud-untrusted-domain) |
| Open WebUI refuses connections after deployment | [Check startup](troubleshooting.md#open-webui-startup-connection-refused) |
| A long media transfer stopped | [Interrupted media copy](troubleshooting.md#interrupted-media-copy) |
| An application cannot access its files | [Storage permissions](troubleshooting.md#storage-permissions) |
| Git authentication fails | [Git authentication](#git-authentication) |
| Strata is healthy but its API is unreachable | [Prometheus diagnostics](troubleshooting.md#prometheus-healthy-container-unreachable-api) |
| Open WebUI shows replies late | [Compare backend and browser timing](troubleshooting.md#open-webui-replies-appear-late) |
| Recover a database | [PostgreSQL recovery](postgres-recovery.md) |

Use [backups](backups.md#check-the-setup) to check protection jobs and [networking](networking.md) for the address/DNS reference.

## Find the right path

| Context | Repository | Application state |
| --- | --- | --- |
| TrueNAS host | `/mnt/tank/stacks` | `/mnt/tank/appdata/<app>` |
| code-server | `/workspace` | Its own persistent state is `/config` |
| Caddy container | Caddyfile at `/etc/caddy/Caddyfile` | `/data` and `/config` |
| Prometheus AI host | Strata Compose at `/srv/ai/strata/compose.yaml` | `/srv/ai/strata/data` |

A host path and a container path can name the same underlying files differently. For example, `/mnt/tank/stacks/caddy/Caddyfile` on TrueNAS appears as `/workspace/caddy/Caddyfile` in code-server and `/etc/caddy/Caddyfile` in Caddy.

`/workspace` is a code-server mount, not a TrueNAS host path. A missing path in the wrong shell does not establish that the host file is missing.

<details>
<summary>Listing root-protected backup directories</summary>

Root-protected backup paths also need care: the shell expands wildcards before `sudo` runs. During backup setup, `sudo ls /mnt/tank/backups/databases/*` failed with zsh's `no matches found` even though the directories existed. Inspect them without a shell wildcard:

```bash
# TrueNAS host
sudo find /mnt/tank/backups/databases \
  -mindepth 1 -maxdepth 1 -type d -printf '%f  %m  %u:%g\n'
```

</details>

## Inspect a TrueNAS app

These checks show an app's status, image, user, mounts, and Compose validity. They do not deploy it. Full environment dumps and unreviewed request logs can expose credentials or session tokens.

<details>
<summary>App inspection commands</summary>

Run these commands on the **TrueNAS host**, replacing the example app/container names as appropriate:

```bash
sudo docker ps --filter name=ix-navidrome \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

sudo docker inspect ix-navidrome-navidrome-1 \
  --format 'Image: {{.Config.Image}} | User: {{.Config.User}}'

sudo docker inspect ix-navidrome-navidrome-1 \
  --format '{{range .Mounts}}{{println .Source " -> " .Destination}}{{end}}'

sudo docker compose -f /mnt/tank/stacks/navidrome/compose.yaml config --quiet
```

These inspect status, selected metadata, mounts, and Compose validity. They do not deploy the source file. Avoid sharing full environment dumps or unreviewed request logs, which can include credentials or session tokens.

</details>

## Deployment workflow

I deploy apps through TrueNAS **Apps → Install via YAML**, using an include that points to the Compose file on disk:

```yaml
include:
  - path: /mnt/tank/stacks/<app>/compose.yaml
```

The placeholder must be replaced with the app directory. Keep app directories at their established repository paths so includes continue to resolve.

Use the TrueNAS WebUI, CLI, or API for system configuration; avoid editing appliance-managed system files directly.

I keep documentation edits separate from deployment work. Changing Compose, Dockerfiles, Caddy configuration, maintenance scripts, or live infrastructure requires explicit approval.

<details>
<summary>Deployment checks</summary>

### For an authorized deployment change

1. Inspect the current image, ports, service identity, mounts, database dependencies, and data.
2. Read the relevant Compose source and identify required external settings without printing credentials.
3. Prepare an application-consistent backup and validate the proposed configuration and permissions.
4. Deploy through TrueNAS, then verify application behavior and persistence.
5. For migrations, retain the previous state until the replacement is verified.

The `tank/Apps` migration is complete, and that dataset has been deleted. Use current backups for recovery. The [migration history](migrations.md) describes what was retained, reset, and retired.

</details>

## Git authentication

I use the checkout's existing authentication. In code-server, that is a persistent SSH deploy key selected by repository-local `core.sshCommand`. Other environments can have their own HTTPS authentication without changing this checkout. An explicit SSH override once bypassed the working key selection and caused `Permission denied (publickey)`.

<details>
<summary>Git checks and credential precautions</summary>

Inspect repository state in **code-server**:

```bash
git -C /workspace status --short --branch
git -C /workspace diff --check
```

Preserve working credential helpers and SSH configuration. If authentication fails, inspect the relevant local configuration without sharing key contents or credential-bearing URLs. Review explicit file diffs before committing; `.gitignore` cannot detect a secret embedded inside a tracked file.

</details>

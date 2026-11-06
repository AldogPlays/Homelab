# Local AI

> [Homelab](../../README.md) · [Documentation](../README.md)

I use Open WebUI on TrueNAS to chat with a model running on Prometheus. Strata does the model work on Prometheus's AMD GPU. I'm running `qwen3.8-flash-next-q2_0` with a 65,536-token (64K) context window, and I've checked that it starts after a reboot.

## Serving layout

```mermaid
flowchart LR
    Client["Browser"] --> UI["Open WebUI<br/>TrueNAS"]
    UI -->|OpenAI-compatible API| Strata["Strata · AMD GPU<br/>Prometheus"]

    classDef host fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    class UI,Strata host
```

<details>
<summary>API and model settings</summary>

Open WebUI connects to Strata through `/v1/models` and `/v1/chat/completions`. The [WebUI stack](../../open-webui/compose.yaml) persists its backend data, disables Ollama integration, and is served through Caddy. [Networking](networking.md) covers client access and Ethernet/Wi-Fi routing; [infrastructure](infrastructure.md#prometheus-ai-host) records the hardware.

Here, “OpenAI-compatible” describes the API format used between the two services. Strata performs the inference on Prometheus. `/v1/models` lists available models, and `/v1/chat/completions` accepts chat requests.

Three settings describe different parts of this setup:

| Term | Meaning here |
| --- | --- |
| Q2_0 | The quantization label for the model being served. Quantization stores model weights at reduced precision; the recorded benchmark does not compare its quality with other quantizations. |
| 64K context | The configured token window for a request. Tokens are chunks of text, so 65,536 tokens is not a word count. A configured window does not establish how well the model uses all of it. |
| Thinking enabled | The model generates reasoning as well as visible answer text. That reasoning consumes generated tokens and time before or alongside the answer. |

</details>

## Performance reference

I have one recorded performance baseline: the [standard Q2_0 benchmark](../benchmarks/q2-0.md). That page has the timings, output limits, sanity checks, exact run settings, and command. It measures Strata directly, not the browser experience.

## Runtime and maintenance

These are the versions and settings I recorded during setup. Strata uses a moving image tag, so the running version needs checking after updates. I keep its full Compose file on Prometheus, outside this repository.

<details>
<summary>Versions, paths, and container settings</summary>

| Item | Configuration |
| --- | --- |
| Host OS / kernel | Ubuntu Server 26.04.1 LTS / `7.0.0-42-generic` |
| Docker / Compose | Docker CE 29.9.2 / Compose 5.7.0 at installation |
| Strata image / engine | `ghcr.io/niko1221/strata:latest-rocm-gfx110x` / engine 0.1.55 HIP in logs |
| Model / context | `qwen3.8-flash-next-q2_0` / 65,536 tokens |
| Capabilities | Text-only; vision disabled; Bearer API authentication |
| OpenAI-compatible base URL | `http://10.10.10.20:8080/v1` |

### Storage and configuration

| Prometheus path | Role |
| --- | --- |
| `/srv/ai/strata/compose.yaml` | Host-side deployment definition |
| `/srv/ai/strata/data` | Models, packed experts, draft layers, and runtime state; mounted at `/data` |
| `/etc/systemd/system/strata-compose.service` | Host-managed Compose startup unit |

The dedicated logical volume (LV), formatted with ext4, is mounted persistently at `/srv/ai`; the remaining volume-group space was left unallocated.

Engine logs are at `/data/state/strata/launch/docker.engine.log` inside the container. Authentication is supplied through an existing protected mount referenced by the host-side configuration; keep its contents out of logs and documentation.

The recorded container settings are:

| Area | Settings |
| --- | --- |
| Model selection | `FAMILY: qwen`, `MODEL: Q2_0` |
| Context and input | `CONTEXT: "64k"`, `VISION: "off"` |
| Authentication | `API_KEY_FILE` references the mounted credential file |
| AMD GPU access | `/dev/kfd`, `/dev/dri`, and video/render groups `44` and `991` |
| Memory | 2 GB shared memory; unlimited memlock |
| Shutdown and logs | 120-second stop grace period; bounded JSON-file logs |
| API publication | Ethernet address, TCP 8080 |

The 64K setting allocates context space. The standard suite's longest performance prompt was approximately 16K, so the recorded benchmark does not establish full-window answer quality.

</details>

### Startup and diagnostics

The systemd unit waits for the reserved Ethernet address on `enp13s0`, then invokes Compose with `up -d --force-recreate`. Both manual startup and startup after reboot have succeeded.

I haven't verified recovery after a hardware power outage or from a process that stays running but becomes unhealthy. Those are separate from the successful reboot test.

For a healthy model with an unreachable host API, use [Prometheus diagnostics](../operations/troubleshooting.md#prometheus-healthy-container-unreachable-api). For responses that appear late in the browser, compare backend completion with [Open WebUI timing](../operations/troubleshooting.md#open-webui-replies-appear-late).

I recorded the Windows-to-Ubuntu move, SMT fix, and Netplan changes in the [migration notes](../history/migrations.md#prometheus-move-to-ubuntu). The full systemd, fstab, and Netplan settings are not documented here. Routine maintenance checks include Ubuntu updates and hardware power-recovery settings.

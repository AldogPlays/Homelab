# Local AI

> [Homelab](../README.md)

I use Open WebUI on TrueNAS to chat with a model running on Prometheus. Strata does the model work on Prometheus's AMD GPU. I use Coder IQ1_M with a 65,536-token (64K) context window.

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

Open WebUI connects to Strata through `/v1/models` and `/v1/chat/completions`. The [WebUI stack](../open-webui/compose.yaml) persists its backend data, disables Ollama integration, and is served through Caddy. [Networking](networking.md) covers client access and Ethernet/Wi-Fi routing; [infrastructure](infrastructure.md#prometheus-ai-host) records the hardware.

Here, “OpenAI-compatible” describes the API format used between the two services. Strata performs the inference on Prometheus. `/v1/models` lists available models, and `/v1/chat/completions` accepts chat requests.

Three settings describe different parts of this setup:

| Term | Meaning here |
| --- | --- |
| Coder IQ1_M | The model and quantization I use; I previously used Q2_0. Quantization stores model weights at reduced precision. The timings and sanity fixtures do not establish broad quality differences between them. |
| 64K context | The configured token window for a request. Tokens are chunks of text, so 65,536 tokens is not a word count. A configured window does not establish how well the model uses all of it. |
| Thinking enabled | The model generates reasoning as well as visible answer text. That reasoning consumes generated tokens and time before or alongside the answer. |

</details>

## Performance reference

I ran six standard benchmarks on November 5–6. All six passed **12/12 sanity checks**, with zero failed or skipped required requests. **My baseline is Coder IQ1_M with `KV=int8`, `spec=4`, and RAM-resident experts.**

| Workload | Fresh Q2_0: first token, s | Coder IQ1_M: first token, s | Coder decode, tokens/s |
| --- | ---: | ---: | ---: |
| Short | 1.33 | 1.06 | 50.3 |
| 4K prompt | 22.74 | 8.92 | 48.2 |
| 16K prompt | 83.70 | 33.71 | 45.6 |

I ran each workload three times through the container-loopback API; the table shows medians without Open WebUI overhead. I got about 2.5× faster long-prompt first-token latency with Coder. I changed the model and expert-residency mode together, so I can’t isolate one cause.

I found no clear improvement with `k8v4`, `spec=2`, or quick and thorough tuning, so I kept my baseline. Performance requests had a **512-token reasoning-plus-answer cap**, often reached on long prompts. The sanity checks and timings do not establish broad answer quality or full-window 64K performance.

I keep all six runs, tuning results, and report paths in my [benchmark notes](benchmarks.md), alongside the original Q2_0 timings and settings.

## Runtime and maintenance

I keep the versions and settings from setup below. Strata uses a moving image tag, so I check the running version after updates. Its full Compose file stays on Prometheus, outside this repository.

<details>
<summary>Versions, paths, and container settings</summary>

| Item | Configuration |
| --- | --- |
| Host OS / kernel | Ubuntu Server 26.04.1 LTS / `7.0.0-42-generic` |
| Docker / Compose | Docker CE 29.9.2 / Compose 5.7.0 at installation |
| Strata image / engine | `ghcr.io/niko1221/strata:latest-rocm-gfx110x` / engine 0.1.55 HIP in logs |
| Model / context | Qwen3.8-Flash-Next Coder IQ1_M / 65,536 tokens |
| Inference settings | `KV=int8`, `spec=4`, `--resident-experts` |
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

These are the container settings I used with Q2_0. I keep the active Coder configuration on Prometheus; the model and inference settings I settled on are above:

| Area | Settings |
| --- | --- |
| Model selection | `FAMILY: qwen`, `MODEL: Q2_0` |
| Context and input | `CONTEXT: "64k"`, `VISION: "off"` |
| Authentication | `API_KEY_FILE` references the mounted credential file |
| AMD GPU access | `/dev/kfd`, `/dev/dri`, and video/render groups `44` and `991` |
| Memory | 2 GB shared memory; unlimited memlock |
| Shutdown and logs | 120-second stop grace period; bounded JSON-file logs |
| API publication | Ethernet address, TCP 8080 |

The 64K setting allocates context space. The standard suite's longest performance prompt was approximately 16K, so I haven’t tested answer quality across the full window.

</details>

### Startup and diagnostics

The systemd unit waits for the reserved Ethernet address on `enp13s0`, then invokes Compose with `up -d --force-recreate`. I checked manual startup and startup after reboot with Q2_0. I haven’t repeated the reboot test since switching to Coder.

I haven't verified recovery after a hardware power outage or from a process that stays running but becomes unhealthy. Those are separate from the successful reboot test.

For a healthy model with an unreachable host API, use [Prometheus diagnostics](troubleshooting.md#prometheus-healthy-container-unreachable-api). For responses that appear late in the browser, compare backend completion with [Open WebUI timing](troubleshooting.md#open-webui-replies-appear-late).

I describe the Windows-to-Ubuntu move, SMT fix, and Netplan changes in my [migration notes](migrations.md#prometheus-move-to-ubuntu). The full systemd, fstab, and Netplan settings are not documented here. Routine maintenance checks include Ubuntu updates and hardware power-recovery settings.

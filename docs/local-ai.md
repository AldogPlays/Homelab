# Local AI

[Overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md) · [Operations](operations.md) · [Roadmap](roadmap.md)

Prometheus runs Strata inference on a dedicated AMD machine; Open WebUI runs on TrueNAS. The machine moved from Windows to bare-metal Ubuntu Server in early November 2026. It serves Q2_0 with 64K context, prefers Ethernet with Wi-Fi fallback, and starts successfully after reboot. The completed standard Q2_0 run below is the benchmark baseline.

## Ubuntu deployment

| Item | Configuration and setup versions |
| --- | --- |
| Host / login user | `prometheus` |
| OS / kernel | Ubuntu Server 26.04.1 LTS / `7.0.0-42-generic` |
| CPU | Ryzen 7 7800X3D, 8 cores / 16 threads after firmware troubleshooting |
| GPU | PowerColor RX 7800 XT, 16 GiB VRAM; `amdgpu`, HIP/ROCm inference |
| Memory | 32 GB DDR5, about 29 GiB usable; 8 GiB swap |
| Storage | 2 TB nominal NVMe; 100 GB root LV, dedicated 1 TB ext4 LV mounted at `/srv/ai` |
| Ethernet | Intel I225-V, `enp13s0`, 2.5 Gb/s full duplex; DHCP reservation `10.10.10.20/24` |
| Route preference | Ethernet metric 100, Wi-Fi metric 600; gateway `10.10.10.1` |
| Docker / Compose | Docker CE 29.9.2 / Compose 5.7.0 at installation |
| Strata image / engine | `ghcr.io/niko1221/strata:latest-rocm-gfx110x` / engine 0.1.55 HIP in logs |
| Model / context | `qwen3.8-flash-next-q2_0`, 65,536-token allocation |
| Capabilities | Text-only; vision disabled; Bearer API authentication |
| OpenAI-compatible base URL | `http://10.10.10.20:8080/v1` |

The image uses a moving tag; check the running engine version after updates. The 64K setting allocates context space. The benchmark below tests inputs up to approximately 16K tokens and does not measure answer quality across the full window.

## Storage and configuration

| Prometheus path | Role |
| --- | --- |
| `/srv/ai/strata/compose.yaml` | Host-side deployment definition; not present as a stack in this repository |
| `/srv/ai/strata/data` | Models, packed experts, draft layers, and runtime state; mounted at `/data` |
| `/srv/ai/strata/secrets/api_key` | Protected API credential; mounted read-only at `/run/secrets/strata_api_key` |
| `/etc/systemd/system/strata-compose.service` | Host-managed Compose startup unit |
| `/data/state/strata/launch/docker.engine.log` | Engine log path inside the container |

The dedicated LV is `/dev/ubuntu-vg/ai-data`, mounted persistently at `/srv/ai` through fstab. The mount survives reboots. The remaining volume-group space was left unallocated.

Strata is configured with `FAMILY: qwen`, `MODEL: Q2_0`, `CONTEXT: "64k"`, `VISION: "off"`, and `API_KEY_FILE`. The container receives `/dev/kfd` and `/dev/dri`, adds video/render groups `44` and `991`, and uses 2 GB shared memory, unlimited memlock, a 120-second stop grace period, and bounded JSON-file logs. The host binding is `10.10.10.20:8080:8080`. The full Compose definition lives on Prometheus at the path above.

## Open WebUI connection

Open WebUI connects to Strata's Q2_0 model through its OpenAI-compatible API, including `/v1/models` and `/v1/chat/completions`.

The [Open WebUI stack](../open-webui/compose.yaml) specifies version `v0.13.0`, host port `30070`, persistent data under `appdata/open-webui/data`, an external secret file, and disabled Ollama integration. Caddy serves it at `open-webui.home.arpa`.

During initial use, some replies appeared delayed in Open WebUI while backend requests had already completed. The cause was not isolated. When troubleshooting a similar delay, compare backend completion with visible answer timing; reasoning and tool activity can precede the final answer.

## Firmware, networking, and startup

Linux initially exposed 8 threads with SMT reported as `notsupported`. The kernel command line contained no explicit `nosmt`. A BIOS change restored 8 cores / 16 threads and SMT `on`. Gigabyte X3D Turbo Mode was a suspected cause; the specific firmware setting responsible remains uncertain.

Ethernet initially had link but no IPv4 DHCP setting in Netplan. Enabling DHCP and moving the `.20` reservation to the Ethernet adapter established access. Wi-Fi initially retained the preferred route; lowering Ethernet's metric to 100 made it preferred while Wi-Fi remained at 600. The Netplan trial was accepted, and these route preferences remain in use.

During the initial reboot/network changes, Strata sometimes stopped or lost active port publication even though Docker retained its desired binding. Recreating the container restored publication. The systemd unit now waits for `10.10.10.20` on `enp13s0`, then invokes Compose with `up -d --force-recreate`. Both a manual service start and startup after reboot have been tested successfully.

For inspection commands and the distinction between model loading and missing publication, see [operations](operations.md#prometheus-healthy-container-unreachable-api). Hardware recovery after a power outage and recovery from an unhealthy-but-running process still need separate verification.

## Q2_0 standard benchmark

I ran the standard suite against Q2_0 at 64K context. The run completed with **zero failed requests** and **12/12 sanity checks passed**. These results are the performance baseline for this setup.

| Item | Benchmark configuration |
| --- | --- |
| Started | 2026-11-05 05:44:24 UTC; November 4, 21:44:24 Pacific |
| Run ID | `20261105T054424Z-1e39bba3` |
| Protocol | `strata-qwen38-thinking-v1-draft.1`, draft; `standard-v1` suite |
| Strata commit | `c62d5e3a15b40ea51c96aae9e8d36928965f53ab` |
| Engine / build | 0.1.55 / release |
| Model / quantization | `qwen3.8-flash-next-q2_0` / Q2_0 |
| Context / capacity | 65,536 tokens / one serving slot |
| Track | `custom`; no additional track notes |
| Sampling | Temperature 1.0; top_p 0.95; top_k 20; min_p 0; presence penalty 0; repetition penalty 1.0 |
| Reasoning | `xhigh`, thinking enabled and preserved |
| Duration after model loading | 20 minutes 42 seconds, as reported by the runner |
| Host | Ryzen 7 7800X3D, RX 7800 XT 16 GiB from the host inventory; runner reported generic `AMD Radeon` and 30.0 GiB RAM |
| Host OS | Ubuntu 26.04.1 LTS, from host `/etc/os-release` |
| Runner environment | Inside Docker: Ubuntu 24.04.5 LTS; kernel `7.0.0-42-generic` |

The benchmark ran inside Docker, so its Ubuntu 24.04.5 label describes the container userspace. The Prometheus host runs Ubuntu 26.04.1. The runner reads its local `/etc/os-release`; see the [OS-probe source](https://github.com/Niko1221/Strata/blob/main/strata_cli/bench_facts.py).

### Performance

Values are medians with minimum–maximum ranges. Each performance case has three samples, except 16K first-answer latency, which has two.

| Case | Prompt tokens/s | Decode tokens/s | First token, s | First answer, s | Total, s | Capped |
| --- | --- | --- | --- | --- | --- | --- |
| Short | Not reported | 49.7 (39.4–64.0) | 1.41 (0.85–1.52) | 2.89 (2.81–9.33) | 11.1 (8.0–13.4) | 1/3 |
| 4K prompt | 167.3 (121.4–215.6) | 36.5 (30.9–53.2) | 24.50 (19.01–33.77) | 29.09 (25.43–46.69) | 34.1 (33.0–50.3) | 3/3 |
| 16K prompt | 208.5 (158.9–322.2) | 44.5 (29.3–49.6) | 78.66 (50.92–103.23) | 70.16 (58.38–81.94) | 96.1 (62.4–113.5) | 3/3 |

Generation reached median rates of 36.5–49.7 tokens/s across the three cases. Longer inputs incurred substantial startup latency: median first-token time was 24.50 seconds at 4K and 78.66 seconds at 16K. These are loopback API measurements, including reasoning; they do not measure Open WebUI overhead.

The short prompt was about 80 tokens, so the report omits its prompt-processing rate because fixed request overhead dominates. The 16K first-answer median uses a different sample count from its first-token median: one request produced no visible answer before the cap. The two medians therefore are not a paired timing comparison.

### Output caps and sanity checks

Each performance request could generate at most **512 tokens, including reasoning and visible answer text**. Reaching that cap is an expected benchmark boundary and is labeled `truncated`; total duration then measures time to the cap, not time to a complete answer. It does not reduce the configured 64K context or establish a model output limit. See the [protocol's truncation rules](https://github.com/Niko1221/Strata/blob/main/docs/BENCHMARK_PROTOCOL.md).

| Phase | Planned | Completed without cap | Truncated | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: | ---: |
| Warm-up | 1 | 0 | 1 | 0 | 0 |
| Performance | 9 | 2 | 7 | 0 | 0 |
| Sanity | 12 | 12 | 0 | 0 | 0 |
| Concurrency | 0 | 0 | 0 | 0 | 0 |

All four instruction checks, four retrieval checks, and four tool-call checks passed. This verifies those twelve fixtures; it is not a broad intelligence or coding-quality score. No concurrency test was run, and the longest performance input was approximately 16K, not the full 64K allocation.

### Artifacts and limits

The original files remain on Prometheus, outside this repository:

```text
/srv/ai/strata/data/benchmarks/q2_0-20261105T054344Z/
├── README.md
├── config.json
├── outputs.jsonl
├── provenance/
└── results.json
```

The tables above summarize the generated benchmark README. Full request traces, configuration, and provenance remain in the artifact directory. The report files are root-owned, mode `600`; read them with `sudo` rather than changing their permissions.

The report identifies two split GGUF files, with abbreviated hash prefixes `69820c02ec7d0b45…` and `316b46f3a2dbd68c…`; complete hashes belong to the original artifacts. Model/source revisions, driver/runtime versions, storage characteristics, and background work were not measured. The server had answered one request before the run. Shared template-prefix and expert-cache state remained warm and evolved during the test, so this is not a cold-model measurement.

Reaching the output cap does not invalidate this baseline. If repeating the fixed suite, restart the engine between runs as required by the protocol to avoid reusing prompt state.

### Run command

Connect with `ssh prometheus@10.10.10.20`, leave other inference clients idle, and run:

```bash
sudo docker exec -it strata sh -ec '
  strata bench run --help >/dev/null
  export STRATA_API_KEY="$(cat /run/secrets/strata_api_key)"
  exec strata bench run \
    --url http://127.0.0.1:8080 \
    --no-start \
    --out "/data/benchmarks/q2_0-$(date -u +%Y%m%dT%H%M%SZ)"
'
```

This uses the running model through container loopback, reads authentication from its existing mounted file, and saves reports in persistent storage. `--no-start` prevents the runner from launching another engine. The help check stops the block if the installed CLI lacks the benchmark command. Command behavior and authentication are documented in [terminal commands](https://github.com/Niko1221/Strata/blob/main/docs/TERMINAL.md).

The output directory inside the container maps to `/srv/ai/strata/data/benchmarks/` on Prometheus. Retain the generated README, JSON, and supporting files together. Review the report before publishing. The reported 20 minutes 42 seconds applies to this run after model loading; it is not a universal duration estimate.

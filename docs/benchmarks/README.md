# Local AI benchmark history

> [Homelab](../../README.md) · [Documentation](../README.md) · [Local AI](../setup/local-ai.md)

Six recorded Strata standard runs compare Q2_0 with Coder IQ1_M on Prometheus. **Coder IQ1_M with `KV=int8`, `spec=4`, and RAM-resident experts is the latest recorded baseline.** The [original Q2_0 report](q2-0.md) preserves its full timings and provenance.

This page combines the existing repository baseline with `strata_benchmarks_summary_2026-11-06.md`, a conversation-derived summary through November 6, 2026. These are historical observations; the later raw reports were not supplied with the summary. Run-folder timestamps use UTC; the original November 5 UTC run occurred November 4 Pacific.

## Standard runs

All runs used the Ryzen 7 7800X3D, Radeon RX 7800 XT with 16 GiB VRAM, approximately 30 GiB usable RAM, Strata engine 0.1.55, and a 65,536-token context. The runner's Ubuntu 24.04.5 label describes its container; the host runs Ubuntu 26.04.1. Requests used the container-loopback API against an already running server, excluding Open WebUI overhead.

| Run | Folder under `/data/benchmarks/` | Configuration | Reported duration |
| --- | --- | --- | --- |
| 1 · Original Q2_0 | `q2_0-20261105T054344Z/` | Q2_0, `KV=int8`, file-mapped experts | 20m 42s |
| 2 · Q2_0 repeat | `q2_0-20261105T204647Z/` | Q2_0, file-mapped experts | 25m 20s |
| 3 · Q2_0 fresh | `q2_0-fresh-20261105T214750Z/` | Same Q2_0 configuration after Compose restart | 19m 56s |
| 4 · Coder baseline | `coder-iq1_m-20261105T224226Z/` | Coder IQ1_M, `KV=int8`, `spec=4`, RAM-resident experts | 5m 36s |
| 5 · Coder KV trial | `coder-iq1_m-k8v4-20261106T015430Z/` | Coder IQ1_M, `KV=k8v4`, `spec=4` | 5m 34s |
| 6 · Coder speculation trial | `coder-iq1_m-spec2-20261106T021836Z/` | Coder IQ1_M, `KV=int8`, `spec=2` | 5m 40s |

Every run passed **12/12 sanity checks** (four instruction, four retrieval, four tool-call fixtures), with zero failed or skipped required requests. Runs 2–6 each reported 21/21 required requests. The original run's phase accounting is preserved in the [original report](q2-0.md#output-caps-and-sanity-checks); its required-request total was not recorded in the new summary.

Compared with fresh Q2_0, the Coder baseline reduced median 4K time to first token from **22.74 to 8.92 seconds** and 16K from **83.70 to 33.71 seconds**, about 2.5× faster in both cases. Reported suite duration fell from 19m 56s to 5m 36s. The model and expert-residency mode changed together, so these runs do not isolate either one's contribution.

<details>
<summary><strong>Median performance for all six runs</strong></summary>

Each workload has three repetitions. Prompt and decode rates are tokens/second; TTFT is client time to first token. Short prompts are about 80 tokens, so their prompt-processing rate is omitted. Total time includes capped completions.

| Run | Workload | Prompt tok/s | Decode tok/s | TTFT, s | Total, s | Hit 512-token cap |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 · Original Q2_0 | Short | — | 49.7 | 1.41 | 11.1 | 1/3 |
| 1 · Original Q2_0 | 4K | 167.3 | 36.5 | 24.50 | 34.1 | 3/3 |
| 1 · Original Q2_0 | 16K | 208.5 | 44.5 | 78.66 | 96.1 | 3/3 |
| 2 · Q2_0 repeat | Short | — | 49.3 | 1.78 | 9.5 | 0/3 |
| 2 · Q2_0 repeat | 4K | 98.4 | 32.3 | 41.61 | 59.2 | 2/3 |
| 2 · Q2_0 repeat | 16K | 165.8 | 51.1 | 98.93 | 107.8 | 3/3 |
| 3 · Q2_0 fresh | Short | — | 60.5 | 1.33 | 8.0 | 0/3 |
| 3 · Q2_0 fresh | 4K | 180.3 | 48.6 | 22.74 | 30.7 | 2/3 |
| 3 · Q2_0 fresh | 16K | 195.9 | 55.2 | 83.70 | 97.3 | 2/3 |
| 4 · Coder baseline | Short | — | 50.3 | 1.06 | 8.3 | 0/3 |
| 4 · Coder baseline | 4K | 460.3 | 48.2 | 8.92 | 19.6 | 3/3 |
| 4 · Coder baseline | 16K | 486.7 | 45.6 | 33.71 | 44.9 | 3/3 |
| 5 · Coder KV trial | Short | — | 51.0 | 1.03 | 7.9 | 0/3 |
| 5 · Coder KV trial | 4K | 458.6 | 46.3 | 8.96 | 19.9 | 3/3 |
| 5 · Coder KV trial | 16K | 487.7 | 46.6 | 33.64 | 44.5 | 3/3 |
| 6 · Coder speculation trial | Short | — | 48.3 | 1.07 | 8.2 | 1/3 |
| 6 · Coder speculation trial | 4K | 460.8 | 45.7 | 8.91 | 20.1 | 3/3 |
| 6 · Coder speculation trial | 16K | 487.6 | 47.0 | 33.65 | 44.3 | 3/3 |

Run 1's total times and cap counts come from the existing repository report; the new summary omitted those fields. The [original report](q2-0.md#full-timing-results) retains ranges and first-answer timings.

</details>

## What the experiments showed

The Q2_0 repeat was variable, especially on long prompts. Restarting improved the next run, but the cause was not isolated. Q2_0 used file-mapped experts, with engine logs predicting roughly 36.5–38.5 GB of drive reads per 32K-token prompt. Coder IQ1_M used about 18.08 GiB of RAM-resident experts plus a GPU expert cache and reported zero ongoing file-tier expert reads. These are engine observations, not measured disk-throughput results. The backing device was identified as NVMe `SHPP41-2000GM`; an earlier engine log's SATA-class inference was incorrect.

The `k8v4` trial was essentially tied with the Coder baseline. Reducing speculation to `spec=2` offered no clear improvement and lowered short-prompt decode throughput. Both trials were reverted to `KV=int8`, `spec=4` before tuning.

### Automatic tuning

These experiments were separate from the full standard suite:

| Experiment, November 6 | Result |
| --- | --- |
| Quick, preset `docker-tune-test`, `TUNE=quick` | Executed; reported “already fastest” and retained the baseline |
| First thorough attempt, `TUNE=thorough`, `RETUNE=1` | Reused the quick result; the installed Docker image 0.2.9 entrypoint did not forward `--retune` to the CLI |
| Actual thorough retune, preset `docker-tune-thorough` | Executed with a temporarily patched entrypoint; tested growing conversation-memory allocation and control-thread CPU placement; reported “already fastest” |

The last displayed launch retained Coder IQ1_M, 64K context, `KV=int8`, `spec=4`, and `--resident-experts`. Detailed tune candidate scores were not supplied, and no full standard run after thorough tuning was shown. These results support retaining the baseline among the evaluated settings; they do not establish global optimality.

### Limits and report locations

Performance requests could generate at most **512 tokens, including reasoning and visible answers**. Many 4K/16K requests reached that cap, so total time often measures time to the cap rather than a complete answer. Passing twelve sanity fixtures does not establish broad factual or coding quality. The standard performance cases extend to approximately 16K input; configuring 64K does not demonstrate quality across that full window.

Container `/data` maps to `/srv/ai/strata/data` on Prometheus. Each listed run wrote `README.md` and `results.json`; the original run also recorded configuration, outputs, and provenance. Tuner results were saved separately:

```text
/srv/ai/strata/data/state/strata/launch/docker-tune-test.tune.json
/srv/ai/strata/data/state/strata/launch/docker-tune-thorough.tune.json
```

Use the [run command and artifact guidance](q2-0.md#run-command) for future measurements.

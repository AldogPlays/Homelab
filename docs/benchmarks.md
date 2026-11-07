# Local AI benchmark history

> [Homelab](../README.md) · [Local AI](local-ai.md)

I ran six standard Strata benchmarks to compare Q2_0 with Coder IQ1_M on Prometheus. **I use Coder IQ1_M with `KV=int8`, `spec=4`, and RAM-resident experts as my baseline.** I kept the full timings and settings from my [original Q2_0 run](q2-benchmark.md).

I ran these tests on November 5–6, 2026 UTC and kept the raw results on Prometheus. My run folders use UTC timestamps; the first run took place November 4 in Pacific time.

## Standard runs

I used the Ryzen 7 7800X3D, Radeon RX 7800 XT with 16 GiB VRAM, approximately 30 GiB usable RAM, Strata engine 0.1.55, and a 65,536-token context for every run. I ran the benchmark inside an Ubuntu 24.04.5 container on my Ubuntu 26.04.1 host, calling the already-running server through container loopback. These timings exclude Open WebUI overhead.

| Run | Folder under `/data/benchmarks/` | Configuration | Duration |
| --- | --- | --- | --- |
| 1 · Original Q2_0 | `q2_0-20261105T054344Z/` | Q2_0, `KV=int8`, file-mapped experts | 20m 42s |
| 2 · Q2_0 repeat | `q2_0-20261105T204647Z/` | Q2_0, file-mapped experts | 25m 20s |
| 3 · Q2_0 fresh | `q2_0-fresh-20261105T214750Z/` | Same Q2_0 configuration after Compose restart | 19m 56s |
| 4 · Coder baseline | `coder-iq1_m-20261105T224226Z/` | Coder IQ1_M, `KV=int8`, `spec=4`, RAM-resident experts | 5m 36s |
| 5 · Coder KV trial | `coder-iq1_m-k8v4-20261106T015430Z/` | Coder IQ1_M, `KV=k8v4`, `spec=4` | 5m 34s |
| 6 · Coder speculation trial | `coder-iq1_m-spec2-20261106T021836Z/` | Coder IQ1_M, `KV=int8`, `spec=2` | 5m 40s |

All six of my runs passed **12/12 sanity checks**: four instruction, four retrieval, and four tool-call fixtures. None had failed or skipped required requests. Each of my five later runs completed 21/21 required requests; I kept the first run’s separate [request counts](q2-benchmark.md#output-caps-and-sanity-checks).

Switching from fresh Q2_0 to Coder brought my median 4K time to first token from **22.74 to 8.92 seconds** and 16K from **83.70 to 33.71 seconds**, about 2.5× faster in both cases. The suite took 5m 36s instead of 19m 56s. I changed the model and expert-residency mode together, so I can’t attribute the improvement to either change alone.

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

I kept the ranges and first-answer timings from run 1 in my [original Q2_0 notes](q2-benchmark.md#full-timing-results).

</details>

## What the experiments showed

I saw considerable variation in the Q2_0 repeat, especially on long prompts. Restarting improved the next run, but I didn’t isolate why. Q2_0 used file-mapped experts, and its logs estimated roughly 36.5–38.5 GB of drive reads per 32K-token prompt. With Coder, I used about 18.08 GiB of RAM-resident experts plus a GPU expert cache, and the logs showed zero ongoing file-tier expert reads. I haven’t measured disk throughput separately. My backing device is an NVMe `SHPP41-2000GM`; the earlier engine log incorrectly inferred a SATA-class SSD.

I got essentially the same performance with `k8v4` as with my Coder baseline. Reducing speculation to `spec=2` gave me no clear improvement and slowed short-prompt decoding. I reverted both trials to `KV=int8`, `spec=4` before tuning.

### Automatic tuning

I tried these tuners separately from the full standard suite:

| Experiment, November 6 | Result |
| --- | --- |
| Quick, preset `docker-tune-test`, `TUNE=quick` | I ran it; the tuner said “already fastest,” so I kept the baseline |
| First thorough attempt, `TUNE=thorough`, `RETUNE=1` | My first attempt reused the quick result because the Docker image 0.2.9 entrypoint did not forward `--retune` to the CLI |
| Actual thorough retune, preset `docker-tune-thorough` | I temporarily patched the entrypoint and tested growing conversation-memory allocation and control-thread CPU placement; the tuner again said “already fastest” |

I kept Coder IQ1_M, 64K context, `KV=int8`, `spec=4`, and `--resident-experts`. I haven’t repeated the full standard suite since thorough tuning. I keep the tune JSON files below; these trials don’t prove I’ve found the fastest possible configuration.

### Limits and report locations

I capped performance requests at **512 tokens, including reasoning and visible answers**. Many of my 4K/16K requests reached that cap, so their total time measures the wait until the cap rather than a complete answer. I haven’t evaluated broad factual or coding quality. My longest performance prompts were about 16K tokens; I haven’t tested answer quality across the full 64K window.

I keep the results under `/srv/ai/strata/data` on Prometheus, mounted as `/data` in the container. Each run wrote `README.md` and `results.json`; my original run also includes configuration, outputs, and provenance. I keep the tuner results separately:

```text
/srv/ai/strata/data/state/strata/launch/docker-tune-test.tune.json
/srv/ai/strata/data/state/strata/launch/docker-tune-thorough.tune.json
```

Use the [run command and artifact guidance](q2-benchmark.md#run-command) for future measurements.

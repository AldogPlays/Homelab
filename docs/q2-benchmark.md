# Q2_0 standard benchmark

> [Homelab](../README.md)

I ran this on November 4, 2026 Pacific time (November 5 UTC), directly against Strata's API inside the container. This is my original performance baseline; the [benchmark history](benchmarks.md) compares it with later Q2_0 and Coder IQ1_M runs. It measures the backend, without Open WebUI or the browser connection.

My [local AI notes](local-ai.md#serving-layout) explain how I connect the services, configure the context window, and use thinking mode. I used Q2_0 for this original run.

What I got from this run:

- **Reliability in this run:** zero failed requests and 12/12 sanity checks passed.
- **Generation speed:** median rates of 36.5–49.7 tokens/s.
- **Initial wait:** the median time to the first token grew from 1.41 seconds on the short prompt to 78.66 seconds on the 16K prompt.

Those generation rates alone don't describe the wait on a long prompt.

Each performance request had a **512-token output cap shared by reasoning and answer text**. Seven of the nine performance requests reached it; one 16K request produced no visible answer before stopping. These are useful timing results, but zero failures does not mean every request delivered a complete answer. The [sanity checks](#output-caps-and-sanity-checks) are separate, limited checks of instruction following, retrieval, and tool calls.

## How to read the timings

For a request, the server first processes the input prompt and then generates output tokens. With thinking enabled, the first generated token may be reasoning; the first visible answer can arrive later.

<details>
<summary>Timing definitions and sample sizes</summary>

| Metric | What it tells you |
| --- | --- |
| Prompt tokens/s | How quickly the input is processed. Higher is faster, but a longer prompt can still take more time overall. |
| Decode tokens/s | How quickly output tokens are generated, including reasoning. This is not a rate for visible answer text alone. |
| First token, s | Time from the request to the first generated token, which may be reasoning. Lower is faster. |
| First answer, s | Time from the request to the first visible answer text. It is unavailable if no answer appears before the output cap. |
| Total, s | Time until the request stops, either by finishing or by reaching its output cap. |
| Capped | Number of requests that reached the output cap, out of the samples in that row. |

The short input was about 80 tokens; the larger cases used approximately 4K and 16K prompt tokens. Each performance case ran three times. A median is the middle of the measured values; the ranges below show the smallest and largest values.

These small sample counts describe this run, not a guaranteed response time.

</details>

## Performance

| Case | Prompt tokens/s | Decode tokens/s | First token, s |
| --- | ---: | ---: | ---: |
| Short | — | 49.7 | 1.41 |
| 4K prompt | 167.3 | 36.5 | 24.50 |
| 16K prompt | 208.5 | 44.5 | 78.66 |

Values are medians from three repetitions. For example, the 16K case took a median 78.66 seconds to produce its first token, even though its median generation rate after that was 44.5 tokens/s. The API was accessed through container loopback (`127.0.0.1`), so these measurements exclude Open WebUI overhead.

## Full timing results

The full results include the timing ranges and the difference in sample counts for the 16K case.

<details>
<summary>Full timing table</summary>

Values are medians with minimum–maximum ranges. Each metric has three samples per case, **except 16K first-answer latency, which has only two**: the third request reached the cap without visible answer text.

That missing sample explains why the 16K first-answer median below is smaller than its first-token median. They summarize different sets of requests; they do not show an answer arriving before its own first token. Do not subtract these medians to calculate reasoning time.

| Metric | Short | 4K prompt | 16K prompt |
| --- | ---: | ---: | ---: |
| Prompt tokens/s | — | 167.3 (121.4–215.6) | 208.5 (158.9–322.2) |
| Decode tokens/s | 49.7 (39.4–64.0) | 36.5 (30.9–53.2) | 44.5 (29.3–49.6) |
| First token, s | 1.41 (0.85–1.52) | 24.50 (19.01–33.77) | 78.66 (50.92–103.23) |
| First answer, s | 2.89 (2.81–9.33) | 29.09 (25.43–46.69) | 70.16 (58.38–81.94) |
| Total, s | 11.1 (8.0–13.4) | 34.1 (33.0–50.3) | 96.1 (62.4–113.5) |
| Capped | 1/3 | 3/3 | 3/3 |

</details>


The report omits the short case's prompt-processing rate because fixed request overhead dominates at about 80 input tokens.

<details>
<summary><strong>Run configuration and provenance</strong></summary>

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
| Duration after model loading | 20 minutes 42 seconds |
| Host | My Ryzen 7 7800X3D and RX 7800 XT 16 GiB; the runner identified the GPU as `AMD Radeon` and memory as 30.0 GiB |
| Host OS | Ubuntu 26.04.1 LTS, from host `/etc/os-release` |
| Runner environment | Inside Docker: Ubuntu 24.04.5 LTS; kernel `7.0.0-42-generic` |

These values identify the measured run, including its draft protocol and exact Strata commit. They belong with the results when comparing runs.

The two Ubuntu versions refer to different layers: Prometheus runs Ubuntu 26.04.1, while the benchmark container contains Ubuntu 24.04.5 userspace tools and libraries. The runner reads the container's `/etc/os-release`; see the [OS-probe source](https://github.com/Niko1221/Strata/blob/main/strata_cli/bench_facts.py).

</details>

## Output caps and sanity checks

The runner labels a request that reaches its output cap `truncated`. This is an expected benchmark boundary, distinct from a failed request. For performance requests, the cap was **512 tokens, including reasoning and visible answer text**; total duration for a capped request measures time to that cap, not time to a complete answer. This test setting neither reduces the configured 64K context nor establishes the model's maximum output length. See the [protocol's truncation rules](https://github.com/Niko1221/Strata/blob/main/docs/BENCHMARK_PROTOCOL.md).

<details>
<summary>Request counts and output caps</summary>

| Phase | Planned | Completed without cap | Truncated | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: | ---: |
| Warm-up | 1 | 0 | 1 | 0 | 0 |
| Performance | 9 | 2 | 7 | 0 | 0 |
| Sanity | 12 | 12 | 0 | 0 | 0 |
| Concurrency | 0 | 0 | 0 | 0 | 0 |

</details>


All four instruction checks, four retrieval checks, and four tool-call checks passed. This verifies those twelve specific test cases; it is not a broad intelligence or coding-quality score.

The test coverage has two further limits:

- **Simultaneous requests:** no concurrency test was run.
- **Full context window:** the longest performance input was approximately 16K; the full 64K allocation was not exercised.

## Artifacts and limits

I kept the original reports on Prometheus, outside Git. They are root-owned and mode `600`; read them with `sudo` instead of changing permissions. The run used warm caches, so it does not measure a cold start.

<details>
<summary>Report files, model identification, and cache state</summary>

The original files remain on Prometheus, outside this repository:

```text
/srv/ai/strata/data/benchmarks/q2_0-20261105T054344Z/
├── README.md
├── config.json
├── outputs.jsonl
├── provenance/
└── results.json
```

I keep the full request traces, configuration, and provenance in that directory. The files are root-owned, mode `600`, so I read them with `sudo` rather than changing their permissions.

**Model identification.** The model was stored across two GGUF files, a format used for model weights. The report records abbreviated hash prefixes `69820c02ec7d0b45…` and `316b46f3a2dbd68c…`; complete hashes belong to the original artifacts. Model/source revisions, driver/runtime versions, storage characteristics, and background work were not measured.

**Cache state.** The server had answered one request before the run. Shared template-prefix and expert-cache state remained warm and evolved during the test: some reusable prompt and model data was already cached. The timings therefore do not describe a model's first request from a cold start.

**Repeating the test.** Reaching the output cap does not invalidate this baseline. If repeating the fixed suite, restart the engine between runs as required by the protocol to avoid reusing prompt state.

</details>

## Run command

Run this on **Prometheus** when intentionally starting a benchmark; it sends inference requests and writes report files. Leave other inference clients idle. For a repeat of the fixed suite, first restart the engine as required by the protocol, then wait for the model to be ready.

<details>
<summary>Benchmark command and report paths</summary>

The command below uses the already-running engine and does not perform that restart:

```bash
sudo docker exec -it strata sh -ec '
  strata bench run --help >/dev/null
  export STRATA_API_KEY="$(cat /run/secrets/strata_api_key)"
  exec strata bench run \
    --url http://127.0.0.1:8080 \
    --no-start \
    --out "/data/benchmarks/NEW-RUN-$(date -u +%Y%m%dT%H%M%SZ)"
'
```

This uses the running model through container loopback, reads authentication from its existing mounted file, and saves reports in persistent storage. `--no-start` prevents the runner from launching another engine. The help check stops the block if the installed CLI lacks the benchmark command. Command behavior and authentication are documented in [terminal commands](https://github.com/Niko1221/Strata/blob/main/docs/TERMINAL.md).

The output directory inside the container maps to `/srv/ai/strata/data/benchmarks/` on Prometheus. Retain the generated README, JSON, and supporting files together. Review the report before publishing. Use a descriptive, unique folder and record the active model and settings for each new run. My original run took 20 minutes 42 seconds after model loading; other runs can take a different amount of time.

</details>

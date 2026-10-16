# Local AI

[Back to overview](../README.md) · [Infrastructure](infrastructure.md) · [Services](services.md)

I'm experimenting with running language models locally and will add results here as I tune the setup. These first two Strata benchmarks were on Windows, on a PC with a Ryzen 7 7800X3D, Radeon RX 7800 XT, and 32 GB of DDR5 memory. The first run was untuned. Before the second, I changed speculative depth from the default of 4 to 2. I plan to wipe Windows and test Strata on a bare-metal Ubuntu Server install next.

## Strata benchmark — October 15, 2026

I ran `BENCH.bat` twice on October 15, 2026. Both runs used the same model and benchmark suite. The first run is my untuned baseline; before the second run, I changed speculative depth from the default of 4 to 2. The results below show both runs so I can keep track of the change.

Both runs started the Strata server on port 8080, warmed up, then ran each workload three times (nine short-chat runs and fifteen agent turns). The report identifies the model as `qwen3-8-flash-next-coder-iq1-m`; its output folder records `community-rx-7800-xt`.

| Workload | Untuned (depth 4) median | Depth 2 median | Samples per run |
| --- | ---: | ---: | ---: |
| Short chat decode | 27.30 tokens/s (22.10–34.30) | 27.40 tokens/s (24.40–29.40) | 9 |
| Short chat first token | 1.01 s (0.83–1.18) | 1.24 s (1.06–1.45) | 9 |
| 4K prompt processing | 497.40 tokens/s (399.80–499.10) | 498.70 tokens/s (484.10–500.10) | 3 |
| 4K prompt first token | 8.12 s (8.10–10.09) | 8.10 s (8.06–8.34) | 3 |
| 16K prompt processing | 501.10 tokens/s (499.50–503.50) | 506.00 tokens/s (504.30–508.80) | 3 |
| 16K prompt first token | 32.12 s (31.92–32.19) | 31.78 s (31.61–31.91) | 3 |
| Agent cache hit rate | 68.64% (68.43–68.74) | 68.72% (68.66–68.73) | 3 sessions |
| Agent re-read tokens/session | 5.00 (4.00–145.00) | 5.00 (5.00–5.00) | 3 sessions |
| Agent turn first token | 6.40 s (3.79–7.05) | 6.24 s (3.78–8.93) | 15 turns |
| Agent decode | 31.40 tokens/s (21.70–38.30) | 29.60 tokens/s (19.90–35.90) | 15 turns |

My short-chat requests generated up to 100 tokens. Prompt-processing trials used fresh prompts of about 4,096 or 16,384 tokens and generated 24 tokens. The agent workload used six turns and four tools per session. The harness estimated about 1.08 tokens per word during calibration in both runs.

### Report and sharing

The harness saved a detailed report for the first run in my Strata checkout at:

```text
bench/results/2026-10-15-community-rx-7800-xt-qwen3-8-flash-next-coder-iq1-m/README.md
```

That report is separate from this homelab repository. The harness says it replaces home-folder, user, host, and IP details, but I'll review the generated README before sharing it. Strata's suggested publication route is to add the results folder to a pull request using `docs/COMMUNITY_BENCHMARKS.md`, or paste its README into a GitHub issue. I haven't copied the full report into this repository.

The speculative-depth-2 run's report is at:

```text
bench/results/2026-10-15-community-rx-7800-xt-qwen3-8-flash-next-coder-iq1-m-2/README.md
```

### Notes

- These medians and ranges come from the harness output; each generated report has the per-run measurements.
- For the second run, I changed speculative depth to 2. The short-chat decode median was nearly unchanged, while its first-token median was 0.23 seconds higher. The runs alone don't establish that speculative depth caused the difference.
- First-token latency rose with prompt length in both runs. Reported prompt-processing throughput was about 500 tokens/s for both long-prompt sizes.

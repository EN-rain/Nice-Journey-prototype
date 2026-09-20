# Nice Journey — DR-08-Safe Reference Performance Evidence

Captured: 2026-09-14

## Status

This is a **reference-machine smoke baseline only** captured before DR-08 was resolved. Master §58 now contains the approved DR-08 hardware and benchmark contract; this historical reference-machine run is not final performance acceptance and does not satisfy that minimum-hardware worst-case benchmark.

Primary machine-readable artifact: `docs/evidence/reference-validation-2026-09-14.json`.

Reproduce with `powershell -NoProfile -File .\tools\reference_validation.ps1 -OutputPath docs\evidence\reference-validation-latest.json`.

The entrypoint discovers every `tests/test_*.gd` file in sorted order, records SHA-256 identities, runs editor parsing, every discovered executable test, a headless main-scene smoke, and an optional renderer-active greybox smoke.

## Reference environment

| Item | Captured value |
|---|---|
| Engine | Godot `4.6.2.stable.mono.official.71f334935` |
| Project renderer | `gl_compatibility` |
| Renderer/API observed | OpenGL 3.3 Compatibility; Intel Iris Xe; driver/build `32.0.101.7088` |
| World viewport | 640×360 |
| Window override | 1280×720 |
| Physical display reported by probe | 1920×1080 |
| Machine | Lenovo 82H7 |
| CPU | Intel Core i5-1135G7, 4 cores / 8 logical processors |
| RAM | 16,952,647,680 bytes (~15.8 GiB) |
| GPU | Intel Iris Xe Graphics |
| OS | Windows 11 Pro, build 26100, 64-bit |
| Project storage | Fanxiang MD87, USB-attached, D: NTFS |

The exact project/spec/state/tool hashes are stored in the JSON evidence so later runs can identify content drift even though the Godot project root is not currently a usable Git worktree.

## Repository validation result

The captured run discovered **14** executable `test_*.gd` gates. Editor parse, all 14 tests, and the configured main-scene headless smoke exited successfully with **0 failures**.

This is functional regression evidence only. Headless execution is not evidence of pixel readability, letterboxing, UI clipping, raster silhouette quality, lighting/VFX readability, or other visual acceptance.

## Renderer-active greybox smoke

Scenario ID: `QA-PERF-REFERENCE-GREYBOX`.

The probe instantiates the current gameplay greybox, warms for 120 rendered frames, then samples 600 rendered frames on the actual Compatibility renderer. Captured settings for this run were camera zoom step 0 / 1× zoom, VSync mode 1, 1280×720 window on a 1920×1080 display, Run mode Hold, reduced motion off, and shake intensity 1.0.

Observed single-run values:

| Metric | Value |
|---|---:|
| Mean frame interval | 7.021 ms |
| p50 frame interval | 6.900 ms |
| p95 frame interval | 6.930 ms |
| p99 frame interval | 15.790 ms |
| Maximum sampled frame interval | 34.701 ms |
| Samples above 16.667 ms | 3 / 600 |
| Samples above 40 ms | 0 / 600 |
| Maximum reported process time | 18.582 ms |
| Maximum reported physics-process time | 10.802 ms |
| Peak static memory reported by Godot | 34,466,270 bytes (~32.9 MiB) |
| Maximum draw calls observed in a sampled frame | 10 |
| Physics tick rate | 60 Hz |

The 16.667 ms and 40 ms counts remain informational anchors for this historical reference smoke. Final pass/fail performance acceptance must use the approved DR-08 benchmark contract on the approved minimum hardware class rather than treating this stronger reference machine as a substitute.

## What this evidence does not prove

- The current greybox is not the authored §41.1 worst-case scenario: there are no 8–12 active full-intelligence enemies, late-floor projectiles/effects, boss/elite sequencing, maximum UI scale, or representative navigation/audio load.
- This run does not establish floor-transition performance. The project currently resides on a USB-attached drive and no representative generated floor transition exists yet.
- One smoke run is not a statistically qualified benchmark or confidence interval.
- No screenshot/video evidence was captured here, so QA-PIXEL and visual portions of QA-ACCESS remain open.
- No optimization recommendation is justified from this smoke alone; there is no demonstrated bottleneck to optimize.

## Next DR-08-safe evidence step

Keep this entrypoint as the regression baseline. As representative scenes become available, add named scenario probes that record the same machine/settings metadata plus frame-time distribution, worst hitches, physics backlog, memory, active/dormant actor counts, navigation demand, projectiles/effects, and audio voices. Final QA-PERF acceptance remains pending until the approved DR-08 worst-case scenario is representative and the benchmark is executed on the approved minimum hardware class.

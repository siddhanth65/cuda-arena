# CUDA Arena — Benchmark Summary

All figures below were parsed automatically from `results/full_session.log` (session started 2026-11-26 18:50:09 UTC).

## Hardware and software

| Item | Value |
|---|---|
| GPU | NVIDIA GeForce RTX 3050 Laptop GPU (4096 MiB, compute capability 8.6) |
| NVIDIA driver (Windows) | 621.14 |
| CPU | 11th Gen Intel Core i5-11300H @ 3.10GHz |
| OS | Windows 11 Home (build 26300), WSL2 kernel via Docker Desktop |
| CUDA toolkit | 13.0 (V13.0.88), container `nvidia/cuda:13.0.1-devel-ubuntu24.04` |

## Main benchmark (`./scripts/run_demo.sh 1048576 5`)

| Metric | Value |
|---|---|
| Games | 1,048,576 |
| Timing iterations | 5 |
| Agent X wins | 339,530 (32.38%) |
| Agent O wins | 0 (0.00%) |
| Draws | 709,046 (67.62%) |
| Average moves per game | 8.3524 |
| CPU/GPU consistency | PASS (1,048,576 games checked) |
| Average GPU kernel time | 1.5826 ms |
| GPU throughput | 662.57 million games/s |
| CPU reference time (single thread) | 531.70 ms |
| CPU throughput | 1.97 million games/s |
| Kernel-only speedup vs. single-thread CPU | 336x |

## All runs in the session

| Run | Games | GPU kernel (ms) | GPU throughput (M games/s) | CPU ref (ms) | Speedup | X wins | O wins | Draws | Consistency |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| SMOKE TEST: 16384 games, 3 iterations | 16,384 | 0.0433 | 378.60 | 8.2441 | 190x | 5,339 | 0 | 11,045 | PASS |
| MAIN BENCHMARK: ./scripts/run_demo.sh 1048576 5 | 1,048,576 | 1.5826 | 662.57 | 531.7030 | 336x | 339,530 | 0 | 709,046 | PASS |
| BATCH SIZE SWEEP: 1024 games, 5 iterations | 1,024 | 0.0137 | 74.63 | 0.5527 | 40x | 321 | 0 | 703 | PASS |
| BATCH SIZE SWEEP: 16384 games, 5 iterations | 16,384 | 0.0317 | 516.65 | 8.2509 | 260x | 5,252 | 0 | 11,132 | PASS |
| BATCH SIZE SWEEP: 262144 games, 5 iterations | 262,144 | 0.3948 | 663.99 | 127.9010 | 324x | 84,792 | 0 | 177,352 | PASS |

## CSV validation (`scripts/validate_results.py`)

```
results/tournament_results.csv: rows=1048576 (expected 1048576) ids_sequential=True invalid_rows=0 seeds=['2030']
  winners={'DRAW': 709046, 'X': 339530}  avg_moves=8.3524
  (winner,moves) distribution={('DRAW', 9): 709046, ('X', 7): 339530}
results/smoke.csv: rows=16384 (expected 16384) ids_sequential=True invalid_rows=0 seeds=['2028']
  winners={'X': 5339, 'DRAW': 11045}  avg_moves=8.3483
  (winner,moves) distribution={('DRAW', 9): 11045, ('X', 7): 5339}
VALIDATION: PASS
```

## Interpretation

- Throughput rises with batch size and levels off at about 660 million games/s from 262,144 games upward. At 1,024 games, only 4 blocks of 256 threads run on the GPU's 16 SMs, so most of the GPU sits idle and fixed launch overhead dominates.
- Speedup figures compare **GPU kernel time only** with a **single-threaded** CPU loop. They leave out host-device transfer and kernel launch overhead, and the CPU side is neither multithreaded nor vectorised, so they overstate the end-to-end advantage.
- The agents are deterministic heuristics with a small seeded tie-break. Agent O never wins: every decided game is an X win on move 7, and every other game is a 9-move draw. This is a property of the two strategies, not a counting error; the per-game CSV confirms it independently.
- The CSV `seed` column records the seed of the **final** timing iteration (base seed + iterations − 1). The CPU reference is checked against that same final iteration.
- Timings vary by a few percent between runs because of laptop GPU boost clocks and power state.

## Evidence screenshot

evidence/cuda-run.png shows a **separate live run** (`scripts/screenshot_run.sh`, 1,048,576 games, 5 iterations), launched in a visible terminal window on the laptop and captured with `scripts/capture_window.ps1`. Its full output is in `results/screenshot_run.log`. The win/draw counts are identical to the main benchmark, as expected with the same seed. Timings differ slightly, as expected between runs: 1.5473 ms kernel time, 677.70 million games/s, and a 617.85 ms CPU reference.
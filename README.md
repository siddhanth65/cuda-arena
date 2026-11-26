# CUDA Arena: Massively Parallel GPU Tic-Tac-Toe Tournament

CUDA Arena is a CUDA C++ project that runs a tournament of independent Tic-Tac-Toe games. It demonstrates how a problem with many independent simulations can be mapped onto a GPU: **one CUDA thread simulates one complete game**, and thousands of games execute concurrently across the device.

The project has two modes:

- **Tournament mode (`cuda_tournament`)** simulates a configurable batch of independent games in a CUDA kernel, compares every GPU result with a CPU reference, reports throughput and timing, and writes a per-game CSV file.
- **Duel mode (`cuda_arena_duel`)** preserves the original terminal match between two logical agents. It is useful for demonstrating individual moves, but the tournament is the main scalable GPU workload.

## Hardware and honesty note

The program requires an NVIDIA CUDA-capable GPU and a compatible CUDA Toolkit. It selects CUDA device 0. It does not claim to use two physical GPUs. The two agents are logical strategies running as part of each independent game.

The browser visualization linked below is an explanatory illustration. It does not execute CUDA and is not proof of GPU execution. For Coursera evidence, run the compiled CUDA program on a real CUDA device and include the generated terminal log and CSV output.

## Measured results (author's laptop)

Measured on 2026-11-26. Full logs are in `results/full_session.log`, with the analysis in `results/benchmark_summary.md`.

| Item | Value |
|---|---|
| GPU | NVIDIA GeForce RTX 3050 Laptop GPU (4 GB, compute capability 8.6, 16 SMs) |
| Driver / toolkit | NVIDIA 621.14 (Windows) / CUDA 13.0 (`nvidia/cuda:13.0.1-devel-ubuntu24.04` container on WSL2) |
| CPU | Intel Core i5-11300H |

| Games | Avg GPU kernel time | GPU throughput | CPU reference (1 thread) | X wins | O wins | Draws | CPU/GPU check |
|---:|---:|---:|---:|---:|---:|---:|---|
| 1,024 | 0.0137 ms | 74.6 M games/s | 0.55 ms | 321 | 0 | 703 | PASS |
| 16,384 | 0.0317 ms | 516.6 M games/s | 8.25 ms | 5,252 | 0 | 11,132 | PASS |
| 262,144 | 0.3948 ms | 664.0 M games/s | 127.90 ms | 84,792 | 0 | 177,352 | PASS |
| 1,048,576 | 1.5826 ms | 662.6 M games/s | 531.70 ms | 339,530 | 0 | 709,046 | PASS |

- GPU throughput levels off at about 660 M games/s once the batch fills the GPU's 16 SMs. At 1,024 games, launch overhead dominates.
- The GPU time is kernel-only and the CPU baseline is single-threaded, so the roughly 336x ratio for 1,048,576 games is **not** an end-to-end speedup.
- With these heuristics Agent O never wins: every decisive game is an X win on move 7. The per-game CSV (validated by `scripts/validate_results.py`) confirms this.
- Laptop boost clocks make timings vary by a few percent between runs.

### Reproducing on Windows without a native CUDA toolkit

These runs used Docker Desktop's WSL2 backend with the official NVIDIA CUDA development image. The Windows NVIDIA driver provides GPU access:

```powershell
docker run --rm --gpus all -v "${PWD}:/work" -w /work nvidia/cuda:13.0.1-devel-ubuntu24.04 ./scripts/full_session.sh
```

`scripts/full_session.sh` builds the project and runs the smoke test, the 1,048,576-game benchmark and the batch-size sweep. Pipe it through `tee results/full_session.log` to keep the log.
## Why parallelize independent games?

A single Tic-Tac-Toe game has only nine cells, so launching a GPU kernel for one match is too small to showcase useful GPU throughput. Tournament mode instead creates many independent games. Each GPU thread owns a private nine-cell board, simulates its game, and writes a compact result. There are no dependencies between games, so the work can be distributed across many GPU threads without inter-thread synchronization.

The project demonstrates a parallel simulation workload and measurement workflow. It does not assume that a GPU is automatically faster for every problem size. For small batches, launch overhead can dominate.

## CUDA implementation

The tournament kernel is `simulate_tournament_kernel` in `src/cuda_tournament.cu`.

1. The host allocates an output array for all game results.
2. The kernel launches enough CUDA threads to cover the requested number of games.
3. Each thread calculates its game ID from `blockIdx.x`, `blockDim.x`, and `threadIdx.x`.
4. Each thread initializes a private board and simulates up to nine moves.
5. The aggressive X strategy and defensive O strategy score legal cells using immediate wins, blocking opportunities, and board position.
6. A deterministic hash-based tie-breaker varies otherwise equivalent choices while keeping each run reproducible for a fixed seed.
7. Each thread writes the winner and number of moves to its output slots.
8. The host copies results back, computes tournament totals, and checks every GPU result against the CPU reference implementation using the same deterministic rules.

The CPU/GPU check is a consistency check between the two implementations. It is not a formal proof that the heuristics are strategically optimal. The strategies are explainable heuristics, not minimax solvers.

## Requirements

- NVIDIA GPU with a working CUDA driver
- CUDA Toolkit with `nvcc`
- GNU Make
- C++17-capable host compiler

Check the environment:

```bash
nvcc --version
nvidia-smi
make --version
```

## Build

From the repository root:

```bash
make clean
make
```

This builds `cuda_tournament` (the primary capstone workload) and `cuda_arena_duel` (the original single-match demonstration).

## Run the tournament

Default run:

```bash
./cuda_tournament
```

The default is 262,144 games and five timed GPU iterations.

Large execution suitable for evidence:

```bash
./cuda_tournament --games 1048576 --iterations 5 --seed 2026 --csv results/tournament_results.csv
```

The run prints the GPU name, game count, winner totals, CPU/GPU consistency result, average GPU kernel time, throughput, and CPU reference time. The CSV contains one row per game with the game ID, winner, number of moves, and seed.

Run the bundled script:

```bash
chmod +x scripts/run_demo.sh
./scripts/run_demo.sh 1048576 5
```

## Command-line options

| Option | Description | Default |
|---|---|---:|
| `--games N` | Number of independent games (1 to 20,000,000) | 262144 |
| `--iterations N` | Number of timed kernel iterations (1 to 100) | 5 |
| `--seed N` | Reproducible 32-bit seed | 2026 |
| `--csv PATH` | CSV output destination | `results/tournament_results.csv` |
| `--no-csv` | Disable CSV output | Off |
| `--help` | Show usage | - |

## Measuring performance

CUDA events measure the tournament kernel. The printed GPU time is kernel-only and excludes host-side CSV writing and the final device-to-host result copy. The CPU reference timing measures the host simulation loop. Interpret the timings with that distinction; they are not a complete end-to-end comparison.

For meaningful observations, run multiple batch sizes (for example 1,024, 16,384, 262,144, and 1,048,576 games) and record how throughput changes. Do not claim a GPU speedup without comparing measurements under clearly stated conditions.

## Repository layout

```text
cuda-arena/
├── src/                     cuda_tournament.cu (main benchmark), cuda_arena.cu (duel demo)
├── scripts/                 run_demo.sh, full_session.sh, screenshot_run.sh,
│                            validate_results.py, make_summary.py, make_proof_zip.py,
│                            capture_screenshot.ps1, capture_window.ps1
├── results/                 full_session.log, tournament.log, tournament_results.csv,
│                            smoke.csv, screenshot_run.log, video_run.log, benchmark_summary.md
├── evidence/                cuda-run.png (genuine terminal capture of a live GPU run)
├── deliverables/            cuda-arena-proof.zip, cuda-arena-demo.mp4, FINAL_SUBMISSION_CHECKLIST.md
├── presentation/            final_narration.md, speaker_script.md, make_narration.ps1,
│                            record_screen.ps1, build_video.ps1
├── index.html               explanatory browser illustration (not GPU evidence)
├── Makefile
└── README.md
```
## Execution evidence for the course

After running on the Coursera CUDA lab or another supported NVIDIA GPU environment, retain:

- `results/tournament.log` - terminal output showing the device, batch size, timings, throughput, and consistency result.
- `results/tournament_results.csv` - per-game outputs for the whole batch.
- A screenshot of the terminal showing the successful run and the GPU device name.

Commit the log and CSV to the public repository, and upload a ZIP containing the log, CSV, and screenshot to the Coursera proof-of-execution field. Do not use the browser visualization or an unexecuted sample output as GPU evidence.

## Limitations and future work

The game agents use hand-designed heuristics rather than minimax search. Every thread simulates a small game sequentially, while GPU parallelism comes from running many independent games at once. This is a batch-simulation example, not a universal workload: very small batches may be more efficient on a CPU. Future extensions could compare multiple heuristic policies, add a minimax opponent, or evaluate larger board sizes.

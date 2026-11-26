# CUDA Arena — Final Presentation Narration

**Target length:** about 7 minutes in total: around 790 spoken words (about 6.5 minutes of narration) plus title cards.
**Authorship disclosure:** This script was drafted with help from Claude (an AI assistant), based on the project source code and the real measurements in `results/full_session.log`. Review it and change it into your own words before recording. If the video uses synthetic text-to-speech narration, the video itself says so on screen.
**Every number below comes from the measured session on 2026-11-26.** If you re-run the benchmark, update the numbers to match your new log.

---

## Scene 1 — Introduction (0:00–0:45)
**On screen:** title card "CUDA Arena: Massively Parallel GPU Tic-Tac-Toe Tournament", then the presenter's name.

Hello, I'm Siddhanth Susheel, and this is CUDA Arena, my capstone project for the GPU programming specialisation. The idea is simple: take a problem made of many small, independent tasks — here, games of tic-tac-toe between two rule-based agents — and run a million of them at once on an NVIDIA GPU. I'll show the code, compile it, run it on my own laptop GPU, check the GPU results against a CPU reference, and then look at what the numbers mean, including their limitations.

## Scene 2 — Repository and README (0:45–1:30)
**On screen:** github.com/siddhanth65/cuda-arena, scrolling the README.

The project is on GitHub at siddhanth65/cuda-arena. The repository has two CUDA programs: `cuda_tournament`, the main benchmark, and `cuda_arena_duel`, a smaller program that plays out individual games for illustration. There's a Makefile, a demo script that builds and runs the benchmark and saves a log and a CSV, and a results folder with the execution evidence.

## Scene 3 — Kernel and architecture (1:30–3:00)
**On screen:** `src/cuda_tournament.cu` — `simulate_tournament_kernel`, then `simulate_one_game`, then `score_move`.

The core design is one CUDA thread per game. The kernel computes a global game ID from the block and thread index, and that thread plays one complete game on a nine-cell board held in its own local memory. Games share no state, so no synchronisation or atomic operations are needed — a textbook embarrassingly parallel workload.

Each move is chosen by `score_move`. A move that wins immediately scores highest, blocking the opponent's win comes next, and then centre, corner and edge cells get different weights. Agent X and Agent O use different weightings, so they are genuinely different strategies. To break ties, a hash of the seed, the game ID, the turn and the cell adds a small amount of reproducible pseudo-randomness, so every game is deterministic given the seed.

The important engineering choice is that `simulate_one_game` is marked both host and device. The exact same function runs on the GPU and on the CPU, which makes a bit-for-bit correctness check possible. The launch uses 256 threads per block, and a million games need 4,096 blocks.

## Scene 4 — Compilation (3:00–3:40)
**On screen:** terminal running `make clean && make`.

My laptop runs Windows 11 with a GeForce RTX 3050 Laptop GPU, with 4 GB of memory and compute capability 8.6. I build inside the official NVIDIA CUDA 13.0 development container, running on WSL2, which uses the Windows NVIDIA driver for GPU access. `make clean && make` compiles both programs with nvcc at optimisation level O3, with no errors or warnings.

## Scene 5 — GPU execution (3:40–4:40)
**On screen:** terminal running `./cuda_tournament --games 1048576 --iterations 5 --seed 2026` (the same benchmark that `run_demo.sh` runs).

Now a live run of the main benchmark: 1,048,576 games, timed over five iterations. The program identifies the GPU as the NVIDIA GeForce RTX 3050 Laptop GPU. In the logged benchmark session, the average kernel time was 1.58 milliseconds, about 663 million games per second. Laptop timings vary by a few percent from run to run, so the live run on screen lands close to that figure rather than exactly on it. The outcome counts are deterministic: Agent X won 339,530 games, Agent O won none, and 709,046 games — about 68 percent — were draws.

## Scene 6 — Correctness verification (4:40–5:20)
**On screen:** the "CPU/GPU consistency: PASS" line; then `python scripts/validate_results.py`.

Speed means nothing if the answers are wrong. After timing, the program copies the GPU results back and replays every game on the CPU with the same seed. All 1,048,576 games matched on both the winner and the number of moves. Separately, a validation script checks the CSV: the right number of rows, sequential game IDs, only valid winner values, and move counts that are legal for each outcome. All of those checks passed.

## Scene 7 — CSV results and benchmark analysis (5:20–6:30)
**On screen:** the first rows of `results/tournament_results.csv` in the terminal, then `results/benchmark_summary.md` in VS Code.

The CSV has one row per game. Looking at the batch-size sweep: 1,024 games ran at about 75 million games per second, 16,384 games at about 517 million, and from 262,144 games upward throughput levels off at about 660 million games per second. With only 1,024 games there are just four blocks for the GPU's 16 streaming multiprocessors, so most of the GPU sits idle and launch overhead dominates. Larger batches fill the GPU.

The single-threaded CPU reference took about 532 milliseconds for a million games, so the kernel is about 336 times faster — but that comparison needs a caveat, which brings me to the limitations.

## Scene 8 — Limitations and conclusion (6:30–7:15)
**On screen:** "Limitations" card, then a closing card.

First, the GPU time is kernel-only, while the CPU baseline is a single thread with no vectorisation. A fair end-to-end comparison would include memory transfers on the GPU side and a multithreaded CPU baseline, so the real-world speedup is much smaller than 336 times. Second, the agents are simple heuristics: Agent O never won, and every decisive game ended with an X win on move seven. That makes the tournament a good parallel-computing benchmark, but not an interesting AI result. Third, these are measurements from a single laptop, and boost clocks make them vary by a few percent from run to run.

To conclude: CUDA Arena shows the one-thread-per-task pattern working at scale, sharing one function between host and device so the GPU output can be verified exactly, and the importance of filling the GPU with enough parallel work. Thank you for watching.

---
*Approximate spoken word count: ~790.*
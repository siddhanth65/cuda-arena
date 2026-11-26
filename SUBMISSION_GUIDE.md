# Coursera capstone submission checklist

This file is a preparation aid, not a claim that the project has already been run or presented.

## Project title
CUDA Arena: Massively Parallel GPU Tic-Tac-Toe Tournament

## Code repository URL
https://github.com/siddhanth65/cuda-arena

## Proof of execution
After running the CUDA build on an NVIDIA GPU, create a ZIP containing:
- `results/tournament.log`
- `results/tournament_results.csv`
- a terminal screenshot showing the GPU name and successful run

Do not upload illustrative browser screenshots or sample outputs as proof of CUDA execution.

## Project description - draft to personalize after testing

CUDA Arena explores how a small sequential game can be transformed into a large parallel simulation workload. A single Tic-Tac-Toe match exposes very little work, so the project runs many independent matches concurrently. In the CUDA tournament kernel, one GPU thread owns one game, initializes its board, applies two heuristic agents, and writes the winner and move count to a result array. The X agent emphasizes immediate wins and aggressive positional choices, while the O agent gives stronger priority to blocking and defensive positions. A deterministic hash-based tie-breaker varies decisions across games while keeping results reproducible for a fixed seed.

The host program accepts command-line arguments for the number of games, timing iterations, seed, and CSV destination. CUDA events measure kernel time, and the program reports tournament totals and throughput. It also compares every GPU result with a CPU reference using the same deterministic rules; this checks CPU/GPU consistency but does not prove that the heuristics are optimal. The generated CSV preserves per-game results, while the console log records the GPU and benchmark details.

The main challenge was choosing a workload that exposes enough parallelism to justify GPU execution. Launching a kernel for one nine-cell board would be dominated by overhead, whereas independent games can be distributed across many threads without synchronization between games. The results should be interpreted by testing multiple batch sizes: very small batches may favour the CPU, and the GPU timing reported by the program is kernel-only. The current agents are simple heuristics rather than minimax solvers, so the project demonstrates parallel simulation and measurement rather than optimal game play.

Before submission, add your actual GPU model, the batch sizes you tested, measured throughput, any issues encountered, and what you changed after examining the results. Do not claim measurements or development time that you did not personally complete.

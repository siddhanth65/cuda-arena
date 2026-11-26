# CUDA Arena - 6 to 8 minute demonstration script

## 0:00-0:45 - Problem and motivation

"CUDA Arena is a GPU-parallel simulation project built around Tic-Tac-Toe. A single game is too small to make a useful GPU workload: there are only nine cells, and kernel-launch overhead can dominate. I changed the main workload from one match to a tournament of many independent matches. The games do not depend on each other, which makes them suitable for parallel execution."

## 0:45-1:45 - Workload and algorithms

"Each game has two logical agents. X uses a more aggressive positional strategy, while O uses a more defensive strategy. Both prioritize immediate wins and blocking opportunities, then use position scores for the centre, corners and edges. A deterministic hash-based tie-breaker creates variation across games while allowing a run to be reproduced with the same seed. These are transparent heuristics, not a minimax solver."

## 1:45-3:00 - CUDA mapping

"The main CUDA kernel is simulate_tournament_kernel. The host chooses a batch size and launches enough CUDA threads to cover every requested game. Each thread calculates its own game ID, owns a private nine-cell board, simulates that game, and writes two integers: the winner and the number of moves. Because games are independent, threads do not need to synchronize with one another or exchange board state. The GPU parallelism is across games, not within one board."

## 3:00-4:00 - Memory and execution

"The host allocates a compact output array on the device. The kernel writes one result pair per game. After the timed iterations, the host copies the results back and aggregates wins, draws and average moves. CUDA events measure kernel execution time. The CSV is written on the host, outside the kernel timing."

## 4:00-5:15 - Correctness and evidence

"I compare every GPU result with the CPU reference using the same deterministic rules and seed. The program reports how many games were checked and whether any mismatches occurred. The execution log records the GPU name, game count, iteration count, outcomes, kernel time and throughput. The CSV stores one result row per game, so the evidence covers a large batch rather than a single demonstration."

## 5:15-6:15 - Results and interpretation

"Here I will show the actual run from the CUDA environment. I will point out the GPU model, the number of simulated games, the CPU/GPU consistency result, kernel time and throughput. The GPU timing is kernel-only, while the CPU time measures the host simulation loop, so I will not present their ratio as a strict end-to-end speedup. I will compare several batch sizes to show how workload size affects throughput."

## 6:15-7:00 - Lessons and limitations

"The main lesson is that GPU suitability depends on exposing enough independent work. A single Tic-Tac-Toe game is a poor GPU workload, but a large batch of independent games exposes parallelism. The current heuristics are intentionally simple and are not guaranteed to play optimally. Small batches may favour the CPU because of launch overhead. Future work could compare more strategies, add minimax search, and test larger game representations."

## Recording checklist

- Show the repository and README.
- Show the CUDA source and identify the one-thread-per-game kernel.
- Build with \`make clean && make\`.
- Run \`./scripts/run_demo.sh 1048576 5\` on the CUDA GPU.
- Show the terminal output and the generated CSV.
- Only report numbers observed in the actual run.

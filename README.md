# CUDA Arena: GPU vs GPU Tic-Tac-Toe

A CUDA C++ game in which two logical AI agents compete. Each agent evaluates all nine board cells in parallel using a CUDA kernel; the host selects the highest-scoring legal move.

## Hardware note

This version uses **one physical CUDA device** with two independent logical agents and separate CUDA streams. It does not claim two physical GPUs. The agents alternate turns because each move depends on the updated board.

## Agents

- **Agent X (aggressive):** immediate wins, blocks, center and corners.
- **Agent O (defensive):** immediate wins, stronger blocking priority and positional moves.

These are explainable heuristics, not exhaustive minimax solvers.

## Build and run

Requirements: NVIDIA GPU, compatible CUDA Toolkit (`nvcc`), GNU Make and C++17 support.

```bash
make clean
make
./cuda_arena
./cuda_arena --games 3
```

Or run `chmod +x scripts/run_demo.sh && ./scripts/run_demo.sh 3`. The script stores output in `results/demo.log`.

## CUDA flow

1. Host stores nine integers: 0 is empty, 1 is X and 2 is O.
2. Current board is copied to device memory.
3. `EvaluateMoves` launches CUDA threads to score candidate cells.
4. Occupied cells receive a very low score; legal cells get heuristic scores.
5. Scores return to host, which selects the best legal move.
6. Host updates the board, checks win/draw and alternates agents.

## CLI

| Argument | Meaning | Default |
|---|---|---|
| `--games COUNT` | Number of games | 1 |

## Visualization and presentation

- [Open the interactive game visualization](https://siddhanth65.github.io/cuda-arena/)
- [Source HTML](presentation-assets/game_visualization.html)
- [Presentation speaker script](presentation/speaker_script.md)

The downloadable project bundle also contains an animated GIF preview and a short explanatory MP4. The browser visualization and supplied MP4 are illustrative explanatory assets. They do not execute CUDA or prove GPU execution. Compile and run the application in the course GPU environment and record that actual run as execution evidence.

## Enable the public visualization

In repository **Settings → Pages**, select **Deploy from a branch**, choose `main` and `/(root)`, then save. The root URL above serves `index.html`.

## Limitations

Move selection is heuristic rather than minimax. Tic-Tac-Toe is too small to claim a GPU speedup; kernel launch and memory-transfer overhead can dominate. Future work includes minimax with alpha-beta pruning, parallel independent games, or separate physical GPUs when available.

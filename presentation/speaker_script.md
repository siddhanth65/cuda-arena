# CUDA Arena — presentation script

## Project overview
"CUDA Arena is a Tic-Tac-Toe game in which two CUDA-based agents compete. Agent X uses an aggressive heuristic, while Agent O uses a defensive heuristic. The goal is to demonstrate parallel candidate-move evaluation with CUDA."

## Architecture
"The board is nine integers: zero is empty, one is X and two is O. The host controls turns, checks wins and displays the board. The GPU evaluates candidate moves for the active agent. The agents alternate because each move depends on the updated board."

## CUDA kernel
"The EvaluateMoves kernel assigns one CUDA thread to each board cell. Occupied cells receive a very low score. Empty cells are scored for immediate wins, blocking opportunities and position. Scores return to the host, which selects the highest-scoring legal move."

## Hardware and lessons
"The course environment may expose only one physical GPU. This version therefore runs two logical agents on device zero, with separate streams and alternating turns. It does not claim two physical GPUs. Tic-Tac-Toe is a small workload, so launch and memory-transfer overhead can dominate. The project demonstrates parallel candidate evaluation, not a speedup claim."

Run: `./scripts/run_demo.sh 3`.

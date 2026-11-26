#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GAMES=262144
ITERATIONS=5
if [[ $# -ge 1 ]]; then GAMES="$1"; fi
if [[ $# -ge 2 ]]; then ITERATIONS="$2"; fi
mkdir -p results
make clean
make
echo "Running CUDA Arena tournament: games=$GAMES, iterations=$ITERATIONS"
./cuda_tournament \
  --games "$GAMES" \
  --iterations "$ITERATIONS" \
  --seed 2026 \
  --csv results/tournament_results.csv \
  | tee results/tournament.log
echo
echo "Execution evidence saved in:"
echo "  results/tournament.log"
echo "  results/tournament_results.csv"

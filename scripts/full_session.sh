#!/usr/bin/env bash
# Runs the full CUDA Arena evidence session and logs everything.
# Usage (from repo root): ./scripts/full_session.sh 2>&1 | tee results/full_session.log
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p results
section() { echo; echo "################ $* ################"; }

section "SESSION INFO"
echo "Date (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
echo "Host kernel: $(uname -srm)"
nvidia-smi
nvcc --version

section "BUILD: make clean && make"
make clean && make
echo "build exit code: $?"

section "SMOKE TEST: 16384 games, 3 iterations"
./cuda_tournament --games 16384 --iterations 3 --seed 2026 --csv results/smoke.csv
echo "smoke exit code: $?"

section "MAIN BENCHMARK: ./scripts/run_demo.sh 1048576 5"
./scripts/run_demo.sh 1048576 5
echo "run_demo exit code: $?"

for games in 1024 16384 262144; do
  section "BATCH SIZE SWEEP: $games games, 5 iterations"
  ./cuda_tournament --games "$games" --iterations 5 --seed 2026 --no-csv
  echo "batch $games exit code: $?"
done

section "SESSION COMPLETE"
echo "Finished (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
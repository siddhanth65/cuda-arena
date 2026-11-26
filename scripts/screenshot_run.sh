#!/usr/bin/env bash
# Live run shown in the evidence screenshot. Output is also saved to results/screenshot_run.log.
cd "$(dirname "$0")/.."
{
echo "\$ nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv"
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv
echo
echo "\$ ./cuda_tournament --games 1048576 --iterations 5 --seed 2026 --no-csv"
./cuda_tournament --games 1048576 --iterations 5 --seed 2026 --no-csv
} 2>&1 | tee results/screenshot_run.log
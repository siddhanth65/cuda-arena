#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
make clean
make
mkdir -p results
./cuda_arena --games "${1:-3}" | tee results/demo.log

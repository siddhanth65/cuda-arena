# Execution evidence

Run the project on a real CUDA-capable NVIDIA GPU to generate the evidence files.

From the repository root:

\`\`\`bash
./scripts/run_demo.sh 1048576 5
\`\`\`

This generates:
- \`tournament.log\`: console output, including GPU identification, correctness check, timing and throughput.
- \`tournament_results.csv\`: one result row per independent game.

Also capture a terminal screenshot showing the successful run and GPU name. These files must come from actual CUDA execution; illustrative browser output is not a substitute.

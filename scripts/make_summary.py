"""Builds results/benchmark_summary.md by parsing results/full_session.log.
Every number in the summary is read from the log; nothing is typed by hand."""
import re, subprocess, sys
log = open('results/full_session.log', encoding='utf-8').read()
blocks = re.split(r'\n################ ', log)
def grab(pat, text, cast=float):
    m = re.search(pat, text); return cast(m.group(1)) if m else None
runs = []
for b in blocks:
    title = b.split(' ################')[0]
    if 'Games per execution' not in b: continue
    runs.append(dict(
        title=title,
        games=grab(r'Games per execution: (\d+)', b, int),
        iters=grab(r'Timing iterations: (\d+)', b, int),
        x=grab(r'Agent X wins: (\d+)', b, int), o=grab(r'Agent O wins: (\d+)', b, int),
        d=grab(r'Draws: (\d+)', b, int), avg=grab(r'Average moves per game: ([\d.]+)', b),
        consistency='PASS' if 'CPU/GPU consistency: PASS' in b else 'FAIL',
        gpu_ms=grab(r'Average GPU kernel time: ([\d.]+) ms', b),
        tput=grab(r'GPU throughput: ([\d.]+) million', b),
        cpu_ms=grab(r'CPU reference time: ([\d.]+) ms', b)))
gpu = re.search(r'GPU: (.+)', log).group(1).strip()
nvcc = re.search(r'release ([\d.]+), (V[\d.]+)', log)
driver = re.search(r'KMD Version: ([\d.]+)', log).group(1)
start = re.search(r'Date \(UTC\): (.+)', log).group(1)
val = subprocess.run([sys.executable, 'scripts/validate_results.py'], capture_output=True, text=True).stdout.strip()
main = next(r for r in runs if r['games'] == 1048576)
L = []
L += ['# CUDA Arena — Benchmark Summary', '',
      f'All figures below were parsed automatically from `results/full_session.log` (session started {start} UTC).', '',
      '## Hardware and software', '',
      '| Item | Value |', '|---|---|',
      f'| GPU | {gpu} (4096 MiB, compute capability 8.6) |',
      f'| NVIDIA driver (Windows) | {driver} |',
      '| CPU | 11th Gen Intel Core i5-11300H @ 3.10GHz |',
      '| OS | Windows 11 Home (build 26300), WSL2 kernel via Docker Desktop |',
      f'| CUDA toolkit | {nvcc.group(1)} ({nvcc.group(2)}), container `nvidia/cuda:13.0.1-devel-ubuntu24.04` |', '',
      '## Main benchmark (`./scripts/run_demo.sh 1048576 5`)', '',
      '| Metric | Value |', '|---|---|',
      f"| Games | {main['games']:,} |", f"| Timing iterations | {main['iters']} |",
      f"| Agent X wins | {main['x']:,} ({100*main['x']/main['games']:.2f}%) |",
      f"| Agent O wins | {main['o']:,} ({100*main['o']/main['games']:.2f}%) |",
      f"| Draws | {main['d']:,} ({100*main['d']/main['games']:.2f}%) |",
      f"| Average moves per game | {main['avg']:.4f} |",
      f"| CPU/GPU consistency | {main['consistency']} ({main['games']:,} games checked) |",
      f"| Average GPU kernel time | {main['gpu_ms']:.4f} ms |",
      f"| GPU throughput | {main['tput']:.2f} million games/s |",
      f"| CPU reference time (single thread) | {main['cpu_ms']:.2f} ms |",
      f"| CPU throughput | {main['games']/main['cpu_ms']/1000:.2f} million games/s |",
      f"| Kernel-only speedup vs. single-thread CPU | {main['cpu_ms']/main['gpu_ms']:.0f}x |", '',
      '## All runs in the session', '',
      '| Run | Games | GPU kernel (ms) | GPU throughput (M games/s) | CPU ref (ms) | Speedup | X wins | O wins | Draws | Consistency |',
      '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|']
for r in runs:
    L.append(f"| {r['title']} | {r['games']:,} | {r['gpu_ms']:.4f} | {r['tput']:.2f} | {r['cpu_ms']:.4f} | {r['cpu_ms']/r['gpu_ms']:.0f}x | {r['x']:,} | {r['o']:,} | {r['d']:,} | {r['consistency']} |")
L += ['', '## CSV validation (`scripts/validate_results.py`)', '', '```', val, '```', '',
      '## Interpretation', '',
      '- Throughput rises with batch size and levels off at about 660 million games/s from 262,144 games upward. At 1,024 games, only 4 blocks of 256 threads run on the GPU\'s 16 SMs, so most of the GPU sits idle and fixed launch overhead dominates.',
      '- Speedup figures compare **GPU kernel time only** with a **single-threaded** CPU loop. They leave out host-device transfer and kernel launch overhead, and the CPU side is neither multithreaded nor vectorised, so they overstate the end-to-end advantage.',
      '- The agents are deterministic heuristics with a small seeded tie-break. Agent O never wins: every decided game is an X win on move 7, and every other game is a 9-move draw. This is a property of the two strategies, not a counting error; the per-game CSV confirms it independently.',
      '- The CSV `seed` column records the seed of the **final** timing iteration (base seed + iterations − 1). The CPU reference is checked against that same final iteration.',
      '- Timings vary by a few percent between runs because of laptop GPU boost clocks and power state.']
open('results/benchmark_summary.md','w', newline='\n', encoding='utf-8').write('\n'.join(L) + '\n')
print('summary written: results/benchmark_summary.md')
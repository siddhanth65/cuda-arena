# CUDA Arena — Final Submission Checklist

Prepared 2026-11-27. Nothing has been submitted to Coursera; uploading is a manual step for you.

## Deliverables

| Deliverable | Path | Status |
|---|---|---|
| Proof-of-execution ZIP | `deliverables/cuda-arena-proof.zip` (2.9 MB) | Built and verified: all 6 files present, archive test passes |
| Presentation video | `deliverables/cuda-arena-demo.mp4` (19.3 MB) | 7:19, 1920x1080, H.264 High + AAC 48 kHz stereo; full decode with 0 errors; audio present (mean −23.3 dB) |
| Code repository | https://github.com/siddhanth65/cuda-arena (`main`) | Evidence, fixes and video pushed |

**ZIP contents:** `results/full_session.log`, `results/tournament.log`, `results/tournament_results.csv`, `results/benchmark_summary.md`, `evidence/cuda-run.png`, plus `results/screenshot_run.log` (the log of the run shown in the screenshot).

## Actual results (from `results/full_session.log`)

- **GPU:** NVIDIA GeForce RTX 3050 Laptop GPU (4 GB, compute capability 8.6, 16 SMs), driver 621.14
- **Toolchain:** CUDA 13.0 (V13.0.88) in `nvidia/cuda:13.0.1-devel-ubuntu24.04`, Docker Desktop WSL2 backend, Windows 11 Home
- **Build:** `make clean && make` succeeded with no errors or warnings
- **Main benchmark (1,048,576 games, 5 iterations):** 1.5826 ms average kernel time, 662.57 M games/s; single-thread CPU reference 531.70 ms
- **Outcomes:** X 339,530 (32.38%), O 0, draws 709,046 (67.62%), average 8.3524 moves per game
- **CPU/GPU consistency:** PASS in every run (smoke test, main benchmark, and 1,024 / 16,384 / 262,144 sweep)
- **Batch sweep throughput:** 74.6 M games/s at 1,024 games, 516.6 M at 16,384, 664.0 M at 262,144
- **CSV validation:** PASS (row counts, sequential IDs, valid winners, legal move counts)
- Two later live runs (the screenshot run and the video run) produced identical outcome counts and kernel times within about 2% (1.5473 ms and 1.5532 ms).

## Changes made by Claude (AI assistant) — disclose as appropriate

1. `.gitattributes` added to force LF line endings for scripts and the Makefile (Windows CRLF checkouts broke `run_demo.sh` under bash).
2. `scripts/run_demo.sh` marked executable in git.
3. `.gitignore` corrected: it now ignores the real build outputs (`cuda_tournament`, `cuda_arena_duel`) and no longer hides `results/*.log`.
4. Escaped backticks fixed in `README.md`, `results/README.md`, `SUBMISSION_GUIDE.md` and `presentation/speaker_script.md`, so code formatting renders on GitHub.
5. README updated with measured results and the Windows/Docker reproduction steps.
6. New scripts: `full_session.sh`, `screenshot_run.sh`, `validate_results.py`, `make_summary.py`, `make_proof_zip.py`, `capture_window.ps1`, `capture_screenshot.ps1`, plus `presentation/make_narration.ps1`, `record_screen.ps1` and `build_video.ps1`.
7. `presentation/final_narration.md` and the video's narration were drafted by Claude.
8. **No CUDA source code was changed.** `src/*.cu` is your original code.

The GitHub contributor list shows "claude" because the commits carry a `Co-Authored-By` line.

## Remaining manual steps

- [ ] Watch the whole video once and listen to the narration. The voice is synthetic (Windows SAPI "Microsoft David"); the opening and closing cards disclose this and the AI-drafted script.
- [ ] Optional: record your own voice-over from `presentation/final_narration.md` (reword it in your own words first), save it per scene as `presentation/build/sceneN.wav`, and re-run `presentation/build_video.ps1`.
- [ ] Known cosmetic gap: in Scene 2 the README did not scroll during recording, so the repository's file listing stays on screen instead.
- [ ] Read Coursera's Honor Code and academic-integrity guidance for this capstone, and disclose the AI assistance (list above) wherever the course asks.
- [ ] Personalise the project description in `SUBMISSION_GUIDE.md`.
- [ ] Upload `deliverables/cuda-arena-proof.zip` to the proof-of-execution field and `deliverables/cuda-arena-demo.mp4` (or a link to it) to the presentation field. Submit the repository URL.
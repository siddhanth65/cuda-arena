import zipfile, os
files = ["results/full_session.log","results/tournament.log","results/tournament_results.csv",
         "results/benchmark_summary.md","evidence/cuda-run.png","results/screenshot_run.log"]
out = "deliverables/cuda-arena-proof.zip"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for f in files: zf.write(f, f)
with zipfile.ZipFile(out) as zf:
    assert zf.testzip() is None
    names = zf.namelist()
    for i in zf.infolist(): print(f"{i.file_size:>10}  {i.filename}")
missing = [f for f in files if f not in names]
print("ZIP:", out, os.path.getsize(out), "bytes;", "all files present" if not missing else f"MISSING {missing}")
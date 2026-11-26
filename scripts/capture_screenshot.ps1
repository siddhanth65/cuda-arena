# Opens a real terminal window, runs the live GPU benchmark in it, then captures only that window to evidence/cuda-run.png.
$repo = Split-Path $PSScriptRoot -Parent
$run = "Set-Location '$repo'; `$host.UI.RawUI.WindowTitle='CUDA Arena - live GPU run'; Write-Host ('CUDA Arena live run on ' + `$env:COMPUTERNAME + '  ' + (Get-Date)) -ForegroundColor Cyan; docker run --rm --gpus all -v '${repo}:/work' -w /work --entrypoint /bin/bash nvidia/cuda:13.0.1-devel-ubuntu24.04 scripts/screenshot_run.sh"
$p = Start-Process powershell.exe -ArgumentList '-NoExit','-NoProfile','-Command',$run -WindowStyle Maximized -PassThru
Start-Sleep 20
& (Join-Path $PSScriptRoot 'capture_window.ps1')

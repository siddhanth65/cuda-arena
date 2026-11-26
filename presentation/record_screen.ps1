# Records REAL screen footage for scenes 1-7 with ffmpeg gdigrab while driving Chrome, VS Code and a terminal.
# Keystrokes are only sent when the intended window is verified to be in the foreground; otherwise the script aborts.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent; Set-Location $repo
$b = Join-Path $repo 'presentation\build'
$ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe | Select -First 1 -Expand FullName
$scenes = Get-Content "$b\scenes.json" -Raw | ConvertFrom-Json
function Dur($n) { [double](($scenes | ? Scene -eq $n).Seconds) + 2.0 }
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  public static IntPtr Find(string t) { IntPtr r = IntPtr.Zero;
    EnumWindows((h, l) => { var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      if (IsWindowVisible(h) && sb.ToString().Contains(t)) { r = h; return false; } return true; }, IntPtr.Zero); return r; }
  public static void Focus(IntPtr h) { keybd_event(0x12,0,0,UIntPtr.Zero); keybd_event(0x12,0,2,UIntPtr.Zero); ShowWindow(h, 3); SetForegroundWindow(h); }
}
"@
$wsh = New-Object -ComObject WScript.Shell
function Focus-Title($t) {
  for ($i = 0; $i -lt 40; $i++) { $h = [Win]::Find($t); if ($h -ne [IntPtr]::Zero) { [Win]::Focus($h); Start-Sleep -Milliseconds 400; if ([Win]::GetForegroundWindow() -eq $h) { return $h } }; Start-Sleep -Milliseconds 500 }
  throw "Could not bring window '$t' to the foreground - aborting so no keystrokes go elsewhere." }
function Send-Safe($h, $keys) { if ([Win]::GetForegroundWindow() -ne $h) { throw 'Target window lost focus - aborting.' }; $wsh.SendKeys($keys) }
function Esc($s) { ($s.ToCharArray() | % { if ('+^%~(){}[]'.Contains([string]$_)) { '{' + $_ + '}' } else { [string]$_ } }) -join '' }
function Type-Cmd($h, $cmd) { foreach ($c in $cmd.ToCharArray()) { Send-Safe $h (Esc ([string]$c)); Start-Sleep -Milliseconds 18 }; Start-Sleep -Milliseconds 300; Send-Safe $h '{ENTER}' }
function Start-Rec($n) {
  $psi = New-Object Diagnostics.ProcessStartInfo $ff, "-y -hide_banner -loglevel error -f gdigrab -framerate 30 -draw_mouse 0 -i desktop -c:v libx264 -preset ultrafast -crf 16 -pix_fmt yuv420p `"$b\screen$n.mkv`""
  $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.CreateNoWindow = $true
  $p = [Diagnostics.Process]::Start($psi); Start-Sleep -Milliseconds 800; $p }
function Stop-Rec($p) { $p.StandardInput.Write('q'); $p.StandardInput.Flush(); [void]$p.WaitForExit(20000) }
function Wait-To($t0, $s) { while (((Get-Date) - $t0).TotalSeconds -lt $s) { Start-Sleep -Milliseconds 150 } }
function Code-Goto($target) { Start-Process -WindowStyle Hidden cmd.exe -ArgumentList "/c code -r -g `"$target`"" }

# ---------- setup (not recorded) ----------
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") | ? { Test-Path $_ } | Select -First 1
Start-Process $chrome -ArgumentList '--new-window','https://github.com/siddhanth65/cuda-arena'
Start-Process -WindowStyle Hidden cmd.exe -ArgumentList "/c code -n -g `"$repo\src\cuda_tournament.cu:146`""
$init = "`$host.UI.RawUI.WindowTitle='CUDA Arena - demo terminal'; Set-Location '$repo'; " +
  "function arena([string]`$c) { docker run --rm --gpus all -v `"`${PWD}:/work`" -w /work --entrypoint /bin/bash nvidia/cuda:13.0.1-devel-ubuntu24.04 -c `$c }; " +
  "Clear-Host; Write-Host 'CUDA Arena demo terminal - Windows 11 + Docker Desktop (WSL2) + NVIDIA GeForce RTX 3050 Laptop GPU' -ForegroundColor Cyan; " +
  "Write-Host 'arena ""<cmd>"" runs <cmd> in the official nvidia/cuda:13.0.1-devel-ubuntu24.04 container with GPU access' -ForegroundColor DarkGray; Write-Host ''"
Start-Process powershell.exe -ArgumentList '-NoExit','-NoProfile','-Command',$init
Start-Sleep 8
$term = Focus-Title 'CUDA Arena - demo terminal'; foreach ($k in 1..3) { Send-Safe $term '^{=}'; Start-Sleep -Milliseconds 200 }
$code = Focus-Title 'cuda_tournament.cu'
$web  = Focus-Title 'siddhanth65/cuda-arena'; Send-Safe $web '{HOME}'; Start-Sleep 2

# ---------- Scene 1: introduction (repo home) ----------
$web = Focus-Title 'siddhanth65/cuda-arena'; $r = Start-Rec 1; $t0 = Get-Date; Wait-To $t0 (Dur 1); Stop-Rec $r
# ---------- Scene 2: README scroll ----------
$web = Focus-Title 'siddhanth65/cuda-arena'; $r = Start-Rec 2; $t0 = Get-Date; $d = Dur 2
foreach ($k in 1..6) { Wait-To $t0 ($d * $k / 7); Send-Safe $web '{PGDN}' }; Wait-To $t0 $d; Stop-Rec $r
# ---------- Scene 3: kernel source ----------
Code-Goto "$repo\src\cuda_tournament.cu:146"; Start-Sleep 2
$code = Focus-Title 'cuda_tournament.cu'; $r = Start-Rec 3; $t0 = Get-Date; $d = Dur 3
Wait-To $t0 ($d * 0.33); Code-Goto "$repo\src\cuda_tournament.cu:122"
Wait-To $t0 ($d * 0.50); Code-Goto "$repo\src\cuda_tournament.cu:98"
Wait-To $t0 ($d * 0.72); Code-Goto "$repo\src\cuda_tournament.cu:122"
Wait-To $t0 ($d * 0.86); Code-Goto "$repo\src\cuda_tournament.cu:286"
Wait-To $t0 $d; Stop-Rec $r
# ---------- Scene 4: compile ----------
$term = Focus-Title 'CUDA Arena - demo terminal'; $r = Start-Rec 4; $t0 = Get-Date
Start-Sleep 1; Type-Cmd $term 'arena "nvcc --version | tail -2; make clean && make"'; Wait-To $t0 (Dur 4); Stop-Rec $r
# ---------- Scene 5: live GPU run ----------
$term = Focus-Title 'CUDA Arena - demo terminal'; Type-Cmd $term 'cls'; Start-Sleep 1
$r = Start-Rec 5; $t0 = Get-Date; Start-Sleep 1
Type-Cmd $term 'arena "./cuda_tournament --games 1048576 --iterations 5 --seed 2026 --no-csv | tee results/video_run.log"'; Wait-To $t0 (Dur 5); Stop-Rec $r
# ---------- Scene 6: verification ----------
$term = Focus-Title 'CUDA Arena - demo terminal'; $r = Start-Rec 6; $t0 = Get-Date; Start-Sleep 1
Type-Cmd $term 'python scripts/validate_results.py'; Wait-To $t0 (Dur 6); Stop-Rec $r
# ---------- Scene 7: CSV + benchmark summary ----------
$term = Focus-Title 'CUDA Arena - demo terminal'; Type-Cmd $term 'cls'; Start-Sleep 1
$r = Start-Rec 7; $t0 = Get-Date; $d = Dur 7; Start-Sleep 1
Type-Cmd $term 'Get-Content results/tournament_results.csv -TotalCount 15'
Wait-To $t0 ($d * 0.30); Code-Goto "$repo\results\benchmark_summary.md:1"; Start-Sleep 2
$code = Focus-Title 'benchmark_summary.md'
Wait-To $t0 ($d * 0.62); Send-Safe $code '^{END}'; Start-Sleep -Milliseconds 300; Send-Safe $code '^{HOME}'
foreach ($k in 1..12) { Send-Safe $code '{DOWN}' }; foreach ($k in 1..10) { Send-Safe $code '{DOWN}' }
Wait-To $t0 ($d * 0.80); foreach ($k in 1..14) { Send-Safe $code '{DOWN}' }
Wait-To $t0 $d; Stop-Rec $r
"Recording finished: " + ((1..7 | % { "screen$_.mkv=" + [math]::Round((Get-Item "$b\screen$_.mkv").Length/1MB,1) + 'MB' }) -join ', ')
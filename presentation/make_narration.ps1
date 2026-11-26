# Generates per-scene synthetic narration (Windows SAPI, local, offline) from presentation/final_narration.md.
$repo = Split-Path $PSScriptRoot -Parent; Set-Location $repo
$b = "presentation\build"; New-Item -ItemType Directory -Force $b | Out-Null
$md = [IO.File]::ReadAllText("$repo\presentation\final_narration.md")
$scenes = [regex]::Matches($md, '(?ms)^## Scene (\d+) — ([^(]+?) \(.*?\)\s*$(.*?)(?=^## Scene|^---)')
Add-Type -AssemblyName System.Speech
$fp = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffprobe.exe | Select -First 1 -Expand FullName
$meta = @()
foreach ($m in $scenes) {
  $n = $m.Groups[1].Value; $title = $m.Groups[2].Value.Trim()
  $text = ($m.Groups[3].Value -split "`n" | ? { $_.Trim() -and $_ -notmatch '^\*\*On screen' }) -join ' '
  $text = ($text -replace '`','' -replace '\*','').Trim()
  [IO.File]::WriteAllText("$repo\$b\scene$n.txt", $text)
  $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.SelectVoice('Microsoft David Desktop'); $s.Rate = -1
  $s.SetOutputToWaveFile("$repo\$b\scene$n.wav"); $s.Speak($text); $s.Dispose()
  $d = [double](& $fp -v error -show_entries format=duration -of csv=p=0 "$b\scene$n.wav")
  $meta += [pscustomobject]@{Scene=[int]$n; Title=$title; Seconds=[math]::Round($d,2)}
}
$meta | ConvertTo-Json | Set-Content "$b\scenes.json" -Encoding utf8
$meta | Format-Table -AutoSize | Out-String
"TOTAL narration: {0:N2} min" -f (($meta | Measure Seconds -Sum).Sum/60)
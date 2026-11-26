# Composes deliverables/cuda-arena-demo.mp4 from real screen recordings (build/screen1..7.mkv),
# synthetic narration (build/sceneN.wav), generated title cards and burned-in captions.
param([switch]$CardsOnlyTest)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent; $b = Join-Path $repo 'presentation\build'; Set-Location $b
$ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe | Select -First 1 -Expand FullName
$fp = Join-Path (Split-Path $ff) 'ffprobe.exe'
$scenes = Get-Content scenes.json -Raw | ConvertFrom-Json
$utf8 = New-Object Text.UTF8Encoding $false
$FB = "'C\:/Windows/Fonts/segoeuib.ttf'"; $FR = "'C\:/Windows/Fonts/segoeui.ttf'"
$BG = '0x0d1117'; $ACC = '0x76b900'
function FF([string[]]$a) { & $ff -y -hide_banner -loglevel error @a; if ($LASTEXITCODE) { throw "ffmpeg failed: $($a -join ' ')" } }
function TF($name, $text) { [IO.File]::WriteAllText("$b\$name", $text, $utf8); return $name }
$ENC = @('-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-r','30','-c:a','aac','-b:a','192k','-ar','48000','-ac','2')

function Card($out, $dur, [string[]]$draws) {
  $vf = (@($draws) + "fade=t=in:st=0:d=0.4,fade=t=out:st=$($dur-0.4):d=0.4") -join ','
  FF (@('-f','lavfi','-i',"color=c=${BG}:s=1920x1080:r=30:d=$dur",'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t',"$dur",'-vf',$vf) + $ENC + @($out))
}
function DT($file, $font, $size, $color, $x, $y) { "drawtext=fontfile=${font}:textfile=${file}:fontsize=${size}:fontcolor=${color}:x=${x}:y=${y}:line_spacing=14" }

function Srt($n, $offset, $total) {
  $text = Get-Content "scene$n.txt" -Raw
  $sent = [regex]::Split($text.Trim(), '(?<=[.!?])\s+') | ? { $_ }
  $chunks = foreach ($s in $sent) { $w = $s -split '\s+'; $cur = ''
    foreach ($x in $w) { if (($cur + ' ' + $x).Trim().Length -gt 84) { $cur.Trim(); $cur = $x } else { $cur = "$cur $x" } }; $cur.Trim() }
  $chars = ($chunks | % { $_.Length } | Measure -Sum).Sum; $t = $offset; $i = 0; $sb = New-Object Text.StringBuilder
  foreach ($c in $chunks) { $i++; $d = $total * $c.Length / $chars
    $f = { param($s) $ts = [TimeSpan]::FromSeconds($s); '{0:00}:{1:00}:{2:00},{3:000}' -f [int][math]::Floor($ts.TotalHours), $ts.Minutes, $ts.Seconds, $ts.Milliseconds }
    [void]$sb.AppendLine($i); [void]$sb.AppendLine("$(& $f $t) --> $(& $f ($t+$d))"); [void]$sb.AppendLine($c); [void]$sb.AppendLine(); $t += $d }
  [IO.File]::WriteAllText("$b\scene$n.srt", $sb.ToString(), $utf8)
}
$SUB = "force_style='FontName=Segoe UI,FontSize=17,PrimaryColour=&H00FFFFFF,BackColour=&H99000000,BorderStyle=3,Outline=6,Shadow=0,MarginV=36'"

function SceneSeg($n, $title, $videoInput) {
  $wav = ($scenes | ? Scene -eq $n).Seconds; $dur = [math]::Round($wav + 1.0, 2)
  Srt $n 0.5 $wav
  $lab = TF "label$n.txt" ("{0} / 8   {1}" -f $n, $title)
  $vf = "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30," +
        "drawbox=x=0:y=0:w=iw:h=6:color=${ACC}@1:t=fill," +
        "drawbox=x=24:y=24:w=tw:h=52:color=black@0.72:t=fill," -replace 'w=tw','w=620'
  $vf += (DT $lab $FB 26 'white' 40 36) + ",subtitles=scene$n.srt:$SUB,fade=t=in:st=0:d=0.4,fade=t=out:st=$($dur-0.4):d=0.4"
  $af = "adelay=500|500,apad,atrim=0:$dur,afade=t=in:st=0:d=0.3,afade=t=out:st=$($dur-0.4):d=0.4"
  FF (@() + $videoInput + @('-i',"scene$n.wav",'-t',"$dur",'-map','0:v','-map','1:a','-vf',$vf,'-af',$af) + $ENC + @("seg_scene$n.mp4"))
}

# ---- cards ----
$t1 = TF 'c_title.txt' 'CUDA Arena'
$t2 = TF 'c_sub.txt' 'Massively Parallel GPU Tic-Tac-Toe Tournament'
$t3 = TF 'c_who.txt' "Siddhanth Susheel`nCoursera capstone project  ·  github.com/siddhanth65/cuda-arena"
$t4 = TF 'c_disc.txt' "All footage is real screen capture from the author's laptop (NVIDIA GeForce RTX 3050 Laptop GPU).`nAll results are real measurements.  Narration is a synthetic text-to-speech voice (Microsoft David, Windows SAPI).`nThe narration script was drafted with AI assistance (Claude)."
Card 'seg_00_intro.mp4' 7 @("drawbox=x=0:y=0:w=iw:h=10:color=${ACC}@1:t=fill", (DT $t1 $FB 110 'white' '(w-text_w)/2' 300), (DT $t2 $FR 48 $ACC '(w-text_w)/2' 450), (DT $t3 $FR 34 '0xc9d1d9' '(w-text_w)/2' 590), (DT $t4 $FR 24 '0x8b949e' '(w-text_w)/2' 820))
foreach ($sc in $scenes) {
  $a = TF "s_num$($sc.Scene).txt" ("{0} / 8" -f $sc.Scene); $c = TF "s_t$($sc.Scene).txt" $sc.Title
  Card ("seg_{0}a_card.mp4" -f $sc.Scene) 2.5 @("drawbox=x=0:y=0:w=iw:h=10:color=${ACC}@1:t=fill", (DT $a $FR 40 $ACC '(w-text_w)/2' 440), (DT $c $FB 72 'white' '(w-text_w)/2' 510))
}
$o1 = TF 'c_end.txt' 'Thank you'
$o2 = TF 'c_end2.txt' "github.com/siddhanth65/cuda-arena`nEvidence: results/full_session.log  ·  results/benchmark_summary.md  ·  evidence/cuda-run.png"
Card 'seg_99_outro.mp4' 6 @("drawbox=x=0:y=0:w=iw:h=10:color=${ACC}@1:t=fill", (DT $o1 $FB 96 'white' '(w-text_w)/2' 380), (DT $o2 $FR 32 '0xc9d1d9' '(w-text_w)/2' 540), (DT $t4 $FR 24 '0x8b949e' '(w-text_w)/2' 820))

# ---- scene 8: limitations slide (generated card, not screen footage) ----
$l1 = TF 'l_head.txt' 'Limitations'
$l2 = TF 'l_body.txt' ("•  GPU time is kernel-only; the CPU baseline is single-threaded,`n    so the real end-to-end speedup is far below 336x.`n" +
  "•  Simple heuristic agents: Agent O never won; every decisive game`n    was an X win on move 7.`n" +
  "•  Measured on one laptop (RTX 3050 Laptop GPU); timings vary`n    by a few percent between runs.")
$l3 = TF 'l_head2.txt' 'Conclusion'
$l4 = TF 'l_body2.txt' "One thread per game  ·  one host/device function for exact verification  ·  fill the GPU with enough work"
$d8 = [math]::Round((($scenes | ? Scene -eq 8).Seconds) + 1.0, 2)
FF @('-f','lavfi','-i',"color=c=${BG}:s=1920x1080:r=30:d=$d8",'-vf',
  ("drawbox=x=0:y=0:w=iw:h=10:color=${ACC}@1:t=fill," + (DT $l1 $FB 64 'white' 160 150) + ',' + (DT $l2 $FR 38 '0xe6edf3' 160 260) + ',' + (DT $l3 $FB 52 $ACC 160 720) + ',' + (DT $l4 $FR 32 '0xc9d1d9' 160 800)),
  '-t',"$d8",'-c:v','libx264','-crf','12','-pix_fmt','yuv420p','screen8.mkv')
$order = @('seg_00_intro.mp4')
foreach ($sc in $scenes) {
  $n = $sc.Scene
  if ($CardsOnlyTest -and $n -ne 8) { continue }
  $src = if ($n -eq 8) { @('-i','screen8.mkv') } else { @('-ss','0.5','-i',"screen$n.mkv") }
  if (-not (Test-Path "screen$n.mkv")) { throw "Missing real screen recording screen$n.mkv - run record_screen.ps1 first" }
  SceneSeg $n $sc.Title $src
  $order += ("seg_{0}a_card.mp4" -f $n); $order += "seg_scene$n.mp4"
}
$order += 'seg_99_outro.mp4'
[IO.File]::WriteAllText("$b\concat.txt", (($order | % { "file '$_'" }) -join "`n"), $utf8)
$out = if ($CardsOnlyTest) { "$b\test_cards_only.mp4" } else { Join-Path $repo 'deliverables\cuda-arena-demo.mp4' }
FF @('-f','concat','-safe','0','-i','concat.txt','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',$out)
"Wrote $out"
& $fp -v error -show_entries format=duration:stream=codec_name,codec_type,width,height -of compact $out
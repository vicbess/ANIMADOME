# Régénère beats.js (kick/kickS/hit/hitS) à partir de stems.js — à lancer après analyze-stems.py / analyze-extra.py
# Usage : powershell -ExecutionPolicy Bypass -File tools\stems-to-beats.ps1 -Dir mixes\<mix>
param([Parameter(Mandatory)][string]$Dir)   # dossier du mix, ex. mixes\pyrobeats
$root = if ([System.IO.Path]::IsPathRooted($Dir)) { $Dir } else { Join-Path (Split-Path -Parent $PSScriptRoot) $Dir }
$s = [IO.File]::ReadAllText("$root\stems.js"); $s = $s.Substring($s.IndexOf('=')+1).TrimEnd(';'); $o = $s | ConvertFrom-Json
$ci = [Globalization.CultureInfo]::InvariantCulture
$f = { param($a,[string]$fmt) ($a | ForEach-Object { $_.ToString($fmt,$ci) }) -join ',' }
$out = "window.BEATS={kick:[" + (& $f $o.kick 'F2') + "],kickS:[" + (($o.kickS) -join ',') + "],hit:[" + (& $f $o.hit 'F2') + "],hitS:[" + (($o.hitS) -join ',') + "]};"
[IO.File]::WriteAllText("$root\beats.js", $out, (New-Object Text.UTF8Encoding($false)))
"beats.js : $($o.kick.Count) kicks, $($o.hit.Count) frappes"
# Reconstruit show.html (la page que le navigateur ouvre) à partir de show.template.html (le code source)
# et de dome-geometry.json (le plan du dôme, inséré à la place de /*DOME_JSON*/).
# À lancer après toute modification de show.template.html :
#   powershell -ExecutionPolicy Bypass -File dome-preview\build.ps1
param([string]$Dir = $PSScriptRoot)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = Join-Path $Dir 'show.template.html'
$t = [System.IO.File]::ReadAllText($src, $utf8)
if (-not $t.Contains('/*DOME_JSON*/')) { throw "L'ancre /*DOME_JSON*/ est introuvable dans show.template.html" }
if (-not $t.Contains('<!doctype html>')) { throw "show.template.html semble tronqué (pas de <!doctype html>)" }
$geo = [System.IO.File]::ReadAllText((Join-Path $Dir 'dome-geometry.json'), $utf8)
$out = Join-Path $Dir 'show.html'
[System.IO.File]::WriteAllText($out, $t.Replace('/*DOME_JSON*/', $geo), $utf8)
"show.html reconstruit ({0:N0} Ko)" -f ((Get-Item $out).Length / 1KB)

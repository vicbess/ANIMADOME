# Prépare un nouveau mix pour ANIMADÔme : audio 128 kbps + analyse (énergie par bandes, kicks/hits) + dossier prêt à l'emploi.
#   powershell -ExecutionPolicy Bypass -File tools\analyze-mix.ps1 -Audio "C:\...\mix.mp3" -OutDir "mixes\monmix"
param([Parameter(Mandatory)][string]$Audio, [Parameter(Mandatory)][string]$OutDir)
$root = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $root $OutDir }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) { $ff = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
$tmp = Join-Path $env:TEMP ('animadome_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmp | Out-Null
& $ff -hide_banner -loglevel error -y -i $Audio -ac 2 -b:a 128k (Join-Path $OutDir 'audio.mp3')
& $ff -hide_banner -loglevel error -y -i $Audio -ac 1 -ar 22050 -f s16le (Join-Path $tmp 'mono22k.raw')
& (Join-Path $PSScriptRoot 'analyze-features.ps1') -raw (Join-Path $tmp 'mono22k.raw') -out (Join-Path $tmp 'features.json')
& (Join-Path $PSScriptRoot 'analyze-beats.ps1') -raw (Join-Path $tmp 'mono22k.raw') -out (Join-Path $OutDir 'beats.js')
$f = Get-Content (Join-Path $tmp 'features.json') -Raw | ConvertFrom-Json
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function J($a,$dd){ ($a | ForEach-Object { ([math]::Round([double]$_,$dd)).ToString($inv) }) -join ',' }
$s = "window.FEATURES={hop:0.1,frames:$($f.frames),rms:[$(J $f.rmsDb 1)],sub:[$(J $f.b0 1)],bass:[$(J $f.b1 1)],lowmid:[$(J $f.b2 1)],mid:[$(J $f.b3 1)],high:[$(J $f.b4 1)],flux:[$(J $f.flux 0)]};"
[System.IO.File]::WriteAllText((Join-Path $OutDir 'features.js'), $s, (New-Object System.Text.UTF8Encoding($false)))
$dur = [math]::Floor($f.frames / 10)
$fx = Join-Path $OutDir 'fxmap.js'
if (-not (Test-Path $fx)) { [System.IO.File]::WriteAllText($fx, "window.FXMAP={phases:{},events:{}};", (New-Object System.Text.UTF8Encoding($false))) }
if (-not (Test-Path (Join-Path $OutDir 'prompts.jsonl'))) { New-Item (Join-Path $OutDir 'prompts.jsonl') -ItemType File | Out-Null }
if (-not (Test-Path (Join-Path $OutDir 'prompts-done.json'))) { [System.IO.File]::WriteAllText((Join-Path $OutDir 'prompts-done.json'), '{}') }
Remove-Item $tmp -Recurse -Force
"Mix prêt dans $OutDir (durée analysée : $dur s)"

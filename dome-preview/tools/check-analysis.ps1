# Vérifie que les outils d'analyse du son sont installés. Affiche un JSON : { ok, python, ffmpeg, missing:[...], help }.
#   powershell -ExecutionPolicy Bypass -File tools\check-analysis.ps1 [-NeedStems]
# -NeedStems : exige aussi Demucs et PyTorch (séparation des stems, utile quand on n'a pas de pistes séparées).
param([switch]$NeedStems)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot           # dome-preview
$repo = Split-Path -Parent $root                    # racine du dépôt
$missing = @()
# Python : l'environnement du projet (audio-analysis\venv) d'abord, sinon celui du PATH
$py = Join-Path $repo 'audio-analysis\venv\Scripts\python.exe'
if (-not (Test-Path $py)) { $py = (Get-Command python -ErrorAction SilentlyContinue).Source }
if (-not $py) { $missing += 'Python 3.11' }
else {
  $mods = @('numpy', 'scipy', 'librosa', 'soundfile'); if ($NeedStems) { $mods += @('torch', 'demucs') }
  foreach ($m in $mods) { & $py -I -c "import $m" 2>$null; if ($LASTEXITCODE -ne 0) { $missing += "module Python « $m »" } }
}
# ffmpeg
$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) { $ff = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
if (-not $ff) { $missing += 'ffmpeg' }
$help = "Outils d'analyse non installés. Installe Python 3.11, ffmpeg, puis dans un terminal : python -m venv audio-analysis\venv ; audio-analysis\venv\Scripts\pip install numpy scipy librosa soundfile" + $(if ($NeedStems) { ' torch torchaudio demucs' } else { '' }) + " (voir le README, section « Analyse du son »)."
$o = [ordered]@{ ok = ($missing.Count -eq 0); python = $py; ffmpeg = $ff; missing = $missing; help = $help }
$o | ConvertTo-Json -Compress

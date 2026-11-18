# Installe les outils d'analyse du son d'ANIMADÔME (lancé par le bouton « Installer » de la page, ou à la main) :
#  Python 3.11 (winget, si absent) -> environnement audio-analysis\venv -> modules Python (numpy, scipy, librosa, soundfile, torch, demucs, beat-this, mdxnet-infer).
# ffmpeg s'installe à part (bouton d'installation de ffmpeg). PyTorch avec CUDA reste conseillé pour aller vite : voir le README, section « Analyse du son ».
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot      # dome-preview
$repo = Split-Path -Parent $root              # racine du dépôt
$venv = Join-Path $repo 'audio-analysis\venv'
$py = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $py)) {
  $sys = $null
  $cands = @((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'), 'C:\Program Files\Python311\python.exe')
  foreach ($c in $cands) { if (Test-Path $c) { $sys = $c; break } }
  if (-not $sys) {
    $g = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($g -and $g -notmatch 'WindowsApps') { $v = & $g --version 2>&1; if ("$v" -match 'Python 3\.(10|11|12)') { $sys = $g } }
  }
  if (-not $sys) {
    'Installation de Python 3.11 (winget)...'
    winget install --id Python.Python.3.11 -e --silent --accept-package-agreements --accept-source-agreements
    foreach ($c in $cands) { if (Test-Path $c) { $sys = $c; break } }
  }
  if (-not $sys) { throw 'Python 3.11 introuvable après installation : ferme et rouvre ANIMADÔME puis recommence.' }
  "Création de l'environnement : $venv"
  New-Item -ItemType Directory -Force (Split-Path -Parent $venv) | Out-Null
  & $sys -m venv $venv
}
'Installation des modules Python (plusieurs Go : PyTorch, Demucs...), patience.'
& $py -m pip install --upgrade pip
& $py -m pip install numpy scipy scikit-learn librosa soundfile torch torchaudio demucs beat-this mdxnet-infer
if ($LASTEXITCODE -ne 0) { throw "pip a échoué (code $LASTEXITCODE)" }
'Outils d''analyse installés.'

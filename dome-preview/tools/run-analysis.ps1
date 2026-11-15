# Analyse d'un mix : lance toutes les étapes dans l'ordre et écrit sa progression sur la sortie standard
# (le serveur la recopie dans mixes\<mix>\analysis.log, que la page affiche).
#   - sans -Tracks : une seule piste, l'audio à lire (A)
#   - avec -Tracks : les pistes séparées de mixes\<mix>\tracks\ (la piste dont le nom contient « music » sert à la batterie et aux stems, sinon la plus forte)
#   Étapes : énergie par bandes -> départs de sons de chaque piste + batterie séparée (htdemucs_ft, drumsep) + temps (beat_this)
#            -> stems (basse, voix, aigus, notes, rugosité) -> kicks / frappes appliqués aux fichiers lus par la page.
#   powershell -ExecutionPolicy Bypass -File tools\run-analysis.ps1 -MixDir "mixes\pyrobeats" [-Tracks]
param([Parameter(Mandatory)][string]$MixDir, [switch]$Tracks)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING = 'utf-8'
$root = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($MixDir)) { $MixDir = Join-Path $root $MixDir }
function L($s) { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $s }
function Fail($code, $s) { L "ERREUR: $s"; exit $code }

$mj = Join-Path $MixDir 'mix.json'
if (-not (Test-Path $mj)) { Fail 3 "mix.json introuvable dans $MixDir" }
$audioRel = (Get-Content $mj -Raw -Encoding UTF8 | ConvertFrom-Json).audio
$audio = Join-Path $MixDir ($audioRel -replace '/', '\')
if (-not (Test-Path $audio)) { Fail 3 "le fichier audio à lire est introuvable : $audio" }

L "Vérification des outils d'analyse..."
$chk = & (Join-Path $PSScriptRoot 'check-analysis.ps1') | ConvertFrom-Json
if (-not $chk.ok) { L ("ERREUR OUTILS: manquants : " + ($chk.missing -join ', ')); L $chk.help; exit 2 }
$py = $chk.python
$tracksDir = Join-Path $MixDir 'tracks'
if ($Tracks -and -not (Get-ChildItem $tracksDir -File -ErrorAction SilentlyContinue)) { Fail 3 "aucune piste dans $tracksDir" }
if (-not $Tracks -and (Test-Path $tracksDir)) { Remove-Item $tracksDir -Recurse -Force -ErrorAction SilentlyContinue }   # sans -Tracks, l'audio à lire est la seule piste

L "ETAPE 1/4 : énergie par bandes de l'audio à lire"
& (Join-Path $PSScriptRoot 'analyze-mix.ps1') -Audio $audio -OutDir $MixDir -NoAudioCopy | ForEach-Object { L $_ }
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { Fail 4 "analyse de l'énergie en échec" }

$work = Join-Path $env:TEMP ('animadome_v2_' + [guid]::NewGuid().ToString('N'))
try {
  L "ETAPE 2/4 : départs de sons par piste, séparation de la batterie, temps (longue étape : plusieurs dizaines de minutes sur un mix d'une heure)"
  & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-v2.py') $MixDir --work $work 2>&1 | ForEach-Object { if ("$_" -notmatch 'Separating|\d+%\||it/s\]') { "$_" } }
  if ($LASTEXITCODE -ne 0) { Fail 5 "analyse des pistes en échec (code $LASTEXITCODE)" }
  $drums = Get-ChildItem $work -Recurse -Filter drums.wav | Select-Object -First 1
  if (-not $drums) { Fail 5 "les stems séparés sont introuvables" }
  $sd = $drums.DirectoryName; $sj = Join-Path $MixDir 'stems.js'
  L "ETAPE 3/4 : stems (basse, voix, aigus, notes, rugosité)"
  & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-stems.py') $sd $sj; if ($LASTEXITCODE -ne 0) { Fail 6 "analyse des stems en échec" }
  & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-extra.py') $sd $sj; if ($LASTEXITCODE -ne 0) { Fail 6 "compléments en échec" }
  L "ETAPE 4/4 : kicks, frappes et temps appliqués au mix"
  & $py -I -X utf8 (Join-Path $PSScriptRoot 'apply-analysis-v2.py') $MixDir | ForEach-Object { L $_ }
  if ($LASTEXITCODE -ne 0) { Fail 7 "application de l'analyse en échec" }
} finally { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
if ($Tracks) { L "Suppression des copies de pistes (inutiles après l'analyse)"; Remove-Item $tracksDir -Recurse -Force -ErrorAction SilentlyContinue }
L "TERMINE : recharge la page pour utiliser la nouvelle analyse."
exit 0

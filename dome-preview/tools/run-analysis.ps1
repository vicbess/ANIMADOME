# Analyse d'un mix : lance toutes les étapes dans l'ordre et écrit sa progression sur la sortie standard
# (le serveur la recopie dans mixes\<mix>\analysis.log, que la page affiche).
#   - sans -Tracks : analyse du fichier audio seul (énergie par bandes, kicks, séparation des stems Demucs, rugosité)
#   - avec -Tracks : analyse des pistes séparées de mixes\<mix>\tracks\ (départs de sons, énergie, brillance) + analyse légère de l'audio à lire
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
$chk = & (Join-Path $PSScriptRoot 'check-analysis.ps1') -NeedStems:(-not $Tracks) | ConvertFrom-Json
if (-not $chk.ok) { L ("ERREUR OUTILS: manquants : " + ($chk.missing -join ', ')); L $chk.help; exit 2 }
$py = $chk.python

$total = if ($Tracks) { 2 } else { 5 }
L "ETAPE 1/${total} : énergie par bandes et kicks de l'audio à lire"
& (Join-Path $PSScriptRoot 'analyze-mix.ps1') -Audio $audio -OutDir $MixDir -NoAudioCopy | ForEach-Object { L $_ }
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { Fail 4 "analyse de l'énergie en échec" }

if ($Tracks) {
  L "ETAPE 2/${total} : analyse des pistes séparées"
  & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-tracks.py') (Join-Path $MixDir 'tracks') (Join-Path $MixDir 'tracks.js') $audio
  if ($LASTEXITCODE -ne 0) { Fail 5 "analyse des pistes en échec (code $LASTEXITCODE)" }
  # les pistes envoyées ne servent plus une fois analysées (tracks.js suffit) : on libère l'espace. En cas d'échec elles restent pour relancer.
  L "Suppression des copies de pistes (inutiles après l'analyse)"; Remove-Item (Join-Path $MixDir 'tracks') -Recurse -Force -ErrorAction SilentlyContinue
} else {
  $tmp = Join-Path $env:TEMP ('animadome_stems_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmp | Out-Null
  try {
    L "ETAPE 2/${total} : séparation des stems (Demucs) : cette étape est longue"
    & $py -m demucs -o $tmp $audio
    if ($LASTEXITCODE -ne 0) { Fail 5 "Demucs en échec (code $LASTEXITCODE)" }
    $stems = Get-ChildItem $tmp -Recurse -Filter drums.wav | Select-Object -First 1
    if (-not $stems) { Fail 5 "les stems séparés sont introuvables" }
    $sd = $stems.DirectoryName
    $sj = Join-Path $MixDir 'stems.js'
    L "ETAPE 3/${total} : analyse des stems"
    & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-stems.py') $sd $sj; if ($LASTEXITCODE -ne 0) { Fail 6 "analyse des stems en échec" }
    L "ETAPE 4/${total} : compléments (rugosité, notes)"
    & $py -I -X utf8 (Join-Path $PSScriptRoot 'analyze-extra.py') $sd $sj; if ($LASTEXITCODE -ne 0) { Fail 6 "compléments en échec" }
    L "ETAPE 5/${total} : kicks et frappes depuis les stems"
    & (Join-Path $PSScriptRoot 'stems-to-beats.ps1') -Dir $MixDir | ForEach-Object { L $_ }
  } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
L "TERMINE : recharge la page pour utiliser la nouvelle analyse."
exit 0

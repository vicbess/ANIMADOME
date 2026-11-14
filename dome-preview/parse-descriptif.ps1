# Lit descriptif-pyrobeats.txt et produit descriptif.json (texte des phases, sous-étapes, évènements).
# Code de mise en page :
#   [02:15 => 04:40] Titre         début d'une phase (évolution d'un état à un autre)
#     - [03:09 => 04:08] texte     sous-étape d'une phase
#   *04:41* texte                  évènement ponctuel (event) ; le texte peut continuer sur les lignes suivantes
#   **texte**                      partie TECHNIQUE (LEDs, barres, directions, intensité) -> gras, affichée en premier
#   texte normal                   partie DESCRIPTIVE (environnement, cinématique)
#   _texte_                        partie SON (analyse audio) -> italique, affichée en dernier
#   **CHAPITRE [mm:ss]**           chapitre principal (chronologie globale, non affiché dans l'interface)
#   Tout ce qui suit la ligne "À PARTIR D'ICI : PROPOSITIONS" est marqué "proposition".
param([string]$In = (Join-Path $PSScriptRoot 'descriptif-pyrobeats.txt'),
      [string]$Out = (Join-Path $PSScriptRoot 'descriptif.json'))

function ToSec([string]$s) { $p = $s.Split(':'); return [int]$p[0]*60 + [int]$p[1] }
$lines = [System.IO.File]::ReadAllLines($In, [System.Text.Encoding]::UTF8)
$phases = New-Object System.Collections.Generic.List[object]
$events = New-Object System.Collections.Generic.List[object]
$cur = $null; $lastEv = $null; $prov = $false; $inChapter = $false; $chapters = New-Object System.Collections.Generic.List[object]; $curCh = $null

foreach ($raw in $lines) {
  $line = $raw.TrimEnd()
  if ($line -match '^Questions') { break }
  if ($line -match '^.{1,3} PARTIR D.ICI' -and $line -match 'PROPOSITIONS') { $prov = $true; continue }
  if ($line -match '^=+\s*$') { continue }
  if ($line -match '^\*\*CHAPITRE\s*\[(\d{1,2}:\d{2})\]\*\*\s*(.*)$') { $curCh = [pscustomobject]@{ start = ToSec $Matches[1]; text = $Matches[2].Trim() }; $chapters.Add($curCh); $inChapter = $true; $lastEv = $null; continue }
  if ($line -match '^\[(\d{1,2}:\d{2})\s*=>\s*(\d{1,2}:\d{2})\]\s*(.*)$') { $inChapter = $false;
    $cur = [pscustomobject]@{ start = ToSec $Matches[1]; end = ToSec $Matches[2]; title = $Matches[3].Trim(); tech = ''; text = ''; audio = ''
                       sub = (New-Object System.Collections.Generic.List[object]); prov = $prov }
    $phases.Add($cur); $lastEv = $null; continue }
  if ($line -match '^\s+-\s+\[(\d{1,2}:\d{2})\s*=>\s*(\d{1,2}:\d{2})\]\s*(.*)$' -and $cur) {
    $cur.sub.Add([pscustomobject]@{ start = ToSec $Matches[1]; end = ToSec $Matches[2]; text = $Matches[3].Trim() }); continue }
  if ($line -match '^\*(\d{1,2}:\d{2})\*?\s*(.*)$') {
    $lastEv = [pscustomobject]@{ t = ToSec $Matches[1]; text = $Matches[2].Trim() }; $events.Add($lastEv); continue }
  if ($line.Trim() -eq '') { $lastEv = $null; continue }
  if ($inChapter) { if ($curCh) { $curCh.text = ($curCh.text + ' ' + $line.Trim()).Trim() }; continue }
  if (-not $cur) { continue }
  if ($line -match '^\*\*(.+?)\*\*\s*$') { $cur.tech = ($cur.tech + "`n" + $Matches[1].Trim()).Trim(); continue }
  if ($line -match '^_(.+?)_\s*$') { $cur.audio = ($cur.audio + ' ' + $Matches[1].Trim()).Trim(); continue }
  if ($line -match '^\(Son') { $cur.audio = ($cur.audio + ' ' + $line.Trim().Trim('()')).Trim(); continue }
  if ($lastEv) { $lastEv.text = ($lastEv.text + ' ' + $line.Trim()).Trim() }
  else { $cur.text = ($cur.text + ' ' + $line.Trim()).Trim() }
}
$dur = if ($phases.Count) { ($phases | ForEach-Object { $_.end } | Measure-Object -Maximum).Maximum } else { 0 }
foreach ($ph in $phases) { $ph.sub = @($ph.sub.ToArray()) }
$evSorted = @($events.ToArray() | Sort-Object -Property t)
$obj = [pscustomobject]@{ duration = $dur; phases = @($phases.ToArray()); events = $evSorted; chapters = @($chapters.ToArray()) }
$json = $obj | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($Out, $json, (New-Object System.Text.UTF8Encoding($false)))
"descriptif.json : $($phases.Count) phases, $($events.Count) évènements"

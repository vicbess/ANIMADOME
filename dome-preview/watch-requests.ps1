# Attend une demande destinée à Claude, puis se termine (ce qui le réveille) :
#  - un nouveau prompt saisi dans la page, pour n'importe quel mix (prompts.jsonl, pas encore dans prompts-done.json) ;
#  - ou une modification d'un descriptif-<mix>.txt suivie de SettleSec secondes de calme (le temps que tu finisses d'écrire).
param([string]$Root = $PSScriptRoot, [int]$SettleSec = 60)
function Get-Mixes { $t = [System.IO.File]::ReadAllText((Join-Path $Root 'mixes.js'), [System.Text.Encoding]::UTF8); $m = [regex]::Match($t, '(\[.*\])', 'Singleline'); return ($m.Value | ConvertFrom-Json) }
$mixes = @(Get-Mixes | ForEach-Object {
  $dir = if ($_.dir -eq '.') { $Root } else { Join-Path $Root ($_.dir -replace '/', '\') }
  [pscustomobject]@{ slug = $_.slug; dir = $dir; txt = (Join-Path $dir $_.descriptif); prompts = (Join-Path $dir 'prompts.jsonl'); done = (Join-Path $dir 'prompts-done.json') } })
$base = @{}; $changedAt = @{}
foreach ($m in $mixes) { if (Test-Path $m.txt) { $base[$m.slug] = (Get-Item $m.txt).LastWriteTimeUtc } }
while ($true) {
  foreach ($m in $mixes) {
    $doneIds = @{}
    if (Test-Path $m.done) { try { $o = [System.IO.File]::ReadAllText($m.done, [System.Text.Encoding]::UTF8) | ConvertFrom-Json; $o.PSObject.Properties | ForEach-Object { $doneIds[$_.Name] = $true } } catch {} }
    $pending = @()
    if (Test-Path $m.prompts) {
      foreach ($l in [System.IO.File]::ReadAllLines($m.prompts, [System.Text.Encoding]::UTF8)) {
        if ($l.Trim() -eq '') { continue }
        try { $p = $l | ConvertFrom-Json; if (-not $doneIds.ContainsKey([string]$p.id)) { $pending += $p } } catch {} } }
    if ($pending.Count -gt 0) { "PROMPTS_EN_ATTENTE (mix $($m.slug), dossier $($m.dir))"; $pending | ForEach-Object { "id=$($_.id) phase=[$($_.phaseStart)s] '$($_.phaseTitle)' t=$($_.t)s : $($_.text)" }; exit 0 }
    if (Test-Path $m.txt) {
      $mt = (Get-Item $m.txt).LastWriteTimeUtc
      if ($base[$m.slug] -ne $mt) { $base[$m.slug] = $mt; $changedAt[$m.slug] = Get-Date }
      if ($changedAt[$m.slug] -and ((Get-Date) - $changedAt[$m.slug]).TotalSeconds -ge $SettleSec) { "DESCRIPTIF_MODIFIE (mix $($m.slug)) : $($m.txt) (calme depuis ${SettleSec}s)"; exit 0 }
    }
  }
  Start-Sleep -Seconds 2
}

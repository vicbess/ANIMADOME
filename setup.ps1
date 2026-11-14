# Premier démarrage d'ANIMADÔME : vérifie Git, règle ton identité de publication, récupère les mix et vérifie l'audio.
#   powershell -ExecutionPolicy Bypass -File setup.ps1
# Rien n'est envoyé sur GitHub par ce script. Il peut être relancé sans risque.
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$mixes = Join-Path $repo 'dome-preview\mixes'

function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c }

Say "== ANIMADÔME : préparation ==" Cyan
if ($PSVersionTable.PSVersion.Major -lt 5) { throw "PowerShell 5.1 ou plus récent est nécessaire." }

# 1. Git
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) { Say "Git n'est pas installé. Installe « Git for Windows » (https://git-scm.com/download/win), puis relance ce script." Red; exit 1 }
Say ("Git trouvé : " + (git --version)) Green

# 2. Accès à GitHub (clé SSH) : sert à publier ; la lecture fonctionne sans
$sshOk = $false
try { $o = & ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | Out-String; if ($o -match 'successfully authenticated') { $sshOk = $true; Say ("Clé SSH GitHub reconnue : " + ($o -split "`n")[0].Trim()) Green } } catch {}
if (-not $sshOk) { Say "Pas de clé SSH reconnue par GitHub : tu pourras lire les mix, mais pas publier. Voir le README (« Accès en écriture »)." Yellow }

# 3. Récupérer les mix (dépôt séparé, cloné dans dome-preview\mixes)
if (-not (Test-Path (Join-Path $mixes '.git'))) {
  $url = if ($sshOk) { 'git@github.com:vicbess/MIX_Animadome.git' } else { 'https://github.com/vicbess/MIX_Animadome.git' }
  Say "Récupération des mix depuis $url ..." Gray
  if ((Test-Path $mixes) -and (Get-ChildItem $mixes -Force | Select-Object -First 1)) { Say "Le dossier dome-preview\mixes existe déjà et n'est pas un dépôt Git : déplace-le puis relance." Red; exit 1 }
  git clone $url $mixes
} else { Say "Dépôt des mix déjà présent." Green }

# 4. Identité de publication (limitée à ces deux dépôts)
Say "`nIdentité utilisée pour tes publications (nom d'utilisateur GitHub conseillé ; il préfixe tes fichiers de phases)." Gray
$curName = (git -C $repo config user.name)
$name = Read-Host ("Nom d'utilisateur" + $(if ($curName) { " [$curName]" } else { "" }))
if (-not $name) { $name = $curName }
if ($name -notmatch '^[A-Za-z0-9_-]{2,30}$') { Say "Nom invalide : 2 à 30 caractères (lettres, chiffres, - et _)." Red; exit 1 }
Say "Adresse de commit : pour ne pas exposer ton adresse personnelle, utilise l'adresse « noreply » de GitHub (github.com > Settings > Emails : <numéro>+<pseudo>@users.noreply.github.com)." Gray
$curMail = (git -C $repo config user.email)
$mail = Read-Host ("Adresse de commit" + $(if ($curMail) { " [$curMail]" } else { "" }))
if (-not $mail) { $mail = $curMail }
if (-not $mail) { Say "Une adresse est nécessaire pour publier." Red; exit 1 }
foreach ($r in @($repo, $mixes)) { git -C $r config user.name $name; git -C $r config user.email $mail }
Say "Identité réglée pour l'outil et pour les mix." Green

# 5. Audio des mix (échangé hors GitHub)
Say "`n== Audio des mix ==" Cyan
Get-ChildItem $mixes -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'mix.json') } | ForEach-Object {
  $mj = Get-Content (Join-Path $_.FullName 'mix.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $audio = Join-Path $_.FullName ($mj.audio -replace '/', '\')
  if (Test-Path $audio) { Say ("{0} : audio présent" -f $mj.title) Green } else { Say ("{0} : audio MANQUANT -> place le fichier ici : {1}" -f $mj.title, $audio) Yellow }
}

# 6. Page
& (Join-Path $repo 'dome-preview\build.ps1') | Out-Null
Say "`nTout est prêt. Lance dome-preview\lancer-apercu.bat (ou ouvre http://localhost:8765/show.html après avoir lancé serve.ps1)." Cyan

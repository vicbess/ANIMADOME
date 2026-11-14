# ANIMADÔME

Outil léger de **prévisualisation 2D / 3D d'animations lumineuses** pour un dôme géodésique de LEDs adressables, conçu pour écrire des scénarios lumineux calés sur des mix audio, et pour y **travailler à plusieurs**.

L'outil tourne dans le navigateur (HTML + JavaScript, rien à installer côté page) avec un petit serveur local PowerShell. Il sert à **concevoir et valider** les animations ; l'export vers un logiciel de pilotage (TouchDesigner, sACN/DMX…) n'est pas encore inclus.

> Les **mix** (descriptif, réglages, analyse du son) sont dans un dépôt séparé : [MIX_Animadome](https://github.com/vicbess/MIX_Animadome).

---

## Installation (Windows)

1. Installer **[Git for Windows](https://git-scm.com/download/win)** et un navigateur récent (Chrome ou Edge). PowerShell 5.1 est déjà présent sous Windows 10/11.
2. Cloner l'outil :
   ```bash
   git clone https://github.com/vicbess/ANIMADOME.git
   cd ANIMADOME
   ```
3. Lancer le script de premier démarrage :
   ```bash
   powershell -ExecutionPolicy Bypass -File setup.ps1
   ```
   Il vérifie Git et ta clé GitHub, **récupère les mix** dans `dome-preview/mixes`, règle l'identité utilisée pour tes publications et te dit où placer l'audio.
4. **Ajouter l'audio** de chaque mix à l'endroit indiqué par `setup.ps1` (par exemple `dome-preview/mixes/pyrobeats/audio/pyrobeats_128k.mp3`). Les fichiers audio ne sont jamais sur GitHub : les collaborateurs se les échangent directement.
5. Lancer `dome-preview/lancer-apercu.bat` (ou `powershell -ExecutionPolicy Bypass -File dome-preview/serve.ps1`) puis ouvrir <http://localhost:8765/show.html>. Garder la fenêtre du serveur ouverte.

### Accès en écriture (pour publier)
Lire et utiliser l'outil ne demande aucun compte. **Publier** (une version de l'outil ou des phases d'un mix) demande :
- d'être **collaborateur** sur les dépôts concernés (le propriétaire t'invite avec ton pseudo GitHub) ;
- une **clé SSH** liée à ton compte GitHub : `ssh-keygen -t ed25519`, puis coller le contenu de `~/.ssh/id_ed25519.pub` dans GitHub > Settings > SSH keys ;
- une adresse de commit : utilise l'adresse « noreply » de GitHub (Settings > Emails) pour ne pas exposer ta vraie adresse. `setup.ps1` te la demande.

## Ce que fait l'outil

- **Vue 2D** : la référence exacte du dôme (pensée pour l'export).
- **Vue 3D** (visualisation seule) : caméras *Top*, *Free* (le dôme tourne à la souris, on peut passer dessous) et *Centre* (point de vue du public, à hauteur d'yeux, molette = zoom) ; halo des LEDs et ciel étoilé.
- **GéoLists** : visualiseur de formes géométriques du dôme (triangles, pentagones, cercles, lignes…), avec sélection par barres et une formule réutilisable pour décrire une sélection.
- **Timeline** : un mix découpé en phases ; chaque phase combine des effets continus et des **events** ponctuels (posés, déplacés, étirés, dupliqués sur la timeline). Un clic sur la barre colorée d'une phase ouvre son menu.
- **Journal des effets** : un encart par effet ou event actif (bleu pour les events) ; la description détaillée apparaît au survol.
- **Event Bank** : catalogue d'events classés en *Volcano*, *Geometric* et *Basics*.
- **Descriptif** : un fichier texte par mix décrit chaque phase et ses events `*mm:ss*` ; l'outil le relit à chaque modification.

## Mettre à jour l'outil

Les versions de l'outil sont des **étiquettes Git** (`v1.1.0`…) de la branche `main`, avec leurs nouveautés dans `CHANGELOG.md`. Les deux boutons sont à droite du titre, sous le numéro de version :

- **publish tool version** : demande un numéro de version et les nouveautés, enregistre les modifications de l'outil, puis envoie la branche et l'étiquette sur GitHub. Refuse si la version existe déjà.
- **update tool version** : liste les versions publiées (date et notes) et installe celle que tu choisis, **sans toucher à tes mix**. Refuse s'il reste des modifications locales non publiées. Il faut ensuite relancer le serveur et recharger la page.

Seul le dépôt officiel de l'outil est utilisé ; il faut un accès en écriture pour publier.

## Travailler à plusieurs sur un mix

Chaque mix est un projet qui dépend d'un audio. Le travail se partage **phase par phase** :

- **publish phases** (en haut à gauche, à côté du choix du mix, ou dans le menu d'une phase) publie **toutes les phases** du mix d'un coup, dans `publish/<ton nom d'utilisateur>_phases.json`. Le nom est **toujours en préfixe** : deux personnes qui publient en même temps n'écrasent rien. Chaque phase contient son texte, ses réglages, ses events (copies comprises) et son timing, avec un numéro de version qui n'augmente que si son contenu change.
- Quand un **autre utilisateur** a publié une version qui diffère de la tienne, la **barre colorée** de la phase devient **jaune striée de rouge** (numéro en jaune). Le test se fait sur GitHub toutes les 3 minutes, sans rien écrire chez toi.
- **Clic sur la barre colorée d'une phase, ou sur « PHASE X » / son titre** : menu avec
  - **updater phase X** : liste les versions disponibles (utilisateur, version, date, nombre d'events) et remplace le texte, les réglages et les events de cette phase par la version choisie. Une sauvegarde est faite et un bouton **Annuler** restaure l'état précédent ;
  - **check for updates** : vérifie tout de suite sur GitHub et indique les phases à mettre à jour ;
  - **publish phases** : publie toutes les phases.
- Les bornes des phases sont fixées par la personne qui démarre le mix ; une version dont les bornes diffèrent des tiennes n'est pas encore récupérable.

Le détail du format est dans le [README des mix](https://github.com/vicbess/MIX_Animadome).

## Travailler avec Claude (facultatif)

La page contient une zone de prompt (« prompt modificateur de phase ») : chaque prompt est écrit dans un fichier local du mix, que `watch-requests.ps1` surveille. Un assistant de code (par exemple [Claude Code](https://claude.com/claude-code) ouvert dans ce dossier) lit les demandes (« ajoute tel event à 5:30 ») et modifie le descriptif, les réglages et l'outil.

Tout ce qu'il doit savoir de l'outil (procédure, règles, fichiers) est dans [`CLAUDE.md`](CLAUDE.md), que Claude Code lit automatiquement. Ce qu'il doit savoir de **chaque mix** (intention, palette, règles de l'auteur, décisions durables) est dans le fichier `CONTEXT.md` du mix : il le lit au début de chaque session, le tient à jour, et il est **publié avec les phases** (une pastille « ● contexte mis à jour » prévient quand un collaborateur en a publié une nouvelle version). Pour qu'il traite tes prompts, ouvre-le dans le dossier du projet et demande-lui de lancer le serveur et le veilleur. L'outil fonctionne très bien sans.

## Organisation du dépôt

```
ANIMADOME/
├─ setup.ps1                 premier démarrage (Git, identité, mix, audio)
├─ CLAUDE.md                 consignes pour un assistant
├─ CHANGELOG.md              versions publiées
├─ dome-preview/
│  ├─ show.template.html     source de la page (effets, vues, interface)
│  ├─ show.html              page générée
│  ├─ build.ps1              reconstruit show.html à partir du template
│  ├─ dome-geometry.json     plan du dôme
│  ├─ serve.ps1              serveur local (+ publication / mise à jour par Git)
│  ├─ watch-requests.ps1     veilleur de prompts
│  ├─ parse-descriptif.ps1   lecture du descriptif
│  ├─ lancer-apercu.bat      lance le serveur et la page
│  ├─ tools/                 scripts d'analyse du son (facultatifs)
│  └─ mixes/                 dépôt séparé des mix (non suivi par ce dépôt)
├─ LICENSE                   MIT
└─ README.md
```

## Analyse du son (facultatif)

Pour **créer un nouveau mix**, les scripts de `dome-preview/tools/` séparent les stems puis calculent l'analyse (kicks, notes, énergie par bande…). Ils nécessitent Python 3.11 et :

- [Demucs](https://github.com/facebookresearch/demucs) (séparation des stems)
- [PyTorch / torchaudio](https://pytorch.org/), [librosa](https://librosa.org/), numpy, scipy

Ces outils ne sont **pas** embarqués dans le dépôt (plusieurs Go) : à installer soi-même. Les fichiers d'analyse **déjà calculés** d'un mix sont dans le dépôt des mix : pour utiliser un mix existant, ils ne sont pas nécessaires.

## Licence et crédits

Code sous licence [MIT](LICENSE). Les mix, leur audio et leurs droits appartiennent à leurs auteurs ; l'audio n'est jamais publié dans ces dépôts.

Outils tiers utilisés (installés séparément, jamais redistribués ici) : Demucs (MIT), PyTorch (BSD), librosa (ISC), numpy et scipy (BSD).
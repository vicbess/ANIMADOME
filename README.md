# ANIMADÔME

Outil léger de **prévisualisation 2D / 3D d'animations lumineuses** pour un dôme géodésique de LEDs adressables (3V 5/8, 120 barres), conçu pour écrire des scénarios lumineux calés sur des mix audio.

L'outil tourne dans le navigateur (HTML + JavaScript, aucun module à installer) et un petit serveur local PowerShell. Il sert à **concevoir et valider** les animations ; l'export vers un logiciel de pilotage (TouchDesigner, sACN/DMX…) n'est pas encore inclus.

> Les **mix** (audio, descriptif, réglages) sont dans un dépôt séparé : [MIX_Animadome](https://github.com/vicbess/MIX_Animadome).

---

## Ce que fait l'outil

- **Vue 2D** : la référence exacte du dôme (positions des LEDs, pensée pour l'export).
- **Vue 3D** (visualisation seule) : caméras *Top*, *Free* (le dôme tourne à la souris) et *Centre* (point de vue du public, à hauteur d'yeux), halo des LEDs, ciel étoilé.
- **GéoLists** : visualiseur de formes géométriques du dôme (triangles, pentagones, cercles, lignes…), avec sélection par barres et formule réutilisable pour décrire une sélection.
- **Timeline** : un mix découpé en phases ; chaque phase combine des effets continus et des **events** ponctuels (posés, déplacés, étirés, dupliqués sur la timeline).
- **Event Bank** : catalogue d'events classés en *Volcano*, *Geometric* et *Basics*.
- **Descriptif** : un fichier texte par mix décrit chaque phase (ambiance, technique, son) et ses events `*mm:ss*` ; l'outil le relit à chaque modification.
- **Analyse du son** : kicks, notes, basses, voix et rugosité d'un mix servent à caler les animations.

## Démarrer

Prérequis : **Windows**, **PowerShell 5.1** (fourni avec Windows) et un navigateur récent (Chrome / Edge).

1. Cloner ce dépôt.
2. Récupérer au moins un mix : cloner le dépôt des mix **dans** `dome-preview/mixes` :
   ```bash
   git clone git@github.com:vicbess/MIX_Animadome.git dome-preview/mixes
   ```
3. Ajouter l'audio du mix dans `dome-preview/mixes/<mix>/audio/` (il n'est pas dans le dépôt, voir le README des mix).
4. Lancer `dome-preview/lancer-apercu.bat` (ou `powershell -ExecutionPolicy Bypass -File dome-preview/serve.ps1`) puis ouvrir <http://localhost:8765/show.html>.

## Organisation du dépôt

```
ANIMADÔME/
├─ dome-preview/
│  ├─ show.template.html     source de la page (effets, vues 2D / 3D, interface)
│  ├─ show.html              page générée (source + plan du dôme)
│  ├─ dome-geometry.json     plan du dôme : sommets, barres, couleur = longueur
│  ├─ serve.ps1              serveur local + régénération des descriptifs
│  ├─ watch-requests.ps1     veilleur de prompts / modifications du descriptif
│  ├─ parse-descriptif.ps1   lecture du descriptif -> descriptif.json
│  ├─ lancer-apercu.bat      lance le serveur et ouvre la page
│  ├─ tools/                 scripts d'analyse du son (facultatifs, voir plus bas)
│  └─ mixes/                 dépôt séparé des mix (non suivi par ce dépôt)
├─ LICENSE                   MIT
└─ README.md
```

Le dossier `dome-preview/mixes/` est volontairement ignoré ici : c'est le dépôt [MIX_Animadome](https://github.com/vicbess/MIX_Animadome).

## Le dôme

Plan de référence : dôme géodésique 3V 5/8, **120 barres adressables** (plus le contour au sol). Les barres ont cinq longueurs, repérées par une couleur sur le plan :

| Couleur | Longueur de barre |
|---|---|
| Blanc | 1,10 m |
| Marron | 1,13 m |
| Jaune | 1,30 m |
| Rouge | 1,40 m |
| Bleu | 1,50 m |

- Les barres sont vissées entre elles à **2,5 cm** de leur bord (le trou de vis est le nœud) : la longueur entre deux nœuds vaut donc la longueur de la barre moins 5 cm.
- Chaque barre est pliée à 5 cm de ses deux bords, avec le même angle pour toutes.
- Les LEDs commencent à **4 cm du nœud** (point mort au centre des « étoiles »). Le nombre de LEDs par barre se choisit dans l'interface (4, 24, 42 ou 60).
- La vue 3D est reconstruite à partir de ces longueurs. C'est une approximation destinée à la visualisation : la vue 2D reste la référence.

## Analyse du son (facultatif)

Pour **créer un nouveau mix**, les scripts de `dome-preview/tools/` séparent les stems puis calculent l'analyse (kicks, notes, énergie par bande…). Ils nécessitent Python 3.11 et :

- [Demucs](https://github.com/facebookresearch/demucs) (séparation des stems)
- [PyTorch / torchaudio](https://pytorch.org/), [librosa](https://librosa.org/), numpy, scipy

Ces outils ne sont **pas** embarqués dans le dépôt (plusieurs Go) : à installer soi-même. Les fichiers d'analyse **déjà calculés** d'un mix sont dans le dépôt des mix : pour simplement utiliser un mix existant, ils ne sont pas nécessaires.

## Utiliser un assistant IA (facultatif)

La page contient une zone de prompt : chaque prompt est écrit dans un fichier local du mix, que `watch-requests.ps1` surveille. Un assistant de code peut ainsi lire les demandes (« ajoute tel event à 5:30 », « change la couleur de… ») et modifier le descriptif, les réglages et l'outil. Cette partie est optionnelle ; l'outil fonctionne très bien sans.

## Versions

Les versions de l'outil sont des **étiquettes Git** (`v2.0.0`…) sur la branche `main`, seule branche du dépôt.
À venir : un bouton *publish tool version* et un bouton *update version* dans l'interface, puis le partage de phases entre collaborateurs d'un même mix.

## Licence et crédits

Code sous licence [MIT](LICENSE). Les mix, leur audio et leurs droits appartiennent à leurs auteurs ; l'audio n'est jamais publié dans ces dépôts.

Outils tiers utilisés (installés séparément, jamais redistribués ici) : Demucs (MIT), PyTorch (BSD), librosa (ISC), numpy et scipy (BSD).

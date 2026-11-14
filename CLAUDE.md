# ANIMADÔME : consignes pour un assistant (Claude Code)

Ce fichier explique à un assistant comment travailler sur ce projet. L'utilisateur parle **français** : réponds et commite en français.

## Le projet en bref
Outil de prévisualisation 2D / 3D d'animations lumineuses pour un dôme géodésique de LEDs (120 barres adressables). Une page HTML/JS (`dome-preview/show.html`) + un serveur local PowerShell (`serve.ps1`, port 8765). Chaque **mix** (audio + scénario) est un dossier dans `dome-preview/mixes/<nom>/`, qui est **un dépôt Git séparé** (`MIX_Animadome`), ignoré par le dépôt de l'outil.

Pas d'export TouchDesigner / sACN / DMX pour l'instant : ne pas y travailler sauf demande explicite. Pas d'animations « globales » (appliquées à tout le dôme sans raison musicale) sans demande.

## Contexte de chaque mix (à lire en premier)
Chaque mix a un fichier **`dome-preview/mixes/<mix>/CONTEXT.md`** : intention artistique, palette, règles posées par l'auteur, vocabulaire, décisions durables. C'est ta mémoire partagée du mix.
- **Au début de chaque session**, lis le `CONTEXT.md` du (des) mix concerné(s) avant de toucher à quoi que ce soit.
- **Mets-le à jour** dès que l'utilisateur donne une consigne durable (une règle, un choix, une préférence qui vaut pour la suite). Chaque collaborateur écrit ses notes sous `### Notes de <utilisateur>` ; la partie principale est tenue par le propriétaire du mix.
- **Avant toute publication** (`publish phases`), vérifie que `CONTEXT.md` reflète bien les décisions de la session : il est envoyé avec les phases, c'est ainsi que le collaborateur suivant en hérite. La page signale (« ● contexte mis à jour ») quand un autre a publié un nouveau contexte : récupère-le avant de continuer.
- Ce fichier ne contient jamais d'information personnelle (adresse, identifiants, chemins de ta machine).
## Connaissances son et lumière
Le skill **nimadome-son-lumiere** (.claude/skills/animadome-son-lumiere/SKILL.md) rassemble ce qu'un technicien son et lumière doit savoir ici : pilotage sACN/DMX, alimentation, gamma et couleur, photosensibilité, synchronisation, analyse audio, ambisonie. Consulte-le avant de régler un effet destiné au dôme réel ou de parler d'export.

## Lancer
```
powershell -ExecutionPolicy Bypass -File dome-preview\serve.ps1 -Port 8765     (serveur, à garder ouvert)
powershell -ExecutionPolicy Bypass -File dome-preview\watch-requests.ps1        (veilleur de prompts, voir plus bas)
```
Page : <http://localhost:8765/show.html>. PowerShell **5.1** : pas de `&&`, pas d'opérateur ternaire. Les fichiers `.ps1` sont en UTF-8 **avec BOM** ; tout le reste en UTF-8 sans BOM.

## Où est quoi
| Fichier | Rôle |
|---|---|
| `dome-preview/show.template.html` | **Source** de la page (effets `FX`, vues 2D / 3D, interface). C'est ce fichier qu'on modifie. |
| `dome-preview/show.html` | Page générée : `powershell -ExecutionPolicy Bypass -File dome-preview\build.ps1` après chaque modification du template. |
| `dome-preview/dome-geometry.json` | Plan du dôme (sommets, barres, couleur = longueur). |
| `mixes/<mix>/mix.json` | Nom du mix, fichier audio, nom du descriptif. |
| `mixes/<mix>/descriptif-<mix>.txt` | Le scénario écrit : phases `[mm:ss => mm:ss] Titre`, texte technique en gras (`**…**`), son en italique (`_…_`), events `*mm:ss*` suivis de leur texte. Un event invoqué par son nom : `Nom : texte`. |
| `mixes/<mix>/fxmap.js` | Réglages techniques : `phases` (effets continus par phase, clé = début `mm:ss`), `events` (une ligne par event, clé = `mm:ss`), `eventTypes` (descriptions génériques de la banque), `eventCategory`, `eventLib`… |
| `mixes/<mix>/events-timing.json` | Positions, durées, copies d'events posés sur la timeline. **Géré par la page** (voir règles). |
| `mixes/<mix>/stems.js beats.js features.js gut.js` | Analyse du son (calculée, ne pas éditer à la main). |
| `mixes/<mix>/prompts.jsonl`, `prompts-done.json` | Prompts reçus / traités (locaux, jamais versionnés). |
| `mixes/<mix>/publish/<utilisateur>_phases.json` | Phases publiées (voir le README des mix). |

## Traiter les prompts (le lien avec la page)
La page contient une zone de prompt. Chaque prompt est écrit dans `mixes/<mix>/prompts.jsonl` (id, phase, instant, texte). `watch-requests.ps1` se termine quand un prompt est en attente ou quand le descriptif a été modifié puis laissé au calme 60 s : **lance-le en tâche de fond** pour être réveillé, et **relance-le après chaque traitement**.

Pour un prompt :
1. Lis-le (phase, instant `t`, texte). S'il est ambigu, pose la question plutôt que de deviner.
2. Applique-le : texte technique du descriptif, `fxmap.js`, et si besoin le code des effets dans `show.template.html`. Reste cohérent : en cas de contradiction, la consigne la plus récente de l'utilisateur gagne, et le texte du descriptif doit toujours décrire ce que fait l'animation.
3. `build.ps1`, recharge la page, vérifie (mesure ou capture). Ne dis jamais « c'est fait » sans avoir vérifié.
4. Ajoute l'id du prompt dans `prompts-done.json` (`{ "<id>": "résumé" }`).
5. Relance le veilleur.

Les boutons « Éditer la description » et « Nettoyer l'anim de la phase » envoient aussi des prompts (`[EDIT]`, `[CLEAN]`) : relis la phase, applique, et pour `[CLEAN]` écris le rapport dans `clean/` en demandant confirmation.

## Règles à respecter
- **Events** : un nom d'event est unique (18 caractères max). Catégories de la banque : *Volcano*, *Geometric*, *Basics*. Les descriptions de la banque (`eventTypes`) ne contiennent **ni timing ni couleur**.
- **Ajouter / déplacer un event sur la timeline** : passe par la page (variables `EV`, `evLibEvent`, puis `saveEvt()` depuis la console du navigateur), **jamais en éditant `events-timing.json` pendant que la page est ouverte** (elle le réécrit).
- Un effet ajouté dans `FX` doit rester léger (viser moins de 2 ms par image, à mesurer) et fonctionner pour 4 à 60 LEDs par barre.
- Phases : ≤ 3 familles de couleurs par phase sauf intention contraire ; ne supprime jamais en silence ce que l'utilisateur a demandé.
- La vue 2D est la référence exacte (futur export) ; la vue 3D est une visualisation, des approximations y sont acceptables.

## Git
- Dépôt de l'outil : **branche `main` uniquement**. Dépôt des mix : idem. Commits en français.
- N'envoie rien sur GitHub sans demande de l'utilisateur. Les versions de l'outil sont publiées par le bouton **publish tool version** (étiquette `vX.Y.Z` + `CHANGELOG.md`) ; les phases par **publish phases**.
- Identité de commit : nom d'utilisateur GitHub + adresse **noreply**. Ne mets jamais d'adresse personnelle dans un commit, un en-tête ou une requête.
- Ne publie ni audio, ni stems, ni historique de prompts, ni mot de passe / jeton / clé. Les opérations d'envoi passent par la clé SSH de l'utilisateur ; ne demande ni ne manipule jamais ses identifiants.

## Pièges connus
- `show.template.html` est un gros fichier : modifie-le par remplacements exacts et vérifie qu'il contient encore `<!doctype html>` et `/*DOME_JSON*/` (`build.ps1` le contrôle).
- Un fichier modifié par un script peut rester en CRLF ou LF : conserve celui du fichier.
- Le veilleur se déclenche aussi sur tes propres modifications du descriptif : c'est normal.

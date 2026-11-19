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
## Goût de l'auteur (valable pour tous les mix)
- **Pas de passages abrupts** d'une animation à l'autre, sauf demande explicite (ex. un « Rien » voulu). Une animation doit **se transformer** en la suivante (morph des paramètres : palette, densité, vitesse, direction) plutôt que d'être simplement superposée à elle ; si deux animations se recouvrent, fondu à puissance constante et couleurs mélangées sans passer par du gris, et si possible une **anticipation** (la suivante apparaît discrètement avant d'arriver) ou un **front qui balaie** le dôme dans le sens naturel de la lave.
- Chaque mix a un look très différent : ne pas transposer les couleurs ou les effets d'un mix à l'autre ; le `CONTEXT.md` du mix fait foi.
- Le rythme des mix est souvent peu conventionnel (sons non standard, bruitages, petits sons séparés) : ne pas supposer un beat régulier ; quand les pistes séparées d'un mix sont disponibles, **analyser chaque piste à part** plutôt que le mélange.
## Couches d'animation (outil 2.0 en construction)
Trois couches, activables séparément par les interrupteurs du journal : **Anim base layer** (anciens « effets de phase » : un canvas qui suit le tempo principal, même effet sur les passages de même nature), **Anim 2D layer** (variations chaînées à un effet de base : accélération, intensité, couleur ; dans `fxmap.js` : `layer:'mod'`, `on:'<nom de l'effet de base>'`, sinon le premier de la phase) et **Events** (inchangés : tout détail ponctuel est un event rangé dans la banque, sans doublon). Les couleurs des encarts viennent de la palette de l'effet (`pal`) ; on garde la palette du mix sauf raison créative. Le tempo suit les changements de tempo à l'intérieur d'une phase. Chaque élément doit rester séparable (désactivable, modifiable). mixes/<mix>/layers.js (généré par 	ools/auto-layers.py, d'après nalysis2.js) contient les fenêtres d'apparition / effets ajoutés des effets de base (ase), les variations automatiques (mods : intensité, accélération, contraste du rythme, couleur) et les events ajoutés (events, jamais écrits dans events-timing.json). mixes/<mix>/events-plan.json (facultatif) liste des events choisis à la main d'après le descriptif et l'analyse ; uto-layers.py les fusionne dans layers.js. **Pour annuler la passe automatique : supprimer layers.js** ; chaque élément automatique se désactive aussi un par un (⏻ dans le journal).
**Trous d'export** : si les pistes séparées fournies sont muettes alors que le mix joue, `tools/fill-gaps.py <mix>` (`--list` pour seulement les lister) analyse le mix sur ces passages et complète `analysis2.js`, `beats.js` et `stems.js` ; à relancer après chaque nouvelle analyse. **Phase réglée à la main** : `mixes/<mix>/layers-plan.json` (`{ "<début en s>": { mods, base, noAutoEvents } }`) remplace les variations automatiques de cette phase ; dans `events-plan.json`, `snap:false` garde un event à l'instant exact donné (déjà calé sur l'analyse) et `ov` lui passe des réglages (ex. `strikes`, `ticks`).
## Connaissances son et lumière
Le skill **nimadome-son-lumiere** (.claude/skills/animadome-son-lumiere/SKILL.md) rassemble ce qu'un technicien son et lumière doit savoir ici : pilotage sACN/DMX, alimentation, gamma et couleur, photosensibilité, synchronisation, analyse audio, ambisonie. Consulte-le avant de régler un effet destiné au dôme réel ou de parler d'export.

**Mouvement** : le skill `motion-design` (.claude/skills/motion-design/) donne le vocabulaire du motion design (anticipation, accélération / décélération, chevauchement, chorégraphie) ; il parle d'interfaces, ses durées ne s'appliquent pas aux LEDs. L'essentiel transposé au dôme, les pièges rencontrés et la méthode de comparaison de versions (`compare.html`) sont dans `dome-preview/docs/moteur-effets.md` : ce fichier est la mémoire partagée de l'outil, **complète-le** quand tu apprends quelque chose d'utile à la session suivante (ne le garde pas dans ta mémoire privée).

## Quel modèle pour quelle tâche (économie de tokens)
Règle écrite en **niveaux**, jamais en noms ni en versions de modèles : « supérieur » = le modèle le plus capable disponible dans la session ; « courant » = le modèle par défaut, juste suffisant.
| Tâche | Niveau |
|---|---|
| Concept d'une phase, code de nouveaux effets, choix et placement des events (travail artistique) | supérieur, effort moyen (comparatif fait sur le plus haut modèle disponible alors : l'effort faible donnait un résultat plus plat ; à revérifier à chaque changement de modèle supérieur, voir le `CONTEXT.md` du mix) |
| Analyse du son, trous d'export, fiche rythmique | courant |
| Câblage (`fxmap.js`, descriptif, plans), reconstruction, mesures de vérification | courant |
| Maintenance de l'outil, interface, publications | courant |
- **Tu es sur le modèle courant et la demande est artistique** : avant de commencer, dis à l'utilisateur en une phrase que cette tâche mérite le modèle supérieur et qu'il peut basculer avec le sélecteur de modèle ; s'il préfère continuer, continue.
- **Tu es sur le modèle supérieur** : ne garde pour toi que le travail artistique ; confie les étapes mécaniques (analyse, fiche, câblage, vérification) à un sous-agent lancé sur un modèle moins cher, désigné par son alias de niveau (il suit les versions tout seul), avec une consigne complète. Si la demande n'a rien d'artistique, signale qu'elle peut se faire sur le modèle courant.
- **Méthode pour refaire ou affiner une phase** (dans cet ordre) : 1) `python tools/fill-gaps.py <mix> --list` puis, s'il y a des trous, sans `--list` ; 2) `python tools/phase-brief.py <mix> <n>` et lire **la fiche** (`mixes/<mix>/briefs/phase-NN.md`), pas l'analyse brute ; 3) lire `dome-preview/docs/moteur-effets.md` (dont « Méthode validée pour refaire une phase » et « Pièges rencontrés »), pas le template entier ; 4) concevoir, coder, placer ; 5) `aniCheckPhase(n)` dans la page ; 6) l'auteur juge à l'œil avec le son.
- **Une session neuve par phase** : elle démarre avec ce fichier, le `CONTEXT.md` du mix et la fiche de la phase ; ne pas enchaîner plusieurs phases dans une longue session.
- N'affiche jamais de longues listes brutes (départs de sons, tableaux d'analyse) : résume par script avant de lire.
## Mode Cinematic (version YouTube du dôme)
Code : bloc « Vue Cinematic » de `show.template.html` (avant `function frame()`), enregistrement MP4 dans `serve.ps1` (`RecHandle`, ffmpeg), logo et textures dans `dome-preview/assets/`. Chaque effet et chaque fond est une **fonction pure du temps** (déterminisme : le rendu hors ligne, le cache de lecture et l'aperçu doivent donner la même image) ; viser nettement moins de 16 ms par image. Pièges et méthode : `dome-preview/docs/moteur-effets.md`. Travail de ce mode : session dédiée, niveau supérieur à effort moyen ; **si la session tourne sur un niveau plus faible, demander confirmation à l'auteur avant de commencer**.
## Repères « IA » et « outil » dans l'interface
Un badge jaune **IA** (classe `aiWarn`, `data-ai` sur le bouton) marque tout ce qui envoie un prompt à une IA : il ne disparaît jamais (il prévient d'une dépense de tokens) et le bouton est grisé tant qu'aucune IA n'est détectée (le veilleur `watch-requests.ps1` écrit `dome-preview/.ai-alive`, lu par `/api/ai-status`). **Lance le veilleur en tâche de fond au début de la session** pour que l'outil te voie « connecté ». Un badge orange **clé à molette** (`toolWarn`, `data-tool`) marque un outil à installer (ffmpeg, Git, outils d'analyse) : `/api/tools-status`, `/api/tool-install` (jamais sans confirmation de l'utilisateur dans la fenêtre d'installation). Tout nouveau bouton qui dépend d'une IA ou d'un outil doit porter le badge correspondant.
## Lancer
```
powershell -ExecutionPolicy Bypass -File dome-preview\serve.ps1 -Port 8765     (serveur, à garder ouvert)
powershell -ExecutionPolicy Bypass -File dome-preview\watch-requests.ps1        (veilleur de prompts, voir plus bas)
```
Raccourci : `RUN_ANIMADOME.bat` (racine) lance le serveur et ouvre la page ; icône `dome-preview/assets/animadome.ico`.
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
| `mixes/<mix>/stems.js beats.js features.js gut.js` | Analyse du son (calculée, ne pas éditer à la main) : kicks / frappes de la batterie séparée, temps (beat_this), stems, énergie. `analysis2.js` (local, ignoré par Git) garde les départs de sons de chaque piste ; `analysis2.report.md` est le bilan par phase à relire avec le descriptif. Tout est lancé par le bouton **Select Audio files** via `tools/run-analysis.ps1` (`analyze-v2.py`, `apply-analysis-v2.py` ; outils vérifiés par `tools/check-analysis.ps1`). |
| `mixes/<mix>/prompts.jsonl`, `prompts-done.json` | Prompts reçus / traités (locaux, jamais versionnés). |
| `mixes/<mix>/publish/<utilisateur>_phases.json` | Phases publiées (voir le README des mix). |

## Traiter les prompts (le lien avec la page)
La page contient une zone de prompt. Chaque prompt est écrit dans `mixes/<mix>/prompts.jsonl` (id, phase, instant, texte). `watch-requests.ps1` se termine quand un prompt est en attente ou quand le descriptif a été modifié puis laissé au calme 60 s : **lance-le en tâche de fond** pour être réveillé, et **relance-le après chaque traitement**.

Pour un prompt :
1. Lis-le (phase, instant `t`, texte). Le champ `vue` (`view`) indique la vue affichée à la validation (2D, 3D, GéoLists, Cinematic, onglet) : simple contexte, le prompt n'agit pas forcément sur la fenêtre visible. S'il est ambigu, pose la question plutôt que de deviner.
2. Applique-le : texte technique du descriptif, `fxmap.js`, et si besoin le code des effets dans `show.template.html`. Reste cohérent : en cas de contradiction, la consigne la plus récente de l'utilisateur gagne, et le texte du descriptif doit toujours décrire ce que fait l'animation.
3. `build.ps1`, recharge la page, vérifie (mesure ou capture). Ne dis jamais « c'est fait » sans avoir vérifié.
4. Ajoute l'id du prompt dans `prompts-done.json` (`{ "<id>": "résumé" }`).
5. Relance le veilleur.

Les boutons « Éditer la description » et « Nettoyer l'anim de la phase » envoient aussi des prompts (`[EDIT]`, `[CLEAN]`) : relis la phase, applique, et pour `[CLEAN]` écris le rapport dans `clean/` en demandant confirmation.

## Règles à respecter
- **Events** : le nom d'un **type** d'event est unique (18 caractères max) ; plusieurs occurrences d'un même type partagent ce nom (par exemple les « Ruée »). Catégories de la banque : *Volcano*, *Geometric*, *Basics*, *Water*, *Sky*, *Stone*. Les descriptions de la banque (`eventTypes`) ne contiennent **ni timing ni couleur**.
- **Ajouter / déplacer un event sur la timeline** : passe par la page (variables `EV`, `evLibEvent`, puis `saveEvt()` depuis la console du navigateur), **jamais en éditant `events-timing.json` pendant que la page est ouverte** (elle le réécrit).
- **Noms d'animations** (effets de base, anims secondaires, events) : courts, **12 caractères au plus si possible, sans espace** (ex. `BattementDnB` et non « Battement DnB »), pour ne pas déborder dans le journal.
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

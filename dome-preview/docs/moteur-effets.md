# Aide-mémoire du moteur d'effets

À lire à la place de `show.template.html` (320 Ko) quand il faut écrire ou régler une animation. Chercher dans le template seulement le détail manquant (`Grep` sur le nom d'une fonction), jamais le relire en entier.

## Où écrire
| Quoi | Où |
|---|---|
| Code d'un effet | `show.template.html`, bloc `Object.assign(FX,{ ... })` qui contient `'Montagne'`, `'Foudre'`… (chercher `« Recul sur la montagne »`). Puis `build.ps1`. |
| Type d'event de la banque | `TOOL_LIB` (même fichier) : `'Nom':{ cat, span, d:"description sans timing ni couleur", fx:{ n:'NomEffet', pal }, tail:secondes_de_retombée }` |
| Effets d'une phase | `mixes/<mix>/fxmap.js`, `phases["mm:ss"].fx` (clé = début de phase). **Pas d'apostrophe dans un commentaire** de ce fichier : `auto-layers.py` le lit. |
| Variations d'une phase réglée à la main | `mixes/<mix>/layers-plan.json` |
| Events placés à la main | `mixes/<mix>/events-plan.json` (`snap:false` = instant exact, `ov` = réglages) |
| Régénérer `layers.js` | `python tools/auto-layers.py <mix>` |
| Texte | `descriptif-<mix>.txt` : technique en gras, une rubrique `**▸ NomEffet**` par effet (c'est elle qui s'affiche au survol de l'encart) |

## Signature d'un effet
```js
'Nom': (t, w, p, f) => { /* ajoute de la lumière */ }
```
- `t` : temps du mix (s). `w` : poids 0..1 (fondus de phase, fenêtres). `p` : réglages (`fxmap.js` ou event). `f` : sons de l'instant (voir plus bas).
- Un event reçoit `p.t0` (début) et `p.span` (durée). Il doit s'éteindre de lui-même ; sa retombée après `span` doit tenir dans `tail` de `TOOL_LIB` (sinon coupure nette).
- Lire `p.level ?? 1` (variation « Intensité »), `p.tw ?? t` pour tout ce qui bouge (variation « Accélération »), `p.beat` (variation « Rythme », 0..1), `p.pal` (variation « Couleur »).
- Écrire : `add(L.id, hsv(teinte, saturation, valeur))` (addition). Pour assombrir tout le dôme : `GAIN *= x` (ex. `BattementDnB`).

## LEDs
`for (const L of LED)` : `L.id`, `L.r` (0 = sommet ; **le bord est à environ 0,80 et non 1** : diviser par `rimR()` pour raisonner de 0 à 1), `L.theta` (angle, rad), `L.x`, `L.y` (pixels, centre `CENTER`, rayon `R`), `L.bar` (barre), `L.h` (hauteur). Le nombre de LEDs par barre varie (4 à 60) : écrire en position continue, jamais en indices. Cache possible : `L._c`, `L._s` (cos / sin de theta).

## Son
- `f` = `feat(t)` : `bass, mid, high, flux, rms, drums, other, bassS` (0..1, 10 images/s).
- Tableaux complets : `E.vocals`, `E.bassN` (basse normalisée lente), `E.high`, `ES.*` (versions lissées ~1,6 s). Indice : `Math.floor((t-AVL)*10)`, borné à `NF-1`.
- Batterie : `BT.kick` / `BT.kickS` (instants, forces 1..7), `BT.hit` / `BT.hitS` (caisse claire + cymbales).
  - `kickEnv(t, tau, minS)`, `hitEnv(t, tau, minS)` : enveloppe 0..~0,7 qui retombe après chaque frappe.
  - `recent(BT.kick, BT.kickS, t, fenêtre, minS)` : indices des frappes récentes. `lastIdx(arr, t)`, `majorKicks(minS, gap)`.
- Temps : `SD.beats`, `SD.downbeats` (stems.js).

## Utilitaires
`clamp(x)`, `lerp(a,b,u)`, `ssG(x)` (lissage 0..1), `smooth`, `h32(n)` (hasard stable 0..1), `rng(seed)`, `hsv(h,s,v)` (h en degrés, négatif accepté), `vnoise(x,y)` (bruit 0..1), `adiff(a,b)` (écart d'angle), `PAL[nom](r,id)` → `[teinte, saturation]` (`fire, ember, lava, violet, ocean`), `lavaHSV(chaleur, valeur)`.
Chemins le long des barres : `walkPath(sommet, dir, min, max, graine)` (dir +1 vers le bord, −1 vers le centre), `eachPathLED(chemin, tête, id => ...)`, `interior` (sommets), `radV(v)`, `adj`.

## Couches
- **Base** : effet listé dans `fx` de la phase. `win:[[début, fin, fondu], ...]` le limite à des fenêtres.
- **Anim secondaire** : `layer:'mod', on:'NomDeBase'` dans `fx`, ou variation de `layers-plan.json` : `{ on, kind:'level'|'beat'|'speed'|'pal', t0, t1, pts:[[t, valeur], ...], why }`.
- **Events** : `events-plan.json` → `{ name, on, span, why, ov, snap }`.

## Règles à tenir
- Noms : 12 caractères au plus si possible, sans espace ; nom de type d'event unique.
- Coût : viser moins de 2 ms par image et par effet ; sortir tôt (`if (v < .012) continue`).
- Rythme (mix drum & bass) : pulsation générale sur chaque kick / caisse claire, effet chaîné sur les variations de basse, montées et ralentissements visibles. Voir le `CONTEXT.md` du mix.
- Au plus 3 familles de couleurs par phase, sauf intention contraire.

## Principes de mouvement (transposés aux LEDs)
Retenus de skills de motion design pour interfaces (désinstallés depuis : `design-motion-principles`, `web-animation-design`). Le skill `motion-design` reste installé pour le vocabulaire complet.
- **Chaque mouvement a une raison** (un son, un passage du récit, une continuité). Si on ne sait pas la nommer, on l'enlève.
- **Règle de fréquence** : ce qui revient à chaque kick reste discret et bref ; ce qui est rare (coup fort, drop, event unique) peut être ample et expressif. Un effet qu'on remarque à chaque battement est trop fort.
- **Courbes de vitesse** : ce qui apparaît part vite et arrive doucement ; ce qui est déjà à l'image et se déplace est lissé aux deux bouts ; ce qui tombe ou s'en va accélère ; jamais de vitesse constante, sauf un défilement continu voulu. Pas de rebond sur ce qui se répète.
- **Jamais à partir de rien** : un élément naît d'une lueur ou d'une taille réduite, pas du noir total ni de zéro ; une traîne garde un fond de lumière.
- **Sorties plus discrètes que les entrées** : plus courtes, moins de déplacement ; l'attention est déjà ailleurs.
- **Taille et durée** : un petit élément va plus vite qu'un grand ; plus le trajet est long, plus il dure.
- **Éléments liés** (tête et traîne, lave et vapeur, flash et retombée) : même horloge, même courbe, pour qu'ils se lisent comme un seul geste.
- **Origine** : un élément grandit depuis sa source (le point d'impact, le bord, le sommet), pas depuis son propre centre.
- **Décalages** : une file d'éléments décalés reste courte (quelques éléments, moins d'une demi-seconde au total) ; pas de cascade systématique.
- **Pas de variété gratuite** : ne pas appliquer le même fondu à tout, ni un effet différent à chaque élément ; rester cohérent avec les effets déjà présents dans la phase et le mix.
- **Photosensibilité** : pas de grands zooms, rotations rapides ou clignotements de tout le dôme sans raison musicale forte (voir aussi le skill `animadome-son-lumiere`).

## Pièges rencontrés (à relire avant de coder)
- **Ne jamais nommer un réglage `n`** dans `fxmap.js` : `n` est le nom de l'effet (`{ n:'Torrents', n:12 }` remplace le nom par 12). Utiliser `count`, `fronts`…
- **Python** : les outils (`fill-gaps.py`, `phase-brief.py`, `auto-layers.py`) ont besoin de l'environnement `audio-analysis\venv\Scripts\python.exe` (numpy, librosa), pas du Python du système ; poser `PYTHONIOENCODING=utf-8`. Ils prennent le **chemin** du mix (`mixes/pyrobeats`), pas son nom.
- **Variations de `layers-plan.json`** : seulement `level`, `beat`, `speed`, `pal`. `speed` règle `p.tw` : un effet qui lit `t` au lieu de `p.tw ?? t` ne la sent pas. Pour faire évoluer un autre réglage au fil de la phase, le prévoir dans l'effet (`t0`, `t1`, valeur de départ et d'arrivée).
- **`layers-plan.json` remplace toutes les variations automatiques de la phase** : ne l'utiliser que si on veut les réécrire ; sinon les variations automatiques de l'effet de base sont perdues.
- **Events automatiques** : `auto-layers.py` peut en retirer un quand un event du plan tombe trop près ; comparer la liste d'events de la phase avant et après (`aniCheckPhase(n).events`).
- **Mesure `pulsationKicks`** : elle compare la luminosité 0,03 s et 0,25 s après un kick. Quand les kicks sont plus rapprochés que 0,25 s, un effet seulement additif plafonne vers 1,1 ; il faut un léger creux entre les kicks (`GAIN *= …`, réglage `dip` de 0,2 environ) pour passer 1,3. Le garder réglable : l'auteur peut préférer moins de creux.
- **Un effet de base ajouté apparaît en fondu à la fin de la phase précédente** : c'est voulu (pas de passage abrupt), mais vérifier la phase voisine (`aniCheckPhase(n-1)`), surtout si elle est appréciée telle quelle.
- **Effets partagés** : ne pas modifier le code d'un effet utilisé par une autre phase (ex. `Flammes`) pour en régler une seule ; ajouter un effet ou une variation chaînée (`layer:'mod'`).
- **Chemins le long des barres déjà construits** : `cracks` (70 chemins, du bord vers le sommet), `bolts` (40, du sommet vers le bord), `seeps` (14, longs, du sommet vers le bord). Un chemin vers le bord continue souvent sur le cercle extérieur en fin de course.
- **Sons normalisés trompeurs** : `f.bass` et `E.bassN` restent vers 0,7 même quand la fiche dit « sans basse » (ex. phase 12, 13:55 → 14:07) ; pour une entrée ou une sortie d'instrument, se fier aux sections de la fiche et l'écrire en réglage de temps dans l'effet (ex. `g0` de `Déferle`), pas à un seuil sur `f`.
- **Forces de frappes faibles** : dans certaines phases les kicks ne dépassent pas 3 (phase 12) ; ne pas filtrer par `minS` élevé ni diviser la force par 5 sans plancher, sinon l'effet reste invisible.
- **Mesure de luminosité et `GAIN`** : après `computeBuf(t)`, `buf` contient déjà l'assombrissement `GAIN` ; `aniCheckPhase` le multiplie encore par `GAIN`, donc un effet qui assombrit (`Battement`, lever de lumière de `Crépite`) paraît deux fois plus creusé dans `luminositeMaxPar5s` qu'à l'image. Pour la vraie valeur : moyenne de `buf` seule.
- **Frappes hors batterie** : `BT.hit` contient aussi les petits sons isolés des passages sans rythme (ex. phase 1 de Pyrobeats, forces 1 à 9) ; `recent(BT.hit, BT.hitS, t, durée, 1)` permet de leur donner un répondant local même quand la fiche dit « aucun repère régulier ».
- **Pas de piste charleston séparée dans la page** : les aigus ne sont que `f.high` / `E.high` (10 images/s, normalisés, vers 0,8 en continu) ; les charlestons d'une drum & bass à 143 bpm n'y apparaissent pas une à une. S'en servir comme densité de texture (seuil sur le niveau), pas comme frappes ; les frappes sont dans `BT.hit`.
- **`E.vocals` normalisé** : reste vers 0,5 à 0,9 même sans voix ; pour la voix, écrire les sections de la fiche en réglage de temps (ex. `voice:[[début, fin], ...]` de `Grésille`) et ne garder `E.vocals` que pour moduler.
- **Coups forts** : un critère « frappe + kick à moins de 70 ms » en trouve trois fois plus que la fiche (96 contre 28 en phase 3 de Pyrobeats) ; passer les instants de la fiche en réglage (`strong:[...]`).
- **Effet qui lit `buf`** : une variation placée après l'effet de base dans `fx` peut lire `buf` pour ne toucher que la lave déjà allumée (grésillement) ; les events sont calculés après, elle ne les voit pas.
- **Variante pour `compare.html`** : relancer `auto-layers.py` **avant** de copier `layers.js` dans `variants/<nom>/` (sinon la variante garde l'ancien `layers.js`) ; recopier aussi `fxmap.js` après chaque réglage.
- **SlowLava est exclusif** : tant qu'un event SlowLava (sans `overlay`) est actif, seuls SlowLava, Noir, TriGlitch et Éruption sont dessinés ; une variation placée sur ces instants est invisible (ex. phase 6 de Pyrobeats après 7:47). Vérifier les events de la phase avant de caler des réglages de temps.
- **`pulsationKicks` et SlowLava** : la mesure prend la médiane sur toute la phase ; si des SlowLava exclusifs en couvrent la plus grande partie (phase 8 de Pyrobeats : 9:15 → 10:10), elle reflète SlowLava et non la variation ajoutée. Mesurer alors le même rapport sur la seule fenêtre libre (kicks de la fenêtre, `mean(x+.03)/mean(x+.25)`).
- **Kicks très serrés (roulements à ~0,17 s)** : le `dip` ne suffit pas si l'enveloppe du kick est lente (`kickEnv` τ 0,13 : pulsationKicks 1,02 même avec un fort creux) ; une enveloppe brève (τ ≈ 0,06, réglage `ktau` d'`Extinction`) remonte à 1,5. Un event du plan à moins de 3,5 s d'un event automatique le retire : le recopier dans `events-plan.json` pour le garder.
- **Recopier un event automatique par précaution le double** s'il n'est pas retiré (phase 20 de Pyrobeats : events du plan à 1-3 s des events auto, aucun retiré) ; poser d'abord les events du plan, relancer `auto-layers.py`, comparer `aniCheckPhase(n).events`, et ne recopier que ceux qui ont disparu.
- **Event calé sur un front mobile** : plutôt que de calculer à la main le rayon de chaque occurrence, l'effet de base expose sa position (`FX['Limace']._fr(t, angle)`, horloge intégrée et normalisée pour arriver pile à `t1`) et l'event la lit à son `t0` (repli sur `p.rb` si l'effet n'a pas encore tourné).
- **Mesure du coût** : `msMedian` varie du simple au double selon la charge de la machine ; mesurer l'original et la nouvelle version dans la même foulée, et un effet seul par une boucle `FX[nom](t,1,réglages,feat(t))`.
- **Vue Cinematic, mesurer le canevas** : le temps passé dans `drawCine` ne compte que l'envoi des ordres (le canevas est rendu par le GPU plus tard) ; mesurer plusieurs images puis un `getImageData(0,0,1,1)` qui force le rendu, et diviser. Remettre `CINE.fixed` à `undefined` si une mesure est interrompue (sinon la vue reste figée à cette définition).
- **Canevas 2D : le coût est dans le nombre de tracés**, pas dans les pixels : ~3 700 petits traits par image coûtaient ~20 ms même sur un canevas minuscule. Un trait par barre coloré par un dégradé (un arrêt par LED) suffit. Les dégradés créés par élément et par image (branches de glints, traînées) coûtent aussi : les précalculer dans **un seul** atlas (`cineAtlas`) ; des centaines de petits canevas séparés sont pires (chaque petit canevas redevient une texture envoyée au GPU à chaque usage).
- **Motif répété décalé dans le temps** (caustiques) : ramener le décalage modulo la tuile, sinon il grandit sans fin et le motif sort de la zone remplie au bout de quelques minutes (caustiques invisibles en fin de mix).
- **`globalAlpha` laissé par une boucle** : après une boucle qui règle `cV.globalAlpha` (lueurs, braises), un effet suivant en hérite ; l'entourer de `save()` / `restore()`.
- **Scripts de remplacement lancés depuis Git Bash** : un `heredoc` peut perdre les barres obliques inverses (`\'` devient `'`, `\\n` devient un vrai saut de ligne) et casser une chaîne JavaScript du template (toute la page s'arrête : « Unexpected identifier »). Écrire le script Python dans un fichier avec l'outil d'écriture, ou utiliser l'apostrophe typographique ’ dans les textes.
- **Effets à particules** (étincelles du fond braises) : l'état avance image par image (`dt`), remis à zéro après un saut dans le temps ; c'est valable parce que le cache et l'enregistrement rendent les images dans l'ordre.

## Comparer plusieurs versions d'une phase
- `compare.html?variants=original,essai&from=<s>&to=<s>` (par le serveur local, jamais en `file://`) joue plusieurs versions côte à côte, synchronisées ; le son vient de la première.
- Une version = un dossier `mixes/<mix>/variants/<nom>/` contenant `fxmap.js` et `layers.js` ; la page les charge avec `show.html?variant=<nom>`. Le code des effets reste commun (le template doit contenir les effets de toutes les versions comparées).
- Avant de refaire une phase : copier les fichiers du mix et le template dans `mixes/<mix>/clean/backups/avant-refonte-phaseNN/`. Après le choix de l'auteur : retirer du template les effets non retenus, vider `variants/`, mettre à jour `CONTEXT.md`.

## Méthode validée pour refaire une phase (comparatifs des phases 27 et 29)
Réglage : modèle supérieur, **effort moyen** (l'effort faible donne une phase plus plate, sans évolution dans le temps).
1. **Sauvegarder** : fichiers du mix + template dans `mixes/<mix>/clean/backups/avant-refonte-phaseNN/`.
2. **Lire la fiche** (`phase-brief.py`) et le texte de la phase et de ses deux voisines dans le descriptif ; relever ce qui existe déjà (effets de `fxmap.js`, events de la phase dans `layers.js`, events posés à la main dans `events-timing.json`).
3. **Découper la phase en actes** d'après la fiche (sections, entrées et sorties d'instruments, respirations de la batterie, roulements, coups forts) : un début, un développement, une fin qui prépare la phase suivante.
4. **Donner un rôle à chaque rythme de chaque piste**, pas seulement au kick : kicks = pulsation générale et avancée par crans ; coups forts (deux instruments ensemble) = events dont le moment clé tombe pile dessus ; basse = respiration d'une traîne ou d'un fond ; synthés / voix = relais quand la batterie se tait ; roulements = montées ; silences = retombées visibles.
5. **Faire évoluer la phase dans le temps** : nombre d'éléments, ampleur, vitesse ou place d'une couleur qui change du début à la fin (réglages `t0`, `t1`, valeur de départ et d'arrivée dans l'effet).
6. **Garder l'existant** : l'effet de base et tous les events d'origine restent ; on ajoute un effet de base ou une variation chaînée (`layer:'mod'`) et un ou deux types d'events. Rester dans la palette de la phase (3 familles au plus).
7. **Events calés à la main** : dans `events-plan.json`, `snap:false`, début = instant du coup fort moins le délai interne de l'effet (ex. un arbre qui s'abat 0,8 s après son début) ; faire varier taille et position d'une occurrence à l'autre par `ov` (progression autour du dôme, taille qui grandit).
8. **Câbler** : `fxmap.js`, `events-plan.json`, rubriques `**▸ Nom**` du descriptif, `auto-layers.py`, `build.ps1`.
9. **Mesurer** : `aniCheckPhase(n)` (aucune erreur, coût, `pulsationKicks` > 1,3, liste d'events inchangée pour ceux d'origine) et les deux phases voisines.
10. **Montrer** : `compare.html?variants=original,actuel&from=<début-4>&to=<fin+4>` ; l'auteur juge à l'œil avec le son. Noter le résultat dans `CONTEXT.md`.
Une phase déjà bien travaillée ne se refait pas : retouches précises seulement (rythme, transitions, détails), sans toucher aux effets posés volontairement par l'auteur.

## Vérifier
Dans la page (console ou outil navigateur) : `aniCheckPhase(11)` → erreurs, coût par image, effets et events actifs, `pulsationKicks` (> 1,3 = le dôme pulse sur les kicks), luminosité par tranche de 5 s. Juger ensuite à l'œil avec le son : la mesure ne remplace pas le regard de l'auteur.

## Pièges Cinematic appris pendant la mise au point de l'interface
- **Limite de cadence du rendu direct** (réglage « live ») : la tester **avant** `cineIdle(t)`. Sinon l'image sautée est déjà marquée « dessinée » et l'écran reste noir à l'arrêt.
- **GéoLists et Cinematic s'excluent** : `cineSet(true)` désactive GéoLists, sinon `renderDome` prend la branche Géo et le canvas Cinematic reste noir (cas d'un rechargement avec les deux mémorisés).
- **F11 / Échap en plein écran** : certains navigateurs sortent eux-mêmes du plein écran *et* envoient la touche à la page ; ignorer F11 pendant ~0,6 s après `fullscreenchange`, et faire d'Échap un simple retour à la fenêtre normale.
- **Défauts mémorisés** : toute valeur enregistrée sans choix de l'auteur (défaut) doit être migrée en montant la version de `animadome_cine_v2` ; ne jamais écraser un choix explicite (ex. `animadome_cine_trackset` pour « Artiste et morceau »).
- **Compteur FPS** : compter les images réellement affichées (cache ou rendu direct), pas les `requestAnimationFrame`.
- **LEDs / barre** : sans effet visible en Cinematic (tubes continus avec dégradé) ; réglage masqué dans cette vue.

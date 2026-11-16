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
`for (const L of LED)` : `L.id`, `L.r` (0 = sommet, 1 = bord), `L.theta` (angle, rad), `L.x`, `L.y` (pixels, centre `CENTER`, rayon `R`), `L.bar` (barre), `L.h` (hauteur). Le nombre de LEDs par barre varie (4 à 60) : écrire en position continue, jamais en indices. Cache possible : `L._c`, `L._s` (cos / sin de theta).

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

## Vérifier
Dans la page (console ou outil navigateur) : `aniCheckPhase(11)` → erreurs, coût par image, effets et events actifs, `pulsationKicks` (> 1,3 = le dôme pulse sur les kicks), luminosité par tranche de 5 s. Juger ensuite à l'œil avec le son : la mesure ne remplace pas le regard de l'auteur.

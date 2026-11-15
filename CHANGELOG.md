# Changelog

## v1.3.0 — 2026-11-15

Couches d'animation et nouveaux events.
- Trois couches dans le journal : Anim base layer, Anim secondaire (variations chaînées : intensité, accélération, contraste du rythme, couleur) et Events, avec un interrupteur par couche (qui coupe aussi la timeline), encarts colorés, Ctrl+clic = mode solo temporaire, clic = aller à l'effet dans la timeline, bouton prompter
- Passe automatique (tools/auto-layers.py -> layers.js, annulable en supprimant le fichier) : variations, events ajoutés et calés sur le rythme (premier temps, kicks, attaques marquées ; fin sur une mesure ou une phrase)
- 6 nouveaux events dans la banque : OndeDeChoc, Spirale, Balayage (Geometric / Basics), Marée, Bulles (Water), Cendres (Volcano)
- Poignées de redimensionnement du dôme (la fenêtre de phase garde sa hauteur) et de la timeline ; LEDs par barre mémorisées
- Select Audio Files : avertissement si les durées diffèrent, possibilité de joindre le descriptif écrit
- Zone de prompt renommée PROMPTEUR : ask me anything ; ligne de phase et boutons à droite ; plus d'erreur 404 pour un rapport de nettoyage absent

## v1.2.0 — 2026-11-15

Nouvelle analyse du son, bien plus précise.
- Select Audio files : avertissement si les pistes n'ont pas la même durée ; copies de pistes supprimées après l'analyse ; bouton sur une seule ligne
- Analyse : départs de sons de chaque piste en 44,1 kHz (superflux), batterie séparée (Demucs htdemucs_ft + drumsep : kick, caisse claire, toms, hi-hat, ride, crash), temps et premiers temps par beat_this, bilan par phase à relire avec le descriptif (analysis2.report.md)
- Les kicks et frappes qui pilotent les animations viennent de la batterie séparée (beaucoup mieux calés sur les temps)
- Anciens outils d'analyse remplacés (analyze-beats, stems-to-beats, analyze-tracks) ; check-analysis vérifie beat_this et mdxnet-infer
- Serveur : plus d'erreur 404 en console pour un rapport de nettoyage absent
- README, CLAUDE.md et skill mis à jour

## v1.1.0 — 2026-11-14

Première version utilisable à 100 % par des collaborateurs.
- Publication des phases d'un mix (fichier préfixé par le nom d'utilisateur) et récupération d'UNE phase (clic sur la barre colorée, « PHASE X » ou le titre), avec marqueurs jaune strié de rouge, check for updates, vérification discrète sur GitHub, sauvegarde et annulation
- Boutons publish tool version / update tool version
- Journal des events en encarts (description au survol), titre de phase et timing réorganisés
- Vue 3D : halo des LEDs, ciel étoilé, caméra Free passant sous le dôme
- Mix dans un dépôt séparé ; CLAUDE.md, setup.ps1, build.ps1, README complétés

## v1.0.0 — 2026-11-14

Première version publiée.
- Vue 2D de référence et vue 3D (Top, Free, Centre), halo des LEDs, ciel étoilé
- GéoLists, timeline, Event Bank, analyse du son
- Mix séparés de l'outil (dépôt MIX_Animadome)
- Boutons publish tool version / update version


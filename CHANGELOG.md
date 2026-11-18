# Changelog

## v2.0.0 — 2026-11-18

Vue Cinematic, repères IA / outil et mode d'emploi plus clair.
- Vue Cinematic (version YouTube du dôme) intégrée à l'onglet de gauche : fonds animés (étoiles, volcan et lave, 20 000 lieues sous les mers, roche, géode, glacier, forêt, jour venteux, ruissellements, glitch, noir, et un mode Automatique qui suit la couleur du dôme), halos, glints, vagues et échos sur les kicks, traînées de vitesse, Lens Dirt, grain, rotation lente, logo, titre du mix et « Artiste et morceau » (liste de chapitres « Artistes et morceaux », texte YouTube copiable)
- Record : enregistrement MP4 image par image en arrière-plan (intervalle au choix, Full HD ou 4K, 30 ou 60 i/s, H.264 réglé pour la fluidité), les vues 2D et 3D restent utilisables ; aperçu plein écran F11 ; cache de lecture automatique
- Panneau de réglages Cinematic dans le volet de droite (fond, effets, nomenclature, format, enregistrement) ; le descriptif et l'Event Bank s'effacent dans cette vue ; la vue choisie est rétablie au rechargement
- Repères d'avertissement : badge jaune IA (ce qui envoie un prompt à une IA, boutons grisés sans IA connectée, proposition de la connecter) et badge orange clé à molette (outil à installer : ffmpeg, Git, outils d'analyse du son, installation proposée avec confirmation de la commande)
- Phases de Pyrobeats refaites et publiées ; nouveaux effets de fond et d'events
- Interface : ordre des vues 2D / 3D / GéoLists, séparateur de la timeline, texte des raccourcis, en-tête réorganisé (version au-dessus de PUBLISH, barre d'enregistrement à droite)
- Docs : README, CLAUDE.md (mode Cinematic, repères IA / outil, veilleur au démarrage), docs/moteur-effets.md ; skill motion-design (MIT) inclus

## v1.4.0 — 2026-11-16

Interface et outils pour travailler phase par phase.
- Poignée au-dessus de la timeline : elle réduit en conséquence le dôme et la fenêtre de texte ; au démarrage l'interface remplit 100 % de l'espace (les tailles réglées à la souris ne durent que la session) ; plus de marge inutile en bas
- Pipette RGB : cadre fixe en bas à droite du schéma 2D (masqué en 3D et GéoLists) ; le texte « barres adressables » passe à gauche
- Nouveaux effets : Montagne, BattementDnB (pulsation générale sur chaque kick et caisse claire), Grondement (variations de basse), VoixAnneau (la voix remplit un anneau comme une barre de volume, pleine au volume maximum de la phase) ; nouveaux events Foudre, Aurore, ÉchoCristal, Panache, Surchauffe
- tools/fill-gaps.py : comble les trous d'export (passages où les pistes fournies sont muettes) en analysant le mix lui-même
- tools/phase-brief.py : fiche rythmique d'une phase ; aniCheckPhase(n) dans la page : bilan de vérification ; docs/moteur-effets.md : aide-mémoire du moteur d'effets
- auto-layers.py : layers-plan.json (phase réglée à la main), events-plan snap:false, échelle d'énergie inchangée par les trous comblés
- CLAUDE.md : règles de choix du modèle par niveau, méthode phase par phase, noms d'animations de 12 caractères au plus

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


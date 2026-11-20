# Changelog

## v2.3.1 — 2026-11-20

Optimisation et rangement.
- Nettoyage de l'outil : README mis à jour (vue Cinematic, mode par défaut, analyse en arrière-plan, notes de version), script obsolète analyze-gut.ps1 retiré (remplacé par l'analyse des stems), anciennes mesures du mode Automatique purgées, variable inutilisée supprimée
- Cinematic : enregistrement hors ligne rendu indépendant de la vitesse du PC pour les fondus de forme et de Constellation ; coûts par fond mesurés et notés dans la documentation (docs/moteur-effets.md)

## v2.3.0 — 2026-11-19

Cinematic repensé : nouveaux fonds, formes du dôme, barre de lecture aux couleurs du mix, menu des phases et liens GitHub.
- Cinematic, fond Forêt : préparation 12 fois plus rapide et plus de reconstruction à chaque redimensionnement (l'onglet pouvait se figer).
- Cinematic, fond Automatique : chaque fond lu utilise ses effets par défaut (le panneau ne montre plus de cases dans ce mode), au lieu de tout cocher ou tout décocher
- Cinematic : nouveaux fonds animés Glacier (lac entouré de banquise bleu glacier qui se fend en rythme, aurore boréale, neige, flocons cristallins, givre, scintilles) et Jour venteux (météo du temps gris au beau temps selon la tonalité de la musique, nuages, air liquide, bourrasques, confettis).
- Interface : plus de curseur en forme de main sur les boutons et la timeline (flèche partout) ; en Cinematic, les calques 2D / 3D sont masqués pour ne jamais apparaître derrière la vidéo quand la fenêtre est réduite
- Cinematic, fond Automatique : couleurs → fonds revues (rose et violet → Géode, bleu clair → Jour venteux, bleu → Ruissellements, bleu foncé → Fond marin) ; « 20 000 lieues sous les mers » devient « Fond marin »
- Cinematic : la timeline habituelle et les boutons de phases, de boucle et de stems disparaissent ; il reste une barre de lecture (lecture / pause, timer, volume) dont la piste reprend les couleurs du mix, identique en fenêtre normale et en plein écran
- Interface : bloc timer et boutons de lecture plus compact (le timer passe au-dessus des boutons quand la colonne est étroite), prompteur qui n'est plus rogné dans les fenêtres basses (la liste des animations défile), plus de filet au-dessus de « Réglages enregistrement » en Cinematic
- Menu d'une phase : « Update phase » (la fenêtre vérifie toute seule sur GitHub et dit si la phase est à jour) à la place de « updater phase » et « check for updates », nouveau « Go to phases Github » ; bouton « Go to Animadome Github » à droite de PUBLISH ; sur un mix sans phase décrite, le grand titre et le nom du mix de Cinematic sont aux couleurs de la roue chromatique
- Cinematic, tiroir Nomenclature : option « Barre de lecture » (active par défaut) qui dessine tout en bas de la vidéo un trait fin aux couleurs du mix, avec la partie jouée lumineuse, une lueur à la position et de fines coupures aux débuts de morceaux ; elle est aussi dans les vidéos enregistrées
- Cinematic : sélecteur « Forme du Dôme » (Arcs, Bulle, 3D sphere, Cristal, Torsion, Fleur) avec la case « Anguleux », au-dessus du tiroir FX Dôme ; « Constellation » devient une case de FX Dôme, avec une forme proposée pour chaque fond et un fondu entre deux formes.
- Cinematic : tiroirs « FX Dome » et « FX globaux » (anciennement FX et Effets fixes) ; en mode Automatique, la forme du dôme suit le fond lu avec un fondu à chaque transition

## v2.2.0 — 2026-11-19

Cinematic plus complet, analyse du son en arrière-plan et veilles allégées.
- Cinematic : « Réglages enregistrement » (images par seconde live 10 à 60, enregistrement toujours à 60 FPS, son AAC 320 kbps, « Select better audio quality » pour utiliser un WAV ou FLAC à la place du MP3), bouton 📁 pour ouvrir le dossier d'export, descriptif en infobulle de chaque effet de fond (ce qu'il fait et en fonction de quoi il varie), timeline réduite par défaut dans la vue, logo BIODÔME réaligné
- Plein écran Cinematic (F11) : sélecteur de mix et barre de lecture, curseur et toute l'interface qui s'effacent après 4 s sans mouvement de souris
- Fonds animés : Forêt, Géode (cristaux, réfraction, éclats de verre) et Glitch (électronique, cartes à puces), avec leurs effets de fond cochés par défaut ; « Automatique » démarre sans aucun effet coché
- Timeline : la barre de séquences prend la couleur moyenne du dôme en fonction du temps (plus une couleur par séquence)
- Select Audio files : l'analyse se fait en arrière-plan avec une barre de progression sur la timeline, le journal au clic et une fenêtre « Ton son est analysé ! » ; titre « C · Descriptif écrit »
- Mode par défaut sans IA : un mix sans phase décrite montre une couleur uniforme qui parcourt la roue chromatique, avec une pulsation douce sur le rythme
- Vue 3D : caméra « centre » dézoomée par défaut et verrouillée vers le bas à 100° du zénith
- Interface : badges IA verts quand une IA est connectée, notes de version pré-remplies dans Publish, veilles en arrière-plan espacées (descriptif 12 s, GitHub 15 min, veilleur 5 s), timeline qui retrouve sa taille en quittant Cinematic

## v2.1.0 — 2026-11-19

Mode Cinematic affiné et raccourci de lancement.
- Cinematic : réglage « Images par seconde (live) » (10 à 60, défaut 20) séparé de l'enregistrement, désormais toujours à 60 FPS ; compteur de FPS sous la vidéo ; clic sur le dôme = lecture / pause ; F11 et Échap reviennent à la fenêtre normale sans changer de vue
- Tiroirs du panneau Cinematic : « FX », « Effets fixes » (Lens Dirt, Vignettage, Grain, nouvelles Aberrations chromatiques cochées par défaut), « Effets du fond » par fond avec défauts propres (Braises volantes sur Volcan et lave, Lucioles flottantes sur Forêt et 20 000 lieues sous les mers, rien de coché en Automatique) ; Étincelles du dôme rangées dans le fond Volcan et lave ; fonds renommés (Space-Opéra, Hyperespace, Nébuleuses, Bancs animaux marins)
- Fonds : Papier brûlé et Braises plus vivants sur Volcan, fond marin retouché, méduses qui pulsent sur le beat, Lens Dirt moins fort
- « Artiste et morceau » : lit la liste enregistrée dans le mix, coché par défaut s'il y a une liste, texte dans le style du logo ; fenêtre renommée « Artistes et morceaux (chapitres de la playlist) » ; astuce Ctrl + Espace pour coller le timing
- Interface : prompteur toujours visible (en bas dans GéoLists et Event Bank), avec une tirette pour l'agrandir ; menus déroulants au-dessus du contenu ; séparateur de la timeline plus discret et plus proche ; notes de version et aide du descriptif plus lisibles ; bouton d'analyse grisé sans outils
- Nouveau : RUN_ANIMADOME.bat à la racine (lance le serveur et ouvre la page) et son icône ; README, CLAUDE.md et docs/moteur-effets.md mis à jour

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


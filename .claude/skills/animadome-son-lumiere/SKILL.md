---
name: animadome-son-lumiere
description: Connaissances de technicien son et lumière pour ANIMADÔME (dôme géodésique de LEDs adressables piloté par un mix audio) : pilotage sACN/DMX, alimentation, gamma et couleur, photosensibilité, synchronisation son/lumière, analyse audio, ambisonie. À consulter avant de proposer ou de régler un effet destiné au dôme réel, ou quand on parle d'export TouchDesigner, de contrôleurs, de brillance ou de synchro.
---

# Son et lumière pour ANIMADÔME

Ce que l'outil montre à l'écran n'est pas ce que les LEDs rendront : la vue 2D est la référence **géométrique**, pas colorimétrique. Garde ces points en tête quand tu règles un effet.

## Pilotage (sACN / Art-Net / DMX)
- Un univers DMX = 512 canaux = **170 pixels RGB** (510 canaux utiles, 2 inutilisés ; certains contrôleurs imposent 510). Un pixel peut être scindé sur deux univers selon le contrôleur : vérifier sa fiche.
- Ordre de grandeur : avec 42 LEDs par barre et 120 barres, 5040 LEDs = environ **30 univers** ; un réseau gigabit suffit largement à 40 images/s.
- sACN (E1.31) : l'adresse multicast dérive du numéro d'univers (239.255.haut.bas). Art-Net : diffusion ou unicast. Préférer le **unicast** vers chaque contrôleur si le switch ne gère pas bien le multicast.
- Les contrôleurs de pixels limitent le nombre de LEDs **par sortie** selon la fréquence d'images (le protocole des LEDs WS281x/SK6812 prend environ 30 µs par pixel) : répartir les barres sur plusieurs sorties et viser 30 à 60 images/s. À vérifier sur la fiche du contrôleur choisi.
- Côté TouchDesigner : sACN Out / DMX Out, pixel mapping par barre ; la correspondance barre → LEDs → univers doit être une table explicite, générée depuis `dome-geometry.json` et le nombre de LEDs par barre.

## Alimentation et sécurité électrique
- Ordre de grandeur : une LED RGB peut tirer jusqu'à 60 mA à pleine puissance (blanc) ; 5040 LEDs = plusieurs centaines d'ampères sous 5 V dans le pire cas. En pratique la luminosité moyenne est bien plus basse, mais **dimensionner pour le pire cas ou plafonner la luminosité globale**.
- Prévoir l'**injection d'alimentation** régulièrement (la chute de tension fait virer le blanc au rouge en bout de ligne), des fusibles par segment et une section de câble adaptée.
- Tout ce qui touche au secteur, à la protection et au montage sous tension : **un électricien qualifié**. Ne jamais suggérer de câblage secteur à la légère.

## Couleur et luminosité
- Les LEDs sont **linéaires** ; les écrans et nos couleurs sont en sRGB. Appliquer une **correction gamma** (≈ 2,2 à 2,8) au dernier moment, et régler le blanc (balance des blancs des trois canaux) sur le dôme réel.
- Les dégradés sont plus naturels dans un espace perceptif (OKLab / OKLCH) que dans HSV.
- À faible luminosité, 8 bits par canal donne des paliers visibles : le dithering temporel ou des contrôleurs 16 bits aident. Éviter les fondus très lents sur du très sombre sans dithering.
- Diffuseurs, angle de vue et réflexion changent beaucoup le rendu : tester sur le vrai dôme avant de figer une animation.
- Caméras : la fréquence de rafraîchissement (PWM) des LEDs peut créer du scintillement à l'image.

## Photosensibilité (obligatoire)
- Pas de flashs de plus de **3 par seconde** (référence : WCAG 2.3.1, règle des trois flashs), attention particulière aux flashs rouges saturés et aux motifs à fort contraste qui alternent. Prévenir le public si un effet stroboscopique est voulu.
- Les effets de la banque comme *Stroboscope*, les glitches rapides et les alternances blanc/orange demandent cette vérification.

## Son et synchronisation
- Une animation « en rythme » se règle avec un **décalage son/lumière réglable** : la perception tolère mieux une lumière légèrement en avance qu'en retard, et la latence audio (carte son, Bluetooth, sono) doit être compensée à part.
- Pour caler TouchDesigner sur le morceau : timecode **LTC** ou MIDI, **OSC**, ou **Ableton Link** ; le projet Ableton du mix est la source de vérité du temps.
- Analyse (offline) : kicks, départs de notes, flux spectral, énergie par bande, rugosité (voir `dome-preview/tools/`). Bibliothèques : librosa (déjà utilisée), madmom (battements, mesures), Essentia. Les séparations de stems (Demucs) améliorent nettement la détection des kicks et de la basse.
- **Ambisonie** : les mix sont ambisoniques. L'analyse de la **direction d'arrivée** du son (azimut, élévation) permettrait d'allumer la bonne zone du dôme. Piste non exploitée aujourd'hui ; ne pas l'inventer sans demande, mais la proposer si une phase s'y prête.

## Réflexes pour ce projet
- Un effet qui devra être exporté vers le dôme réel doit être exprimé en **positions continues** (comme les effets actuels) et indépendant du nombre de LEDs par barre.
- Mesurer le coût de calcul de chaque effet (viser moins de 2 ms par image) : un export temps réel a le même besoin.
- Quand l'auteur demande « plus lumineux », vérifier la marge d'alimentation et la lisibilité (un blanc plein partout écrase les nuances).

## Références vérifiées
- Documentation WLED sur E1.31 / Art-Net : <https://kno.wled.ge/interfaces/e1.31-dmx/>
- Vixen Lights, concepts sACN : <https://www.vixenlights.com/docs/concepts/sacn/>
- Forum Derivative (TouchDesigner), univers DMX : <https://forum.derivative.ca/t/dmx-universes-help/980391>
- librosa (suivi de battements) : <https://librosa.org/doc/main/generated/librosa.beat.beat_track.html>

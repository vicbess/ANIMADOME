// ASSOCIATION PHASES / ÉVÈNEMENTS -> EFFETS  (le TEXTE vient de descriptif-pyrobeats.txt via descriptif.json)
// Clé = début de la phase "mm:ss" (ou instant de l'évènement). ok:true = effet validé par l'utilisateur (✓ dans l'interface).
// Tout le reste est une proposition. Les fondus entre phases sont calculés automatiquement d'après le son.
// Convention de gravité : la lave qui CHEMINE / s'écoule va du HAUT (centre) vers le BAS (bord) ; quand elle JAILLIT / EXPLOSE / REMONTE, c'est l'inverse (bord -> centre).
// Paramètre dir:'up' sur 'Tunnels de lave' et 'Pulsation audio' = la lave remonte (sinon elle chemine vers le bas).
// beat:0..1 sur "Pulsation audio" = part de la luminosité calée EXACTEMENT sur les kicks détectés (beats.js).
window.FXMAP = {
  // Dominante de couleur : rouge dominant jusqu'à la fin de la phase 3 (4:40), puis bascule graduellement vers l'orange pendant le début de la phase 4 (4:40 -> 5:40).
  hueGrade: [[0,1],[14,0.42],[120,0.42],[280,0.55],[340,1]],
  phases: {
    "00:00": { palette:'violet', fx:[{ n:'Terre violette' }] },
    "00:14": { palette:'ember',  fx:[{ n:'Terre violette', level:1.4, fadeStart:125, fadeEnd:160 }, { n:'Braises', mode:'wake', t0:17, t1:51, core:true, small:true }, { n:'Battement', t0:14, t1:135, a0:0.03, a1:0.4, onset:51, aOn:0.35 }] },
    "02:15": { palette:'lava',   fx:[{ n:'Terre violette', level:1.4, fadeStart:125, fadeEnd:160 }, { n:'Braises', mode:'steady', core:true, small:true, bassPulse:0.85 }, { n:'Tunnels de lave', dir:'up', more:true, snake:true, fronts:44, glitchBoost:0.6, t0:135, t1:250, jerk:[[162,175],[177,181],[183,189],[220,247,230]] }, { n:'Battement', t0:135, t1:135, a0:0.4, a1:0.4, minS:2, gap:0.17, tau:0.09, minW:0.35, spread:0.5 }, { n:'Halo violet', t0:189.5, t1:215.2, fadeIn:7, fadeOut:14, level:1.44, tun0:135, tun1:250 }, { n:'Trou de lave', noteFrom:196.6, noteTo:220.3, noteZ:1.8 }] },
    "04:40": { palette:'ember',  fx:[{ n:'Braises', mode:'steady', core:true, small:true, slow:true }, { n:'Tunnels de lave', t0:135, t1:250, slow:true }, { n:'Pulsation audio', dir:'up', pal:'ember', level:0.55, slow:true }, { n:'Jaillissement de lave', gut:{ from:283, to:345, thr:2.2, gap:0.25 }, rise:0.55, tail:0.4, amp:0.65 }] },
    "05:45": { palette:'lava',   fx:[{ n:'Braises', mode:'steady', core:true, small:true }, { n:'Tunnels de lave', dir:'up', t0:0, t1:1 }, { n:'Pulsation audio', dir:'up', pal:'lava', level:0.85, beat:0.4 }] },
    "07:12": { palette:'lava',   fx:[{ n:'Tunnels de lave', dir:'up', t0:0, t1:1 }, { n:'Pulsation audio', dir:'up', pal:'lava', level:0.9, beat:0.5, src:'drums+other' }, { n:'Étincelles', pal:'fire', amount:0.4 }] },
    "08:04": { palette:'fire',   fx:[{ n:'Pulsation audio', dir:'up', pal:'fire', level:0.9, beat:0.6 }, { n:'Étincelles', pal:'fire', amount:0.8 }] },
    "09:05": { palette:'ember',  fx:[{ n:'Braises', mode:'steady' }, { n:'Pulsation audio', dir:'up', pal:'ember', level:0.6 }] },
    "10:10": { palette:'fire',   fx:[{ n:'Jaillissement de lave', t0:610, rise:1.2, tail:2.5 }, { n:'Pulsation audio', dir:'up', pal:'fire', level:1, beat:0.35, src:'other' }, { n:'Étincelles', pal:'fire', amount:1 }] },
    "10:24": { palette:'fire',   fx:[{ n:'Pulsation audio', dir:'up', pal:'fire', level:1, beat:0.35, src:'other' }, { n:'Étincelles', pal:'fire', amount:1 }] },
    "11:10": { palette:'ember',  fx:[{ n:'Pulsation audio', pal:'lava', level:0.35 }, { n:'Éclairs', rate:0.4 }, { n:'Étincelles', pal:'violet', amount:0.25 }] },
    "13:21": { palette:'fire',   fx:[{ n:'Coulées', mode:'both', level:1 }, { n:'Étincelles', pal:'fire', amount:0.3 }] },
    "15:09": { palette:'ember',  fx:[{ n:'Pulsation audio', pal:'lava', level:0.3 }, { n:'Éclairs', rate:0.5 }] },
    "15:40": { palette:'fire',   fx:[{ n:'Coulées', mode:'both', level:1 }, { n:'Étincelles', pal:'fire', amount:0.3 }] },
    "16:47": { palette:'ember',  fx:[{ n:'Pulsation audio', pal:'ember', level:0.3 }, { n:'Éclairs', rate:0.4 }] },
    "17:20": { palette:'fire',   fx:[{ n:'Failles', level:1, minS:4 }, { n:'Pulsation audio', dir:'up', pal:'ember', level:0.4, beat:0.6 }, { n:'Étincelles', pal:'fire', amount:0.6 }] },
    "18:56": { palette:'ember',  fx:[{ n:'Failles', level:0.7, minS:6 }, { n:'Pulsation audio', pal:'ember', level:0.45 }] },
    "19:20": { palette:'lava',   fx:[{ n:'Braises', mode:'steady' }, { n:'Pulsation audio', dir:'up', pal:'lava', level:0.7 }] },
    "20:34": { palette:'ember',  fx:[{ n:'Pulsation audio', dir:'up', pal:'ember', level:0.5 }, { n:'Étincelles', pal:'violet', amount:0.3 }] },
    "21:21": { palette:'lava',   fx:[{ n:'Pulsation audio', dir:'up', pal:'lava', level:0.9, beat:0.7 }] },
    "22:02": { palette:'ember',  fx:[{ n:'Pulsation audio', pal:'lava', level:0.4 }, { n:'Étincelles', pal:'fire', amount:1.4, band:'mid', trail:8 }, { n:'Éclairs', rate:0.25 }] },
    "23:34": { palette:'fire',   fx:[{ n:'Tourbillon', level:1 }, { n:'Pulsation audio', pal:'fire', level:0.3, beat:0.8 }] },
    "25:29": { palette:'lava',   fx:[{ n:'Braises', mode:'steady' }, { n:'Tunnels de lave', dir:'up', t0:0, t1:1 }, { n:'Pulsation audio', dir:'up', pal:'lava', level:0.9, beat:0.6 }] },
    "29:12": { palette:'ember',  fx:[{ n:'Braises', mode:'steady' }, { n:'Pulsation audio', pal:'ember', level:0.8, beat:0.4 }] },
    "32:12": { palette:'fire',   fx:[{ n:'Jaillissement de lave', t0:1932, rise:1.2, tail:2.5 }, { n:'Pulsation audio', dir:'up', pal:'fire', level:1, beat:0.6 }] },
    "32:40": { palette:'fire',   fx:[{ n:'Flammes', level:1, debrisMinS:6 }, { n:'Étincelles', pal:'fire', amount:0.5 }] },
    "35:08": { palette:'fire',   fx:[{ n:'Flammes', level:1.1, speed:1.5, debrisMinS:5, src:'drums+other' }, { n:'Étincelles', pal:'fire', amount:1 }] },
    "36:50": { palette:'ember',  fx:[{ n:'Braises', mode:'steady' }, { n:'Flammes', level:0.35, speed:0.6, debrisMinS:9 }, { n:'Pulsation audio', pal:'ember', level:0.5 }] },
    "37:48": { palette:'ember',  fx:[{ n:'Pulsation audio', pal:'ember', level:0.45 }] },
    "39:00": { palette:'blue',   fx:[{ n:'Braises', mode:'steady' }, { n:'Pulsation audio', pal:'ocean', level:0.5 }, { n:'Vagues', level:0.4 }] },
    "41:25": { palette:'blue',   fx:[{ n:'Vagues', level:0.9 }, { n:'Collision lave-eau', t0:2485, repeats:5, period:22, spread:20, reach:0.78, fade:12, seepEvery:5, tips:1.8, gain:1.1 }, { n:'Pulsation audio', pal:'ocean', level:0.4 }] },
    "43:15": { palette:'blue',   fx:[{ n:'Vagues', level:1 }, { n:'Collision lave-eau', t0:2595, repeats:4, period:26, spread:22, reach:0.7, fade:12, seepEvery:6.5, tips:1.4, gain:1 }] },
    "45:00": { palette:'blue',   fx:[{ n:'Vagues', level:1 }, { n:'Collision lave-eau', t0:2700, repeats:4, period:32, spread:26, reach:0.62, fade:12 }, { n:'Étincelles', pal:'ocean', amount:0.5 }] },
    "47:15": { palette:'blue',   fx:[{ n:'Vagues', level:1, clear:1, dimT0:2850, dimT1:2955 }, { n:'Braises', mode:'sleep', t0:2850, t1:2955, core:true, small:true }] },
    "49:24": { palette:'dark',   fx:[] },
  },
  // Évènements ponctuels : durée visible (s) + effet
  // Descriptions GÉNÉRIQUES des types d'events (EVENT BANK) : aucune indication de temps, pour pouvoir les invoquer n'importe où.
  eventTypes: {
    'Cri': "Flash lumineux violet (30 % d'intensité) sur tout le dôme, calé sur l'attaque d'un son bref ; il s'efface au noir en environ 1,5 s.",
    'Ruée': "Pulsations et avancées de lave temporairement très rapides et très saccadées (la lumière descend au plus à environ 50 %, jamais jusqu'à l'extinction) ; flash rouge à l'attaque.",
    'LavaSpeed': "La lave rush, accélère et emplit plus de chemins en montant vers le centre ; elle s'ajoute aux autres effets sans les modifier ; entrée en montée de puissance progressive, sortie assez rapide.",
    'YaPuRien': "Extinction totale du dôme (tout noir, environ 0,25 s) puis rallumage rapide ; event très court.",
    'Vibration': "Pour des basses vibrantes et longues : le dôme vibre en luminosité (petits flashs très très rapides) et la couleur globale vire au rouge jusqu'à la fin de l'effet.",
    'Jaillissement': "La lave a un sursaut : un front de lave jaune-blanc jaillit du bord vers le centre, avec une courte traînée orange.",
  },
  events: {
    "02:36": { at:156.9, span:5.1, dur:6.0, fx:{ n:'LavaSpeed', span:5.1, out:0.7 } },   // LavaSpeed : la lave rush, accélère, emplit plus de chemins en montant vers le centre (s'ajoute à l'existant)
    "04:30": { at:270.8, span:9.0, dur:9.8, fx:{ n:'LavaSpeed', span:9.0, out:0.7, level:1.2, fill:0.5, startFrac:0.75, runFrac:0.4, inFrac:1.0, inPow:1.2, h0:54, h1:30 } },
    "03:35": { at:215.1, span:4.9, dur:5.8, fx:{ n:'LavaSpeed', span:4.9, out:0.7 } },
    "02:56": { at:176.9, span:0.5, dur:0.8, fx:{ n:'Noir', hold:0.25, back:0.2 } },   // YaPuRien : extinction totale du dôme puis rallumage (très court)
    "02:40": { at:160.1, span:1.7, dur:1.7, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    "03:07": { at:187.0, span:2.3, dur:2.3, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },   // ruée : pulsations et avancées de lave très rapides et saccadées + flash rouge à l'attaque
    "03:56": { at:236.6, span:1.2, dur:1.2, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    "03:58": { at:238.1, span:3.4, dur:3.4, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    
    "03:38": { at:218.5, span:2.0, dur:2.0, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    "03:53": { at:233.7, span:1.4, dur:1.4, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    "04:03": { at:243.1, span:4.7, dur:4.7, rush:1, fx:{ n:'Flash', hue:0, sat:1, level:0.5, tau:0.3 } },
    "04:08": { at:248.0, span:11.4, dur:11.4, fx:{ n:'Vibration', hz:18, amp:0.4 } },   // basses vibrantes et longues (4:08 -> ~4:19,4) : le dôme vibre en luminosité
    
    "02:21": { at:140.1, dur:4.5, fx:{ n:'Flash', hue:280, sat:0.9, level:0.3, tau:1.4 } },   // at = attaque réelle du cri dans le son (1500-6000 Hz) ; fondu au noir ~1,4 s
    "04:41": { dur:5, fx:{ n:'Jaillissement de lave', rise:1.5, tail:3.2 } },
  },
};

"""Analyse de PISTES SÉPARÉES d'un mix : pour chaque fichier audio d'un dossier, on relève
  - les départs de sons (onsets) avec leur force (0..1), à ~50 images/s ;
  - l'enveloppe d'énergie (0..99, relative au niveau maximal de la piste) ;
  - la « brillance » (centroïde spectral, 0..99).
Écrit tracks.js : window.TRACKS = { fps, dur, tracks:[ { name, file, dur, onsets:[[t,s],...], rms:[...], cen:[...] } ] }

Usage : python analyze-tracks.py <dossier des pistes> <sortie tracks.js> [<fichier audio de référence>]
Si un fichier de référence est donné, on signale les pistes dont la durée diffère de plus de 0,5 s.
"""
import sys, os, json
import numpy as np
import librosa
import soundfile as sf

SR = 22050
HOP = 441                  # 50 images par seconde
EXT = ('.wav', '.flac', '.mp3', '.m4a', '.ogg', '.aif', '.aiff')


def duration(path):
    try:
        return float(sf.info(path).duration)
    except Exception:
        return float(librosa.get_duration(path=path))


def analyse(path):
    y, _ = librosa.load(path, sr=SR, mono=True)
    if y.size == 0:
        raise ValueError('fichier vide')
    env = librosa.onset.onset_strength(y=y, sr=SR, hop_length=HOP)
    scale = float(np.percentile(env, 99.5)) or 1.0
    frames = librosa.onset.onset_detect(onset_envelope=env, sr=SR, hop_length=HOP, units='frames', backtrack=False)
    times = librosa.frames_to_time(frames, sr=SR, hop_length=HOP)
    onsets = [[round(float(t), 3), round(float(min(1.0, env[f] / scale)), 2)] for t, f in zip(times, frames)]
    rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=HOP)[0]
    db = 20.0 * np.log10(rms + 1e-6)
    top = float(db.max())
    level = np.clip((db - (top - 60.0)) / 60.0, 0, 1) * 99          # 60 dB de dynamique, relatif au maximum de la piste
    cen = librosa.feature.spectral_centroid(y=y, sr=SR, hop_length=HOP)[0] / (SR / 2.0) * 99
    return {
        'dur': round(len(y) / SR, 2),
        'onsets': onsets,
        'rms': [int(round(v)) for v in level],
        'cen': [int(round(min(99, v))) for v in cen],
        'peakDb': round(top, 1),
    }


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    folder, out = sys.argv[1], sys.argv[2]
    ref = duration(sys.argv[3]) if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else None
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith(EXT))
    if not files:
        print('ERREUR: aucune piste audio trouvée dans', folder); sys.exit(3)
    tracks, alerts = [], 0
    for i, f in enumerate(files, 1):
        print('PISTE %d/%d : %s' % (i, len(files), f), flush=True)
        path = os.path.join(folder, f)
        try:
            d = duration(path)
            if ref is not None and abs(d - ref) > 0.5:
                alerts += 1
                print('ALERTE: %s dure %.1f s au lieu de %.1f s (la piste doit avoir la même durée que l\'audio à lire)' % (f, d, ref), flush=True)
            a = analyse(path)
        except Exception as e:
            print('ERREUR: %s : %s' % (f, e), flush=True)
            continue
        a['name'] = os.path.splitext(f)[0]
        a['file'] = f
        tracks.append(a)
        print('  %d départs de sons, niveau max %.1f dB' % (len(a['onsets']), a['peakDb']), flush=True)
    if not tracks:
        print('ERREUR: aucune piste analysée'); sys.exit(4)
    data = {'fps': 50, 'dur': round(max(t['dur'] for t in tracks), 2), 'tracks': tracks}
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write('window.TRACKS=' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';')
    print('OK: %d piste(s) analysée(s) -> %s%s' % (len(tracks), out, ' (%d alerte(s) de durée)' % alerts if alerts else ''), flush=True)


if __name__ == '__main__':
    main()

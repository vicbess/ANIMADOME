# Comble les « trous d'export » de l'analyse v2 : les passages où les pistes séparées fournies sont muettes alors que le mix complet joue
# (piste oubliée à l'export, voix, etc.). Sur ces passages seulement, on analyse le MIX lui-même (demucs → batterie séparée → départs de sons,
# beat_this → temps) et on complète analysis2.js, beats.js et stems.js. Hors des trous, rien n'est modifié. Relançable sans risque (idempotent).
#   python fill-gaps.py <dossier_mix> [--list]      (--list : affiche seulement les trous détectés)
import sys, os, re, json, importlib.util, tempfile
import numpy as np, librosa, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('av2', os.path.join(HERE, 'analyze-v2.py')); av2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(av2)
FPS = 25; GAPTRACK = 'MIX_TROUS'
def mmss(t): return '%d:%04.1f' % (int(t) // 60, t % 60)

def read_js(path):
    s = open(path, encoding='utf-8').read(); body = s[s.index('=') + 1:].strip().rstrip(';')
    try: return s[:s.index('=') + 1], json.loads(body)
    except Exception: return s[:s.index('=') + 1], json.loads(re.sub(r'([{,])([A-Za-z_][A-Za-z0-9_]*):', r'\1"\2":', body))

def find_gaps(A, audio):
    """trous = mix audible (> -45 dB) alors que la somme des pistes est muette (< -70 dB), pendant au moins 3 s."""
    y, sr = librosa.load(audio, sr=22050, mono=True); hop = 22050 // FPS
    mix = 20 * np.log10(librosa.feature.rms(y=y, frame_length=2048, hop_length=hop)[0] + 1e-6); n = len(mix)
    P = np.zeros(n)
    for t in A['tracks']:
        if t['name'] == GAPTRACK: continue
        a = np.array(t['env']['rms'][:n], float); a = np.pad(a, (0, n - len(a)), constant_values=-120); P += 10 ** (a / 10)
    tr = 10 * np.log10(P + 1e-12); hole = (mix > -45) & (tr < -70)
    k = FPS // 2; hole = np.convolve(hole.astype(float), np.ones(2 * k + 1), 'same') > k   # ferme les micro-coupures
    gaps = []; i = 0
    while i < n:
        if hole[i]:
            j = i
            while j < n and hole[j]: j += 1
            if (j - i) / FPS >= 3: gaps.append([round(i / FPS, 2), round(j / FPS, 2)])
            i = j
        else: i += 1
    return gaps

def analyse_gap(audio, a, b):
    import torch
    from demucs.pretrained import get_model
    from demucs.apply import apply_model
    pad = 8.0; t0 = max(0, a - pad); dur = (b + pad) - t0; dev = 'cuda' if torch.cuda.is_available() else 'cpu'
    y, sr = librosa.load(audio, sr=44100, mono=False, offset=t0, duration=dur)
    if y.ndim == 1: y = np.stack([y, y])
    m = get_model('htdemucs'); m.eval()
    with torch.no_grad(): st = apply_model(m, torch.tensor(y)[None].float(), device=dev, shifts=1, split=True, overlap=.25)[0].cpu().numpy()
    stems = dict(zip(m.sources, st)); del m
    keep = lambda lst: [[round(o[0] + t0, 3)] + list(o[1:]) for o in lst if a <= o[0] + t0 < b]
    # batterie séparée (kick, caisse claire...) puis départs de sons
    from mdxnet_infer import MDX23CInference
    dm = MDX23CInference.from_pretrained('drumsep-6stem', device=dev); r = dm.separate(stems['drums'], sample_rate=44100); drums = {}
    for k in ('kick', 'snare', 'toms', 'hh', 'ride', 'crash'):
        v = np.asarray(r[k]); v = v.mean(axis=1) if v.ndim == 2 and v.shape[1] <= 2 else v.mean(axis=0)
        drums[k] = keep(av2.drum_onsets(v.astype(np.float32), 44100))
    del dm
    mono = y.mean(0); on, *_ = av2.superflux_onsets(mono, 44100); env = av2.envelopes(mono, 44100)
    voc = av2.envelopes(stems['vocals'].mean(0), 44100)['rms']; bas = av2.envelopes(stems['bass'].mean(0), 44100)['rms']; drm = av2.envelopes(stems['drums'].mean(0), 44100)['rms']; oth = av2.envelopes(stems['other'].mean(0), 44100)['rms']
    # temps (beat_this) sur le passage, avec un peu de contexte avant et après
    from beat_this.inference import File2Beats
    tmp = os.path.join(tempfile.gettempdir(), 'animadome_gap.wav'); sf.write(tmp, mono, 44100)
    bt, db = File2Beats(checkpoint_path='final0', device=dev, dbn=False)(tmp); os.remove(tmp)
    return {'t0': t0, 'onsets': keep(on), 'env': env, 'stems': {'vocals': voc, 'bass': bas, 'drums': drm, 'other': oth}, 'drums': drums,
            'beats': [round(float(x) + t0, 3) for x in bt if a <= x + t0 < b], 'downbeats': [round(float(x) + t0, 3) for x in db if a <= x + t0 < b]}

def main():
    mix = os.path.abspath(sys.argv[1]); ap = os.path.join(mix, 'analysis2.js'); head, A = read_js(ap)
    audio = os.path.join(mix, json.load(open(os.path.join(mix, 'mix.json'), encoding='utf-8-sig'))['audio'].replace('/', os.sep))
    gaps = find_gaps(A, audio)
    print('trous détectés : %d (%.0f s au total)' % (len(gaps), sum(b - a for a, b in gaps)))
    for a, b in gaps: print('  %s -> %s (%.0f s)' % (mmss(a), mmss(b), b - a))
    if '--list' in sys.argv or not gaps: return
    ing = lambda t: any(a <= t < b for a, b in gaps)
    n = int(A['dur'] * FPS) + 1; tr = {'name': GAPTRACK, 'file': '(mix complet, passages absents des pistes fournies)', 'dur': A['dur'], 'peakDb': 0, 'onsets': [],
                                         'env': {'fps': FPS, 'rms': [-120.0] * n, 'cen': [0] * n, 'lo': [-120.0] * n, 'hi': [-120.0] * n}}
    A['tracks'] = [t for t in A['tracks'] if t['name'] != GAPTRACK]
    for k in A['drums']: A['drums'][k] = [o for o in A['drums'][k] if not ing(o[0])]
    A['beats'] = [x for x in A['beats'] if not ing(x)]; A['downbeats'] = [x for x in A['downbeats'] if not ing(x)]
    stem_env = {k: {} for k in ('vocals', 'bass', 'drums', 'other')}
    for a, b in gaps:
        print('analyse du mix', mmss(a), '->', mmss(b), flush=True); g = analyse_gap(audio, a, b)
        tr['onsets'] += g['onsets']; off = int(round(g['t0'] * FPS))
        for key in ('rms', 'cen', 'lo', 'hi'):
            src = g['env'][key]
            for i in range(int(a * FPS), min(n, int(b * FPS))):
                j = i - off
                if 0 <= j < len(src): tr['env'][key][i] = src[j]
        for k, v in g['stems'].items():
            for i in range(int(a * FPS), min(n, int(b * FPS))):
                j = i - off
                if 0 <= j < len(v): stem_env[k][i] = v[j]
        for k in A['drums']: A['drums'][k] = sorted(A['drums'][k] + g['drums'].get(k, []), key=lambda o: o[0])
        A['beats'] = sorted(A['beats'] + g['beats']); A['downbeats'] = sorted(A['downbeats'] + g['downbeats'])
        print('   %d départs, %d kicks, %d temps, %d premiers temps' % (len(g['onsets']), len(g['drums']['kick']), len(g['beats']), len(g['downbeats'])))
    A['tracks'].append(tr); A['gaps'] = gaps
    # enveloppes des stems du mix dans les trous (voix, basse, batterie, autres), à 25 images/s : { "indice": dB }
    A['gapStems'] = {k: {'fps': FPS, 'v': {str(i): x for i, x in sorted(v.items())}} for k, v in stem_env.items()}
    open(ap, 'w', encoding='utf-8').write(head + json.dumps(A, separators=(',', ':')) + ';\n'); print('analysis2.js complété')
    # beats.js / stems.js : kicks et frappes des trous, forces recalées par rang sur l'échelle déjà utilisée par la page
    allk = np.sort(np.array([o[1] for o in A['drums']['kick']] or [0.5])); hits_src = A['drums']['snare'] + A['drums']['hh'] + A['drums']['crash']; allh = np.sort(np.array([o[1] for o in hits_src] or [0.5]))
    def merge(lst, gap):
        out = []
        for t, s, *_ in sorted(lst):
            if out and t - out[-1][0] < gap:
                if s > out[-1][1]: out[-1] = [t, s]
            else: out.append([t, s])
        return out
    newk = merge([o for o in A['drums']['kick'] if ing(o[0])], 0.12); newh = [h for h in merge([o for o in hits_src if ing(o[0])], 0.06) if h[1] >= 0.35]
    for fn in ('beats.js', 'stems.js'):
        p = os.path.join(mix, fn)
        if not os.path.exists(p): continue
        hd, o = read_js(p)
        for key, skey, new, ref in (('kick', 'kickS', newk, allk), ('hit', 'hitS', newh, allh)):
            old = [(t, s) for t, s in zip(o.get(key, []), o.get(skey, [])) if not ing(t)]; scale = np.sort(np.array([s for _, s in old] or [1.0])); isint = all(float(s).is_integer() for s in scale[:50])
            add = []; ref = np.sort(np.array([s for _, s in new] or [0.5]))   # rang parmi les frappes des trous eux-mêmes : la plus forte du passage atteint le haut de l'échelle
            for t, s in new:
                q = (np.searchsorted(ref, s, 'left') + np.searchsorted(ref, s, 'right')) / 2 / max(len(ref), 1); q = 0.5 + 0.5 * q; v = scale[min(len(scale) - 1, int(q * len(scale)))]; add.append((round(t, 3), int(round(v)) if isint else round(float(v), 1)))
            both = sorted(old + add); o[key] = [t for t, _ in both]; o[skey] = [s for _, s in both]
        if fn == 'stems.js':
            o['beats'] = A['beats']; o['downbeats'] = A['downbeats']
            for k, v in stem_env.items():   # enveloppes voix / basse / batterie / autres : complétées dans les trous si la page les lit (pas de 0,1 s)
                if k in o and isinstance(o[k], dict) and 'v' in o[k]:
                    hop = o[k].get('hop', 0.1); arr = o[k]['v']
                    for i in range(len(arr)):
                        t = i * hop
                        if ing(t):
                            seg = [v.get(j) for j in range(int(t * FPS), int((t + hop) * FPS) + 1)]; seg = [x for x in seg if x is not None]
                            if seg: arr[i] = round(max(arr[i], max(seg)), 1) if isinstance(arr[i], (int, float)) else arr[i]
        open(p, 'w', encoding='utf-8').write(hd + json.dumps(o, separators=(',', ':')) + ';\n'); print(fn, 'complété')
    print('TERMINE')

if __name__ == '__main__': main()

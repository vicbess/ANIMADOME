# Analyse v2 (en essai, en parallèle des anciens outils) : pistes séparées, 44,1 kHz, pas ~6 ms.
#   python analyze-v2.py <dossier_mix> [--work <dossier_temporaire>] [--only etape,...]
# Étapes : features (superflux + enveloppes par piste ; sans pistes séparées, l'audio à lire est la seule piste), demucs (htdemucs_ft : 4 stems de la piste musique = celle dont le nom contient « music », sinon la plus forte),
#          drums (séparation kick/snare/toms/hh/ride/crash), beats (beat_this), context (nouveautés + bilan par phase), pack.
# Sorties : <mix>/analysis2.js (window.ANALYSIS2) et <mix>/analysis2.report.md (bilan par phase pour relire avec le descriptif).
import sys, os, json, time, subprocess, shutil, glob
import numpy as np, soundfile as sf, librosa

SR = 44100; HOP = 256; HOPS = HOP / SR; FPS = 25
def log(*a): print(time.strftime('[%H:%M:%S]'), *a, flush=True)

def load_mono(path):
    out = []
    with sf.SoundFile(path) as f:
        sr = f.samplerate
        for b in f.blocks(blocksize=sr * 60, dtype='float32', always_2d=True): out.append(b.mean(axis=1))
    y = np.concatenate(out); return y, sr

def superflux_onsets(y, sr, gate_rel=0.12):
    """Départs de sons : spectre mel 138 bandes, flux avec filtre max (superflux), pic adaptatif. Découpé par morceaux pour la mémoire."""
    if sr != SR: y = librosa.resample(y, orig_sr=sr, target_sr=SR)
    n = len(y); chunk = SR * 180; marg = SR * 2; envs = []; mels = []
    pos = 0
    while pos < n:
        a = max(0, pos - marg); b = min(n, pos + chunk + marg)
        S = librosa.feature.melspectrogram(y=y[a:b], sr=SR, n_fft=2048, hop_length=HOP, n_mels=138, fmin=27.5, fmax=16000, power=2.0, center=True)
        D = librosa.power_to_db(S, ref=1.0, amin=1e-10, top_db=None).astype(np.float32)
        e = librosa.onset.onset_strength(S=D, sr=SR, hop_length=HOP, lag=2, max_size=3).astype(np.float32)
        f0 = (pos - a) // HOP; f1 = f0 + min(chunk, n - pos) // HOP + (1 if pos + chunk < n else 0)
        envs.append(e[f0:f1]); mels.append(D[:, f0:f1]); pos += chunk
    env = np.concatenate(envs); mel = np.concatenate(mels, axis=1)
    # normalisation locale (95e centile glissant sur ~20 s) pour comparer les pistes calmes et fortes
    w = int(20 / HOPS); k = max(1, w // 8); idx = np.arange(0, len(env), k)
    loc = np.array([np.percentile(env[max(0, i - w // 2):i + w // 2 + 1], 95) for i in idx]) + 1e-3
    loc = np.interp(np.arange(len(env)), idx, loc); envn = env / np.maximum(loc, 0.8 * np.median(loc))
    pk = librosa.util.peak_pick(envn, pre_max=int(0.03 / HOPS), post_max=int(0.03 / HOPS), pre_avg=int(0.10 / HOPS), post_avg=int(0.10 / HOPS), delta=0.12, wait=int(0.045 / HOPS))
    freqs = librosa.mel_frequencies(n_mels=138, fmin=27.5, fmax=16000)
    lin = librosa.db_to_power(mel)
    on = []
    gate = gate_rel * np.percentile(env, 99.5)   # plancher absolu : ignore le bruit de fond des pistes presque silencieuses
    pk = [p for p in pk if env[p] >= gate]
    for p in pk:
        s = float(min(envn[p], 2.0)) / 2.0
        col = lin[:, min(p + 1, lin.shape[1] - 1)]; cen = float((col * freqs).sum() / (col.sum() + 1e-12))
        on.append([round(p * HOPS, 3), round(s, 2), int(cen)])
    return on, env, mel, freqs

def envelopes(y, sr):
    """rms (dB), centroïde (Hz), énergie graves (<200 Hz, dB) et aigus (>4 kHz, dB) à FPS images/s."""
    if sr != 22050: y = librosa.resample(y, orig_sr=sr, target_sr=22050)
    hop = 22050 // FPS; n = len(y) // hop
    rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=hop, center=True)[0][:n]
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=hop)) ** 2; S = S[:, :n]
    fr = librosa.fft_frequencies(sr=22050, n_fft=2048); tot = S.sum(0) + 1e-12
    cen = (S * fr[:, None]).sum(0) / tot
    lo = 10 * np.log10(S[fr < 200].sum(0) + 1e-12); hi = 10 * np.log10(S[fr > 4000].sum(0) + 1e-12)
    db = lambda a: np.round(20 * np.log10(a + 1e-6), 1)
    return {'fps': FPS, 'rms': db(rms).tolist(), 'cen': np.round(cen).astype(int).tolist(), 'lo': np.round(lo, 1).tolist(), 'hi': np.round(hi, 1).tolist()}

def stage_features(mix, work):
    files = [f for f in sorted(glob.glob(os.path.join(mix, 'tracks', '*.*'))) if not f.endswith('.part')]
    if not files:   # pas de pistes séparées : l'audio à lire est la seule piste (et la piste musique)
        a = json.load(open(os.path.join(mix, 'mix.json'), encoding='utf-8-sig')).get('audio', ''); files = [os.path.join(mix, a.replace('/', os.sep))]
    cache = os.path.join(work, 'features.json')
    if os.path.exists(cache): log('features : cache'); return json.load(open(cache))
    res = {'tracks': []}
    for f in files:
        nm = os.path.splitext(os.path.basename(f))[0]; log('piste', nm); y, sr = load_mono(f); dur = len(y) / sr
        on, env, mel, fr = superflux_onsets(y, sr); log('  ', len(on), 'départs'); en = envelopes(y, sr)
        peak = float(20 * np.log10(np.abs(y).max() + 1e-9))
        res['tracks'].append({'name': nm, 'file': os.path.basename(f), 'path': f, 'dur': round(dur, 2), 'peakDb': round(peak, 1), 'onsets': on, 'env': en,
                              'novfeat': None})
        # caractéristiques pour la nouveauté (0,5 s) : log-mel 64 bandes
        y22 = librosa.resample(y, orig_sr=sr, target_sr=22050) if sr != 22050 else y
        M = librosa.power_to_db(librosa.feature.melspectrogram(y=y22, sr=22050, n_fft=4096, hop_length=11025, n_mels=64, fmax=11000), top_db=80)
        np.save(os.path.join(work, 'nov_' + nm + '.npy'), M.astype(np.float32)); del y, y22, mel, env
    json.dump(res, open(cache, 'w')); return res

def stage_demucs(mix, work, music):
    out = os.path.join(work, 'demucs'); d = glob.glob(os.path.join(out, '**', 'drums.wav'), recursive=True)
    if d: log('demucs : cache'); return d[0]
    log('demucs htdemucs_ft (stems) sur', os.path.basename(music), '- étape longue')
    r = subprocess.run([sys.executable, '-X', 'utf8', '-m', 'demucs', '-n', 'htdemucs_ft', '--float32', '-o', out, music])
    d = glob.glob(os.path.join(out, '**', 'drums.wav'), recursive=True)
    if r.returncode != 0 or not d: raise SystemExit('demucs en échec')
    return d[0]

def drum_onsets(y, sr, freqs_min=0):
    # y : un instrument de batterie séparé (mono) → départs de sons
    on, env, mel, fr = superflux_onsets(y, sr, gate_rel=0.30); return on

def stage_drums(work, drums_path):
    cache = os.path.join(work, 'drums.json')
    if os.path.exists(cache): log('drums : cache'); return json.load(open(cache))
    from mdxnet_infer import MDX23CInference
    m = MDX23CInference.from_pretrained('drumsep-6stem', device='cuda'); names = ['kick', 'snare', 'toms', 'hh', 'ride', 'crash']
    acc = {k: [] for k in names}; envd = {k: [] for k in names}
    with sf.SoundFile(drums_path) as f:
        sr = f.samplerate; total = f.frames; step = sr * 300; pos = 0
        while pos < total:
            f.seek(pos); y = f.read(min(step, total - pos), dtype='float32', always_2d=True); log('drumsep', round(pos / sr), 's /', round(total / sr))
            r = m.separate(y.T, sample_rate=sr)
            for k in names:
                v = np.asarray(r[k]); v = v.mean(axis=1) if v.ndim == 2 and v.shape[1] <= 2 else v.mean(axis=0)
                acc[k].append(v.astype(np.float32))
            pos += step
    out = {}
    for k in names:
        y = np.concatenate(acc[k]); on = drum_onsets(y, sr); out[k] = on; log(k, len(on), 'départs'); del y
    json.dump(out, open(cache, 'w')); return out

def stage_beats(music, work):
    cache = os.path.join(work, 'beats.json')
    if os.path.exists(cache): log('beats : cache'); return json.load(open(cache))
    from beat_this.inference import File2Beats
    f = File2Beats(checkpoint_path='final0', device='cuda', dbn=False); log('beat_this sur', os.path.basename(music))
    b, d = f(music); out = {'beats': [round(float(x), 3) for x in b], 'downbeats': [round(float(x), 3) for x in d]}
    json.dump(out, open(cache, 'w')); log(len(b), 'temps,', len(d), 'premiers temps'); return out

def novelty(M, kern=16):
    X = M - M.mean(axis=1, keepdims=True); X = X / (np.linalg.norm(X, axis=0, keepdims=True) + 1e-9)
    S = X.T @ X; n = S.shape[0]; g = np.exp(-(np.arange(-kern, kern) + 0.5) ** 2 / (2 * (kern / 2) ** 2)); G = np.outer(g, g)
    sign = np.sign(np.outer(np.arange(-kern, kern) + 0.5, np.arange(-kern, kern) + 0.5)); K = G * sign
    nv = np.zeros(n); P = np.pad(S, kern, mode='edge')
    for i in range(n): nv[i] = (P[i:i + 2 * kern, i:i + 2 * kern] * K).sum()
    nv = np.maximum(nv, 0); return nv / (np.percentile(nv, 99) + 1e-9)

def stage_context(mix, work, feats, drums, beats):
    from scipy.signal import find_peaks
    nov = {}
    for t in feats['tracks']:
        M = np.load(os.path.join(work, 'nov_' + t['name'] + '.npy')); nv = novelty(M)
        pk, pr = find_peaks(nv, height=0.25, distance=6, prominence=0.15)
        nov[t['name']] = {'hop': 0.5, 'v': np.round(nv, 2).tolist(), 'peaks': [[round(p * 0.5, 1), round(float(nv[p]), 2)] for p in pk]}
    # tempo local à partir des temps
    b = np.array(beats['beats']); tempo = []
    if len(b) > 8:
        for t0 in np.arange(0, feats['tracks'][0]['dur'], 10):
            s = b[(b >= t0) & (b < t0 + 10)]
            if len(s) >= 3: iv = np.diff(s); tempo.append([float(t0), round(60 / np.median(iv), 1), round(float(iv.std() / iv.mean()), 2)])
    return nov, tempo

def phase_report(mix, feats, drums, beats, nov, tempo):
    dj = json.load(open(os.path.join(mix, 'descriptif.json'), encoding='utf-8-sig')); ph = dj['phases']; L = []
    L.append('# Bilan de l\'analyse v2 par phase\n')
    prev = None; tr = feats['tracks']
    def mm(t): return '%d:%02d' % (int(t) // 60, int(t) % 60)
    for i, p in enumerate(ph):
        a, b = p['start'], p['end']; d = max(b - a, 1e-6); L.append('## Phase %d [%s => %s] %s' % (i + 1, mm(a), mm(b), p['title']))
        if p.get('audio'): L.append('Descriptif son : ' + p['audio'].replace('\n', ' '))
        row = []
        for t in tr:
            n = len([o for o in t['onsets'] if a <= o[0] < b]); st = [o[1] for o in t['onsets'] if a <= o[0] < b]
            e = t['env']; r = np.array(e['rms'][int(a * FPS):int(b * FPS)]) if len(e['rms']) else np.array([-90.0])
            c = np.array(e['cen'][int(a * FPS):int(b * FPS)]); lo = np.array(e['lo'][int(a * FPS):int(b * FPS)]); hi = np.array(e['hi'][int(a * FPS):int(b * FPS)])
            if r.size == 0: r = np.array([-90.0]); c = np.array([0]); lo = hi = r
            h = len(r) // 2; slope = (r[h:].mean() - r[:max(h, 1)].mean()) if h > 2 else 0
            dens = '%.2f/s' % (n / d); row.append('- %s : %s départs, force méd. %.2f, niveau moy. %.0f dB (max %.0f), centroïde %d Hz, graves-aigus %.0f/%.0f dB, évolution %+0.1f dB' % (t['name'][:22], dens, np.median(st) if st else 0, r.mean(), r.max(), c.mean(), lo.mean(), hi.mean(), slope))
        L += row
        dr = ', '.join('%s %.2f/s' % (k, len([o for o in v if a <= o[0] < b]) / d) for k, v in drums.items()); L.append('- batterie séparée : ' + dr)
        bb = [x for x in beats['beats'] if a <= x < b]; dd = [x for x in beats['downbeats'] if a <= x < b]
        if len(bb) > 3: iv = np.diff(bb); L.append('- temps : %d (tempo médian %.0f bpm, irrégularité %.2f), %d premiers temps' % (len(bb), 60 / np.median(iv), iv.std() / iv.mean(), len(dd)))
        else: L.append('- temps : aucun repère régulier')
        pk = []
        for nm, v in nov.items(): pk += [(t, s, nm) for t, s in v['peaks'] if a - 3 <= t <= b + 3]
        pk.sort(key=lambda x: -x[1]); L.append('- ruptures sonores proches : ' + ('; '.join('%s (%.1f, %s)' % (mm(t) + '.%d' % int((t % 1) * 10), s, nm[:10]) for t, s, nm in pk[:5]) or 'aucune'))
        L.append('')
    open(os.path.join(mix, 'analysis2.report.md'), 'w', encoding='utf-8').write('\n'.join(L)); log('bilan écrit')

def main():
    mix = os.path.abspath(sys.argv[1]); work = os.path.join(os.environ.get('TEMP', '.'), 'animadome_v2_' + os.path.basename(mix))
    if '--work' in sys.argv: work = sys.argv[sys.argv.index('--work') + 1]
    os.makedirs(work, exist_ok=True); log('mix', mix, '| travail', work)
    feats = stage_features(mix, work)
    music = [t for t in feats['tracks'] if 'music' in t['name'].lower()] or [max(feats['tracks'], key=lambda t: t['peakDb'])]
    mf = music[0]['path']
    dp = stage_demucs(mix, work, mf); drums = stage_drums(work, dp); beats = stage_beats(mf, work)
    nov, tempo = stage_context(mix, work, feats, drums, beats)
    for t in feats['tracks']: t.pop('novfeat', None); t.pop('path', None)
    out = {'sr': SR, 'hop': round(HOPS, 5), 'dur': feats['tracks'][0]['dur'], 'tracks': feats['tracks'], 'drums': drums, 'beats': beats['beats'], 'downbeats': beats['downbeats'], 'tempo': tempo, 'novelty': nov}
    open(os.path.join(mix, 'analysis2.js'), 'w', encoding='utf-8').write('window.ANALYSIS2=' + json.dumps(out, separators=(',', ':')) + ';\n'); log('analysis2.js écrit')
    if os.path.exists(os.path.join(mix, 'descriptif.json')): phase_report(mix, feats, drums, beats, nov, tempo)
    log('STEMS_DIR=' + os.path.dirname(dp)); log('TERMINE')

if __name__ == '__main__': main()

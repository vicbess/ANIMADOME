# Fiche rythmique d'une phase : un résumé court (sections, tempo, coups forts, voix, montées, trous d'export) à lire AVANT de concevoir
# l'animation, à la place de l'analyse brute. Écrit <mix>/briefs/phase-NN.md et l'affiche.
#   python phase-brief.py <dossier_mix> <numéro de phase | mm:ss>      (ex. : phase-brief.py mixes/pyrobeats 11)
import sys, os, re, json
import numpy as np

def rd(path):
    s = open(path, encoding='utf-8').read(); body = s[s.index('=') + 1:].strip().rstrip(';')
    try: return json.loads(body)
    except Exception: return json.loads(re.sub(r'([{,])([A-Za-z_][A-Za-z0-9_]*):', r'\1"\2":', body))
def mm(t): return '%d:%04.1f' % (int(t) // 60, t % 60)
def mms(t): return '%d:%02d' % (int(t) // 60, int(t) % 60)

def main():
    mix = os.path.abspath(sys.argv[1]); arg = sys.argv[2]
    dj = json.load(open(os.path.join(mix, 'descriptif.json'), encoding='utf-8-sig')); ph = dj['phases']
    if ':' in arg: m_, s_ = arg.split(':'); t = int(m_) * 60 + float(s_); idx = next(i for i, p in enumerate(ph) if p['start'] <= t < p['end'])
    else: idx = int(arg) - 1
    p = ph[idx]; a, b = float(p['start']), float(p['end'])
    A = rd(os.path.join(mix, 'analysis2.js')); S = rd(os.path.join(mix, 'stems.js')) if os.path.exists(os.path.join(mix, 'stems.js')) else {}
    L = ['# Fiche rythmique — phase %d [%s → %s] %s' % (idx + 1, mms(a), mms(b), p.get('title', '')), '']
    if p.get('text'): L += ['**Intention :** ' + ' '.join(str(p['text']).split())[:400], '']
    if p.get('audio'): L += ['**Son (descriptif) :** ' + ' '.join(str(p['audio']).split())[:300], '']
    env = lambda k: np.array(S[k]['v'], float) if k in S and isinstance(S[k], dict) else None
    hop = 0.1; dr, ba, vo = env('drums'), env('bass'), env('vocals')
    seg = lambda arr, t0, t1: float(np.mean(arr[int(t0 / hop):max(int(t0 / hop) + 1, int(t1 / hop))])) if arr is not None else -120.0
    kicks = np.array([o[0] for o in A['drums'].get('kick', [])]); snares = np.array([o[0] for o in A['drums'].get('snare', [])])
    cnt = lambda arr, t0, t1: int(((arr >= t0) & (arr < t1)).sum())
    # --- sections (fenêtres de 4 s, fusionnées par nature)
    W = 4.0; cls = []
    for t0 in np.arange(a, b, W):
        t1 = min(b, t0 + W); d, bs, k = seg(dr, t0, t1), seg(ba, t0, t1), cnt(kicks, t0, t1) + cnt(snares, t0, t1)
        c = 'rythme plein' if (k >= 4 and bs > -35) else 'batterie sans basse' if k >= 4 else 'batterie légère' if k >= 1 and d > -45 else 'calme'
        cls.append([c, float(t0), float(t1)])
    for _ in range(3):   # une section dure au moins 8 s : les plus courtes rejoignent leur voisine
        out = []
        for c in cls:
            if out and out[-1][0] == c[0]: out[-1][2] = c[2]
            else: out.append(list(c))
        for i, c in enumerate(out):
            if c[2] - c[1] < 8 and len(out) > 1: c[0] = out[i - 1][0] if i > 0 else out[i + 1][0]
        cls = out
    out = []
    for c in cls:
        if out and out[-1][0] == c[0]: out[-1][2] = c[2]
        else: out.append(list(c))
    L += ['## Sections', '| De | À | Nature | Batterie | Basse | Voix | Kicks+caisses/s |', '|---|---|---|---|---|---|---|']
    for c, t0, t1 in out:
        L.append('| %s | %s | %s | %.0f dB | %.0f dB | %.0f dB | %.1f |' % (mms(t0), mms(t1), c, seg(dr, t0, t1), seg(ba, t0, t1), seg(vo, t0, t1), (cnt(kicks, t0, t1) + cnt(snares, t0, t1)) / max(1e-6, t1 - t0)))
    # --- tempo et premiers temps
    B = np.array(A['beats']); D = np.array(A['downbeats']); bb = B[(B >= a) & (B < b)]; dd = D[(D >= a) & (D < b)]
    L += ['', '## Tempo']
    if len(bb) > 4:
        iv = np.diff(bb); iv = iv[iv < 2]; L.append('- %d temps, tempo médian **%.0f bpm** (un temps = %.3f s)%s' % (len(bb), 60 / np.median(iv), np.median(iv), ' ; premier temps toutes les **%.2f s**' % np.median(np.diff(dd)[np.diff(dd) < 6]) if len(dd) > 3 else ''))
        L.append('- Premiers temps aux frontières de sections : ' + ', '.join('%s → %s' % (mms(t0), mm(float(dd[np.argmin(abs(dd - t0))]))) for _, t0, _ in out[1:] if len(dd)))
    else: L.append('- Aucun repère régulier (pas de temps détectés).')
    # --- coups forts (kick, caisse claire, cymbale réunis ; au moins 3 s d'écart)
    hits = sorted([(o[0], o[1], k) for k in ('kick', 'snare', 'crash') for o in A['drums'].get(k, []) if a <= o[0] < b and o[1] >= 0.95])
    grp = []
    for t, s, k in hits:
        if grp and t - grp[-1][-1][0] < 0.06: grp[-1].append((t, s, k))
        else: grp.append([(t, s, k)])
    strong = [g for g in grp if len({k for _, _, k in g}) >= 2]; sel = []
    for g in strong:
        if not sel or g[0][0] - sel[-1][0][0] >= 3: sel.append(g)
    L += ['', '## Coups forts (au moins deux instruments ensemble)', ', '.join('%s (%s)' % (mm(g[0][0]), '+'.join(sorted({k for _, _, k in g}))) for g in sel[:40]) or 'aucun']
    # --- roulements / montées : au moins 4 kicks à moins de 0,45 s d'intervalle
    kk = kicks[(kicks >= a) & (kicks < b)]; rolls = []; i = 0
    while i < len(kk) - 1:
        j = i
        while j + 1 < len(kk) and kk[j + 1] - kk[j] < 0.45: j += 1
        if j - i >= 3: rolls.append((kk[i], kk[j], j - i + 1))
        i = j + 1
    L += ['', '## Roulements de kicks (montées probables)', ', '.join('%s → %s (%d kicks)' % (mm(x), mm(y), n) for x, y, n in rolls) or 'aucun']
    # --- voix
    L += ['', '## Voix']
    if vo is not None:
        v = vo[int(a / hop):int(b / hop)]; thr = max(-32.0, float(np.percentile(vo, 70))); on = v > thr; segs = []; i = 0
        while i < len(on):
            if on[i]:
                j = i
                while j < len(on) and (on[j] or (j + 15 < len(on) and on[j:j + 15].any())): j += 1
                if (j - i) * hop >= 4: segs.append((a + i * hop, a + j * hop))
                i = j
            else: i += 1
        L.append(', '.join('%s → %s' % (mms(x), mms(y)) for x, y in segs) or 'pas de passage de voix marqué')
    else: L.append('enveloppe de voix absente (stems.js)')
    # --- trous d'export et events déjà posés par l'auteur
    gaps = [(max(a, g0), min(b, g1)) for g0, g1 in A.get('gaps', []) if g1 > a and g0 < b]
    L += ['', '## Trous d\'export', (', '.join('%s → %s' % (mm(x), mm(y)) for x, y in gaps) + ' — analysés sur le mix complet (fill-gaps.py)') if gaps else ('aucun' if 'gaps' in A else 'non vérifié : lancer tools/fill-gaps.py --list')]
    ev = [e for e in dj.get('events', []) if a <= e['t'] < b]
    L += ['', '## Events écrits dans le descriptif', ', '.join('%s %s' % (mms(e['t']), str(e.get('text', '')).split(':')[0][:24]) for e in ev) or 'aucun', '']
    txt = '\n'.join(L); od = os.path.join(mix, 'briefs'); os.makedirs(od, exist_ok=True); fn = os.path.join(od, 'phase-%02d.md' % (idx + 1)); open(fn, 'w', encoding='utf-8').write(txt); print(txt); print('→', fn)

if __name__ == '__main__': main()

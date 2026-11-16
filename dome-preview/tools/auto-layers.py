# Passe automatique des couches d'animation : propose des VARIATIONS chaînées aux effets de base (Anim 2D layer) et quelques events,
# d'après l'analyse v2 du mix (analysis2.js : départs de sons par piste, batterie séparée, temps beat_this).
#   python auto-layers.py <dossier_mix> [--no-events]
# Écrit <mix>/layers.js (window.LAYERS). Pour ANNULER la passe : supprimer ce fichier (ou le renommer) ; rien d'autre n'est modifié :
# fxmap.js, descriptif et events-timing.json restent intacts, les events ajoutés ne sont jamais enregistrés dans events-timing.json.
import sys, os, re, json
import numpy as np

FPS = 25
DETAILS = {'Étincelles', 'Comètes', 'Éclairs', 'Halo violet', 'Trou de lave', 'Collision lave-eau', 'Jaillissement de lave', 'Battement', 'Terre violette', 'Noir', 'Fade'}
MAIN_ORDER = ['Pulsation audio', 'Tunnels de lave', 'Coulées', 'Tourbillon', 'Flammes', 'Failles', 'Vagues', 'Braises']
SPEED_FX = {'Pulsation audio', 'Tourbillon', 'Flammes'}    # effets qui lisent « speed » / le temps accéléré
PAL_FX = {'Pulsation audio'}
LADDER = ['ember', 'lava', 'fire']

def mmss(t): return '%d:%02d' % (int(t) // 60, int(t) % 60)
def sec(k): m, s = k.split(':'); return int(m) * 60 + int(s)

def load_analysis(mix):
    a = open(os.path.join(mix, 'analysis2.js'), encoding='utf-8').read(); return json.loads(a[a.index('=') + 1:].strip().rstrip(';'))

def parse_fxmap(mix):
    """phases du mix : { début(s): [ {n, pal} ] } et temps des events par défaut."""
    s = open(os.path.join(mix, 'fxmap.js'), encoding='utf-8-sig').read()
    def block(src, start):
        d = 0; i = start; q = None
        while i < len(src):
            c = src[i]
            if q:
                if c == '\\': i += 1
                elif c == q: q = None
            elif c in '\'"': q = c
            elif c == '{': d += 1
            elif c == '}':
                d -= 1
                if d == 0: return src[start:i + 1]
            i += 1
        return ''
    ph = {}
    m = re.search(r'phases\s*:\s*\{', s)
    if m:
        body = block(s, m.end() - 1)
        for km in re.finditer(r'"(\d{2}:\d{2})"\s*:\s*\{', body):
            ob = block(body, km.end() - 1); fxs = []
            fm = re.search(r'fx\s*:\s*\[', ob)
            if fm:
                j = fm.end(); depth = 0; k = j
                while k < len(ob):
                    if ob[k] == '{':
                        it = block(ob, k); n = re.search(r"n\s*:\s*'([^']+)'", it); p = re.search(r"\bpal\s*:\s*'([^']+)'", it); ly = re.search(r"\blayer\s*:\s*'(\w+)'", it)
                        if n: fxs.append({'n': n.group(1), 'pal': p.group(1) if p else None, 'layer': ly.group(1) if ly else 'base'})
                        k += len(it); continue
                    if ob[k] == ']': break
                    k += 1
            ph[sec(km.group(1))] = fxs
    ev = []
    m = re.search(r'events\s*:\s*\{', s)
    if m:
        body = block(s, m.end() - 1)
        for km in re.finditer(r'"(\d{2}:\d{2})"\s*:\s*\{', body): ev.append(sec(km.group(1)))
    return ph, ev

def user_event_times(mix, default_keys):
    t = list(map(float, default_keys)); p = os.path.join(mix, 'events-timing.json')
    if os.path.exists(p):
        try:
            o = json.load(open(p, encoding='utf-8-sig'))
            for k, v in o.items():
                if isinstance(v, (int, float)) and not k.startswith('__'): t.append(float(v))
            for d in o.get('__dups', []): t.append(float(d['on']))
        except Exception: pass
    return np.array(sorted(t))

def smooth(x, n):
    if n <= 1: return x
    k = np.ones(n) / n; return np.convolve(np.pad(x, (n // 2, n - 1 - n // 2), mode='edge'), k, mode='valid')

def rdp(pts, eps):
    if len(pts) < 3: return pts
    a, b = np.array(pts[0]), np.array(pts[-1]); best, bi = 0, 0
    for i in range(1, len(pts) - 1):
        # écart vertical à la droite a-b
        t = (pts[i][0] - a[0]) / (b[0] - a[0] + 1e-9); d = abs(pts[i][1] - (a[1] + t * (b[1] - a[1])))
        if d > best: best, bi = d, i
    if best <= eps: return [pts[0], pts[-1]]
    return rdp(pts[:bi + 1], eps)[:-1] + rdp(pts[bi:], eps)

def main():
    mix = os.path.abspath(sys.argv[1]); want_ev = '--no-events' not in sys.argv
    A = load_analysis(mix); dur = A['dur']; n = int(dur * FPS) + 2
    byname = {t['name'].lower(): t for t in A['tracks']}
    def tr(key): return next((v for k, v in byname.items() if key in k), None)
    music = tr('music') or A['tracks'][0]; bruit = tr('bruit'); echo = tr('echo')
    def pw(t, key='rms'):
        if t is None: return np.zeros(n)
        a = np.array(t['env'][key][:n], float); a = np.pad(a, (0, max(0, n - len(a))), constant_values=-120); return 10 ** (a / 10)
    P = sum(pw(t) for t in A['tracks'])   # toutes les pistes, y compris la piste MIX_TROUS ajoutée par fill-gaps.py (passages absents des pistes fournies)
    Edb = 10 * np.log10(P + 1e-12); E = smooth(Edb, 3 * FPS)
    # l'échelle d'énergie (5e et 98e centiles) reste celle des pistes fournies seules : combler un trou ne change donc rien aux autres phases
    E0 = smooth(10 * np.log10(sum(pw(t) for t in A['tracks'] if t['name'] != 'MIX_TROUS') + 1e-12), 3 * FPS)
    lo, hi = np.percentile(E0, 5), np.percentile(E0, 98); E01 = np.clip((E - lo) / (hi - lo + 1e-9), 0, 1)
    E01s = np.clip((smooth(Edb, 7 * FPS) - lo) / (hi - lo + 1e-9), 0, 1)   # version lente pour les variations d'intensité (les montées, pas chaque coup de batterie)
    # densité des frappes de batterie (kick + caisse claire) sur 6 s
    dr = np.zeros(n)
    for k in ('kick', 'snare'):
        for t, s, *_ in A['drums'].get(k, []):
            i = int(t * FPS)
            if 0 <= i < n: dr[i] += 1
    D = smooth(dr, 6 * FPS) * FPS
    # régularité des kicks : part des kicks tombant sur un temps beat_this (fenêtre 6 s) ; 0 si moins de 4 kicks
    beats = np.array(A['beats']); kk = np.array([t for t, *_ in A['drums'].get('kick', [])])
    ok = np.zeros(n); cnt = np.zeros(n)
    if len(beats) and len(kk):
        idx = np.clip(np.searchsorted(beats, kk), 1, len(beats) - 1); dd = np.minimum(abs(kk - beats[idx - 1]), abs(kk - beats[idx]))
        for t, d0 in zip(kk, dd):
            i = int(t * FPS)
            if 0 <= i < n: cnt[i] += 1; ok[i] += 1 if d0 < 0.05 else 0
    cs, os_ = smooth(cnt, 6 * FPS) * 6 * FPS, smooth(ok, 6 * FPS) * 6 * FPS
    R = np.where(cs >= 4, os_ / np.maximum(cs, 1), 0.0)
    R = np.clip(R * np.minimum(1, cs / 8), 0, 1)

    ph, def_ev = parse_fxmap(mix); ut = user_event_times(mix, def_ev)
    dj = json.load(open(os.path.join(mix, 'descriptif.json'), encoding='utf-8-sig')); phases = dj['phases']
    mods = []; events = []; basewin = []; mid = 0
    # layers-plan.json (facultatif) : phases réglées à la main d'après l'analyse. { "<début de phase en s>": { "base": [...], "mods": [...], "noAutoEvents": true } }
    # Pour ces phases, les variations et fenêtres automatiques sont remplacées par celles du plan (les numéros des autres variations ne changent pas).
    lp = os.path.join(mix, 'layers-plan.json'); LRAW = json.load(open(lp, encoding='utf-8-sig')) if os.path.exists(lp) else {}; LPLAN = {int(float(k)): v for k, v in LRAW.items() if not k.startswith('_')}
    IDSHIFT = {int(float(k)): int(v) for k, v in LRAW.get('_idShift', {}).items()}   # numéros de variations à sauter après une phase (quand une phase modifiée ne produit plus une variation qu'elle produisait) : les numéros suivants restent ceux d'avant, donc les éléments désactivés à la main (⏻) aussi
    def addmod(p0, on, kind, t0, t1, pts, why):
        nonlocal mid; mid += 1
        if int(p0) in LPLAN: return
        mods.append({'id': 'm%03d' % mid, 'ph': p0, 'on': on, 'kind': kind, 't0': round(t0, 2), 't1': round(t1, 2), 'pts': pts, 'why': why, 'auto': True})
    def curve(sig, a, b, step, fn, eps, mingap):
        ts = np.arange(a, b + 1e-6, step); raw = [[float(t), float(fn(sig[min(n - 1, int(t * FPS))]))] for t in ts]
        pts = rdp(raw, eps); out = [pts[0]]
        for p in pts[1:]:
            if p[0] - out[-1][0] >= mingap or p is pts[-1]: out.append(p)
        return [[round(x, 1), round(v, 2)] for x, v in out]
    for p in phases:
        a, b = float(p['start']), float(p['end']); fx = ph.get(int(a)); mid += IDSHIFT.get(int(a), 0)
        if not fx or b - a < 20: continue
        base = [f for f in fx if f['layer'] != 'mod']; names = [f['n'] for f in base]
        main = next((m for m in MAIN_ORDER if m in names), None) or next((f['n'] for f in base if f['n'] not in DETAILS), None)
        i0, i1 = int(a * FPS), min(n, int(b * FPS)); e = E01s[i0:i1]; d = D[i0:i1]; r = R[i0:i1]
        if len(e) < 10: continue
        # 1) intensité : suit le volume (montées / creux) autour de la valeur médiane de la phase
        if main:
            rg = np.percentile(e, 90) - np.percentile(e, 10); med = np.median(e)
            if rg >= 0.12:
                pts = curve(E01s, a, b, 2.0, lambda x: np.clip(1 + 0.45 * (x - med) / max(rg / 2, 0.2), 0.55, 1.35), 0.07, 4.0)
                if len(pts) >= 3 and max(v for _, v in pts) - min(v for _, v in pts) >= 0.15:
                    tmax = a + np.argmax(e) / FPS; tmin = a + np.argmin(e) / FPS
                    addmod(a, main, 'level', a, b, pts, 'intensité calée sur le volume : creux vers %s, pic vers %s' % (mmss(tmin), mmss(tmax)))
        # 2) accélération : suit la densité de frappes de batterie
        sp = [m for m in names if m in SPEED_FX]
        if sp:
            rgd = np.percentile(d, 90) - np.percentile(d, 10); medd = np.median(d)
            if rgd >= 0.8:
                pts = curve(D, a, b, 2.0, lambda x: np.clip(1 + 0.5 * (x - medd) / max(rgd / 2, 0.5), 0.55, 1.6), 0.07, 3.0)
                if len(pts) >= 3 and max(v for _, v in pts) - min(v for _, v in pts) >= 0.25:
                    addmod(a, sp[0], 'speed', a, b, pts, 'mouvement plus rapide quand la batterie se densifie (jusqu\'à ×%.1f), plus lent quand elle s\'allège' % max(v for _, v in pts))
        # 3) contraste du rythme : la pulsation suit les kicks quand ils sont réguliers, se relâche sinon
        if 'Pulsation audio' in names:
            rgr = np.percentile(r, 90) - np.percentile(r, 10)
            if rgr >= 0.25:
                pts = curve(R, a, b, 2.0, lambda x: 0.35 + 1.0 * x, 0.08, 3.0)
                if len(pts) >= 3: addmod(a, 'Pulsation audio', 'beat', a, b, pts, 'pulsation calée sur les kicks quand ils sont réguliers, plus libre quand le rythme se défait')
        # 4) couleur : un cran plus chaud sur les pics d'énergie soutenus, un cran plus froid sur les creux soutenus (échelle ember < lava < fire)
        pf = next((f for f in base if f['n'] in PAL_FX and f['pal'] in LADDER), None)
        if pf and (np.percentile(e, 90) - np.percentile(e, 10)) >= 0.28:
            lv = LADDER.index(pf['pal']); segs = []
            for lab, cond, delta in (('pic', e > max(0.62, np.percentile(e, 70)), +1), ('creux', e < min(0.38, np.percentile(e, 30)), -1)):
                if not 0 <= lv + delta < len(LADDER): continue
                j = 0
                while j < len(cond):
                    if cond[j]:
                        k = j
                        while k < len(cond) and cond[k]: k += 1
                        if (k - j) / FPS >= 12: segs.append((a + j / FPS, a + k / FPS, delta, lab))
                        j = k
                    else: j += 1
            segs.sort()
            if segs:
                pts = [[round(a, 1), pf['pal']]]; last = pf['pal']; txt = []
                for s0, s1, dl, lab in segs[:3]:
                    new = LADDER[lv + dl]
                    if s0 - pts[-1][0] < 6: continue
                    pts.append([round(s0, 1), new]); pts.append([round(s1, 1), pf['pal']]); txt.append('%s %s–%s' % (lab, mmss(s0), mmss(s1)))
                if len(pts) > 1: addmod(a, pf['n'], 'pal', a, b, pts, 'palette un cran plus chaude / froide selon l\'énergie (' + ', '.join(txt) + ')')
        # 0) effets de base par SECTIONS de même nature : la pulsation rythmique (Pulsation audio) n'apparaît que dans les passages rythmés ;
        #    elle revient à l'identique à chaque passage de même nature, tant qu'un autre effet de base continue d'occuper le dôme entre-temps.
        keep = [f for f in base if f['n'] not in DETAILS and f['n'] != 'Pulsation audio']
        if 'Pulsation audio' in names and b - a >= 40:
            W = 4.0; nb = int((b - a) // W)
            if nb >= 8:
                cls = []
                dmed = np.median(D[i0:i1])
                for k in range(nb):
                    s0, s1 = int((a + k * W) * FPS), int((a + (k + 1) * W) * FPS)
                    rr, dd_, ee = R[s0:s1].mean(), D[s0:s1].mean(), E01s[s0:s1].mean()
                    cls.append('amb' if (rr < 0.25 and dd_ < max(1.2, 0.6 * dmed)) or ee < 0.18 else 'rythme')
                # lissage : une section dure au moins 12 s (3 fenêtres) ; on fusionne les plus courtes dans leur voisine
                for _ in range(3):
                    k = 0
                    while k < nb:
                        j = k
                        while j < nb and cls[j] == cls[k]: j += 1
                        if j - k < 3 and (k > 0 or j < nb):
                            rep = cls[k - 1] if k > 0 else cls[j]
                            for q in range(k, j): cls[q] = rep
                        k = j
                if os.environ.get('AL_DEBUG'): print(mmss(a), ''.join('a' if c == 'amb' else 'R' for c in cls))
                secs = []; k = 0
                while k < nb:
                    j = k
                    while j < nb and cls[j] == cls[k]: j += 1
                    secs.append((cls[k], a + k * W, a + j * W)); k = j
                amb = [s for s in secs if s[0] == 'amb']; ryt = [s for s in secs if s[0] == 'rythme']
                if amb and ryt and sum(s[2] - s[1] for s in amb) >= 12:
                    win = [[round(s[1], 1), round(s[2], 1), 4] for s in ryt]
                    entry_extra = {}
                    if not keep:   # rien d'autre ne tient le dôme dans les passages calmes : des braises discrètes prennent le relais (même effet à chaque passage calme)
                        awin = [[round(s[1], 1), round(s[2], 1), 4] for s in amb]
                        if int(a) not in LPLAN: basewin.append({'ph': a, 'add': {'n': 'Braises', 'mode': 'steady', 'core': True, 'small': True}, 'win': awin, 'why': 'des braises discrètes tiennent le dôme dans les passages calmes (' + ', '.join('%s–%s' % (mmss(w[0]), mmss(w[1])) for w in awin) + '), la pulsation revient dans les passages rythmés'})
                    if int(a) not in LPLAN: basewin.append({'ph': a, 'on': 'Pulsation audio', 'win': win, 'why': 'la pulsation rythmique revient à chaque passage rythmé (' + ', '.join('%s–%s' % (mmss(w[0]), mmss(w[1])) for w in win) + ') et s\'efface dans les passages calmes'})
        # 5) events : seulement dans les phases où l'auteur en a peu posé ; sur les impacts (EvilPenta) et avant (Ruée)
        if want_ev and not LPLAN.get(int(a), {}).get('noAutoEvents'):
            nu = int(((ut >= a) & (ut < b)).sum())
            if nu >= 3: continue
            j0 = int(a * FPS); jmp = []
            for i in range(max(j0, 3 * FPS), min(n - 1, int(b * FPS))):
                if Edb[i + 12] - Edb[i - 3 * FPS:i].mean() >= 7 and Edb[i + 12] > np.percentile(Edb, 60):
                    t = i / FPS
                    if not jmp or t - jmp[-1] > 8: jmp.append(t)
            added = 0
            for t in jmp:
                if added >= 2: break
                if len(ut) and np.min(np.abs(ut - t)) < 5: continue
                if any(abs(x['on'] - t) < 5 for x in events): continue
                events.append({'name': 'EvilPenta', 'on': round(t, 2), 'span': 4.5, 'why': 'flash sur un impact (le volume bondit d\'au moins 7 dB en un instant)'}); added += 1
                i = int(t * FPS); rise = Edb[i - 4 * FPS:i - FPS].mean() - Edb[i - 10 * FPS:i - 7 * FPS].mean()
                if rise >= 3 and t - 3.2 > a and not (len(ut) and np.min(np.abs(ut - (t - 3.2))) < 4) and not any(abs(x['on'] - (t - 3.2)) < 4 for x in events):   # montée avant l'impact : la lave s'emballe juste avant
                    events.append({'name': 'Ruée', 'on': round(t - 3.2, 2), 'span': 2.3, 'why': 'montée de volume (+%.0f dB en 6 s) juste avant un impact : la lave s\'emballe' % rise})
    for p0, v in sorted(LPLAN.items()):
        for k, b_ in enumerate(v.get('base', [])): basewin.append(dict(b_, ph=float(p0)))
        for k, m_ in enumerate(v.get('mods', [])): mods.append(dict(m_, id='p%d_%d' % (p0, k + 1), ph=float(p0), auto=True))
    # events écrits à la main d'après le descriptif et l'analyse (events-plan.json) : ils priment sur les flashs automatiques voisins
    pp = os.path.join(mix, 'events-plan.json')
    if os.path.exists(pp):
        plan = json.load(open(pp, encoding='utf-8-sig'))
        pt = np.array([x['on'] for x in plan]) if plan else np.array([])
        events = [x for x in events if not (len(pt) and np.min(np.abs(pt - x['on'])) < 3.5)]
        for x in plan:
            ev = {'name': x['name'], 'on': float(x['on']), 'span': x.get('span'), 'why': x.get('why', '')}
            if x.get('ov'): ev['ov'] = x['ov']
            if x.get('snap') is False: ev['_nosnap'] = True   # déjà calé à la main sur l'analyse (temps exacts) : ne pas recaler
            events.append(ev)
        events.sort(key=lambda x: x['on'])
    # ---- calage rythmique : début sur un temps fort (premier temps, sinon temps, sinon kick, sinon attaque marquée) ; fin sur le premier temps / l'attaque suivants,
    #      pour que la durée de l'event épouse une mesure ou une phrase (un event court dans un passage sans rythme est ÉTIRÉ jusqu'à la prochaine attaque marquée)
    Bt = np.array(A['beats']); Db = np.array(A['downbeats'])
    kk_all = np.array([t for t, *_ in A['drums'].get('kick', [])])
    mo = np.array(sorted([o[0] for t_ in A['tracks'] if t_ is music or t_['name'] == 'MIX_TROUS' for o in t_['onsets'] if o[1] >= 0.3]))   # toutes les attaques de la musique : dans un passage sans kick, ce sont elles qui donnent le rythme (ex. une pulsation lente toutes les 5,6 s)
    ob = np.array([o[0] for o in (bruit['onsets'] if bruit else []) if o[1] >= 0.8])
    strong = np.sort(np.concatenate([mo, ob])) if len(mo) + len(ob) else np.array([])
    def near(arr, t, tol):
        if not len(arr): return None
        i = int(np.argmin(np.abs(arr - t)));  return float(arr[i]) if abs(arr[i] - t) <= tol else None
    def after(arr, t):
        if not len(arr): return None
        i = int(np.searchsorted(arr, t)); return float(arr[i]) if i < len(arr) else None
    def phase_end(t):
        for p in phases:
            if p['start'] <= t < p['end']: return float(p['end'])
        return dur
    MINSPAN = {'PentaCircle': 4.0, 'LineAPulse': 3.0, 'Spirale': 5.0, 'Balayage': 3.0, 'OndeDeChoc': 4.0, 'Ruée': 3.0, 'Jaillissement': 4.0}   # un event bref dans un passage sans temps est ÉTIRÉ jusqu'à la prochaine attaque marquée
    FIXED = {'EvilPenta', 'Rien', 'Gerbes', 'Éruption', 'GerbeEtincelles'}   # durée propre à l'effet : seul le début est calé
    def snap_event(ev):
        t = ev['on']; s = max(ev.get('span') or 2.0, MINSPAN.get(ev['name'], 0)); moved = []
        # début : premier temps (±0.9 s) > temps (±0.5) > kick (±0.45) > attaque marquée (±0.8)
        for arr, tol in ((Db, 0.9), (Bt, 0.5), (kk_all, 0.45), (strong, 3.0)):
            c = near(arr, t, tol)
            if c is not None: t = c; break
        if ev['name'] not in FIXED:
            tgt = t + s; lo = t + 0.9 * s; hi = t + max(1.7 * s, s + 2.5); pe = phase_end(t) - 0.15
            end = None
            for arr in (Db, Bt[::4] if len(Bt) else Bt, strong):   # fin de mesure, sinon tous les 4 temps, sinon prochaine attaque marquée
                if len(arr):
                    cand = arr[(arr >= lo) & (arr <= min(hi, pe))]
                    if len(cand): end = float(cand[np.argmin(np.abs(cand - tgt))]); break
            if end is not None and end > t + 0.3: s = end - t
            elif t + s > pe: s = max(0.4, pe - t)
        else:
            if t + s > phase_end(t) - 0.1: t = max(t - 0.0, phase_end(t) - s - 0.1)
        ev['on'] = round(t, 2); ev['span'] = round(s, 2)
    for ev in events:
        if ev.pop('_nosnap', False): ev['on'] = round(ev['on'], 2); continue
        snap_event(ev)
    events.sort(key=lambda x: x['on'])
    out = {'v': 1, 'generated': 'auto-layers.py', 'base': basewin, 'mods': mods, 'events': events}
    open(os.path.join(mix, 'layers.js'), 'w', encoding='utf-8').write('window.LAYERS=' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n')
    kinds = {}
    for m in mods: kinds[m['kind']] = kinds.get(m['kind'], 0) + 1
    print('base :', len(basewin), 'phases à sections |', 'mods :', len(mods), kinds, '| events ajoutés :', len(events))
    for w in basewin: print('  phase', mmss(w['ph']), w['why'])

if __name__ == '__main__': main()

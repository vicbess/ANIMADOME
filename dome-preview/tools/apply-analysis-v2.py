# Applique analysis2.js (analyze-v2.py) aux fichiers lus par la page : remplace kick/kickS/hit/hitS de beats.js et stems.js
# par ceux de la batterie séparée (drumsep). Les forces sont recalées sur l'échelle des anciens fichiers pour que les seuils
# des effets (minS...) gardent le même sens. Les anciens fichiers doivent être sauvegardés AVANT (le script ne le fait pas).
#   python apply-analysis-v2.py <dossier_mix>
import sys, os, re, json
import numpy as np

def read_js(path, var):
    s = open(path, encoding='utf-8').read(); body = s[s.index('=') + 1:].strip().rstrip(';')
    body = re.sub(r'([{,])([A-Za-z_][A-Za-z0-9_]*):', r'\1"\2":', body); return json.loads(body)

def merge(lists, gap):
    ev = sorted([(t, s) for l in lists for t, s, *_ in l]); out = []
    for t, s in ev:
        if out and t - out[-1][0] < gap:
            if s > out[-1][1]: out[-1] = (t, s)
        else: out.append((t, s))
    return out

def remap(new_s, old_s):
    """force 0..1 -> échelle de l'ancien fichier, par rang (mêmes proportions de forts/faibles)."""
    old = np.sort(np.asarray(old_s, float)); r = (np.argsort(np.argsort(new_s)) + 0.5) / max(len(new_s), 1)
    return old[np.minimum((r * len(old)).astype(int), len(old) - 1)]

def main():
    mix = os.path.abspath(sys.argv[1]); a = open(os.path.join(mix, 'analysis2.js'), encoding='utf-8').read(); A = json.loads(a[a.index('=') + 1:].strip().rstrip(';'))
    DEF = [1] * 30 + [2] * 50 + [3] * 30 + [4] * 15 + [5] * 6 + [6] * 3 + [7]   # échelle de forces par défaut (mix sans ancienne analyse)
    bp, sp = os.path.join(mix, 'beats.js'), os.path.join(mix, 'stems.js')
    bt = read_js(bp, 'BEATS') if os.path.exists(bp) else {'kick': [], 'kickS': DEF, 'hit': [0] * 9000, 'hitS': DEF}
    sd = read_js(sp, 'STEMS') if os.path.exists(sp) else {'kickS': DEF, 'hitS': DEF}
    kick = merge([A['drums']['kick']], 0.12)
    # frappes : caisse claire + hi-hat + crash, plus fortes d'abord, jusqu'au même nombre qu'avant
    hit = merge([A['drums']['snare'], A['drums']['hh'], A['drums']['crash']], 0.06)
    want = len(bt['hit']); hs = np.array([s for _, s in hit])
    if len(hit) > want: thr = np.sort(hs)[::-1][want - 1]; hit = [h for h in hit if h[1] >= thr]
    print('kicks : %d (avant %d) ; frappes : %d (avant %d)' % (len(kick), len(bt['kick']), len(hit), len(bt['hit'])))
    for tgt, kk in ((bt, 'kickS'), (sd, 'kickS')):
        tgt['kick'] = [round(t, 3) for t, _ in kick]; tgt['kickS'] = [int(round(x)) if isinstance(tgt[kk][0], int) else round(float(x), 1) for x in remap([s for _, s in kick], tgt[kk])]
        tgt['hit'] = [round(t, 3) for t, _ in hit]; tgt['hitS'] = [int(round(x)) if isinstance(tgt['hitS'][0], int) else round(float(x), 1) for x in remap([s for _, s in hit], tgt['hitS'])]
    sd['beats'] = A['beats']; sd['downbeats'] = A['downbeats']
    open(os.path.join(mix, 'beats.js'), 'w', encoding='utf-8').write('window.BEATS=' + json.dumps(bt, separators=(',', ':')) + ';\n')
    open(os.path.join(mix, 'stems.js'), 'w', encoding='utf-8').write('window.STEMS=' + json.dumps(sd, separators=(',', ':')) + ';\n')
    print('beats.js et stems.js réécrits')

if __name__ == '__main__': main()

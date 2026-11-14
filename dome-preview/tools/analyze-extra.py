"""Compléments d'analyse d'un mix à partir des stems Demucs -> ajoute à stems.js :
  vocals : {hop:0.1, v:[...]}  niveau (dB) du stem VOIX
  high   : {hop:0.1, v:[...]}  niveau (dB) des AIGUS (> 3 kHz), somme de tous les stems (les aigus ne sont pas une piste : c'est une bande de fréquences)
  notes  : {t:[...], z:[...]}  attaques (s) et force relative des NOTES DE SYNTHÉ (stem « other », 1,5-8 kHz)
  gutty  : {hop:0.1, v:[...]}  « rugosité gutturale » 0..1 du stem « other » (timbre brillant/rugueux relatif au niveau local), repère les raclements dubstep
Usage : python analyze-extra.py <dossier des stems> <stems.js>     (à lancer après analyze-stems.py)
"""
import sys, json, numpy as np, librosa
from scipy.ndimage import median_filter, uniform_filter1d

d, path = sys.argv[1], sys.argv[2]
SR = 22050; HOP10 = int(SR * 0.1)   # 0,1 s

def load(name):
    y, _ = librosa.load(f"{d}/{name}.wav", sr=SR, mono=True); return y

def level(y):
    n = len(y) // HOP10
    return [round(float(20 * np.log10(np.sqrt((y[i * HOP10:(i + 1) * HOP10] ** 2).mean()) + 1e-6)), 1) for i in range(n)]

def band_power(y, f0, N=2048):
    """puissance du signal au-dessus de f0 par pas de 0,1 s"""
    S = np.abs(librosa.stft(y, n_fft=N, hop_length=HOP10)) ** 2
    fr = librosa.fft_frequencies(sr=SR, n_fft=N)
    return S[fr >= f0].sum(axis=0)

with open(path, encoding="utf-8") as fh:
    txt = fh.read()
S = json.loads(txt[txt.index("=") + 1:].rstrip().rstrip(";"))

# --- voix + aigus
tot = None
for name in ("drums", "bass", "other", "vocals"):
    y = load(name)
    if name == "vocals": S["vocals"] = {"hop": 0.1, "v": level(y)}
    bp = band_power(y, 3000)
    tot = bp if tot is None else tot[:min(len(tot), len(bp))] + bp[:min(len(tot), len(bp))]
S["high"] = {"hop": 0.1, "v": [round(float(10 * np.log10(x + 1e-9)), 1) for x in tot]}

# --- rugosité gutturale (stem « other »)
y = load("other"); N, HOP = 2048, 512; hs = HOP / SR
M = np.abs(librosa.stft(y, n_fft=N, hop_length=HOP))
c = librosa.feature.spectral_centroid(S=M, sr=SR)[0]; r = librosa.feature.spectral_rolloff(S=M, sr=SR)[0]; fl = librosa.feature.spectral_flatness(S=M)[0]
rms = librosa.feature.rms(S=M)[0]; active = 20 * np.log10(rms + 1e-6) > -50
def z(x): m, s = x[active].mean(), x[active].std(); return (x - m) / (s + 1e-9)
sc = (z(np.log(c + 1e-6)) + z(np.log(r + 1e-6)) + z(np.log(fl + 1e-6))) / 3
k = int(1.0 / hs) | 1; sm = np.convolve(sc, np.ones(k) / k, 'same'); sm[~active] = sm[active].min()
t10 = np.arange(0, len(sm) * hs, 0.1); g = np.interp(t10, np.arange(len(sm)) * hs, sm)
base = median_filter(g, size=int(90 / 0.1), mode='nearest'); dd = g - base
sdv = np.sqrt(uniform_filter1d(dd ** 2, int(90 / 0.1), mode='nearest')); zz = dd / (sdv + 1e-6)
S["gutty"] = {"hop": 0.1, "v": [round(float(x), 2) for x in np.clip((zz + 0.5) / 2.5, 0, 1)]}

# --- notes de synthé : attaques du stem « other » dans la bande 1,5-8 kHz (flux spectral sur 6 ms, traité par morceaux de 120 s pour limiter la mémoire)
Nn, Hn = 1024, 256; hsn = Hn / SR; fr = librosa.fft_frequencies(sr=SR, n_fft=Nn); band = (fr >= 1500) & (fr < 8000)
flux_all = []; total = librosa.get_duration(path=f"{d}/other.wav"); off = 0.0
while off < total:
    yc, _ = librosa.load(f"{d}/other.wav", sr=SR, mono=True, offset=off, duration=120)
    Sc = np.abs(librosa.stft(yc, n_fft=Nn, hop_length=Hn)); M = np.log1p(Sc[band] * 30)
    fl = np.maximum(0, np.diff(M, axis=1, prepend=M[:, :1])).sum(0); flux_all.append(np.convolve(fl, np.ones(3) / 3, 'same')); off += 120
flux = np.concatenate(flux_all); W = int(1.5 / hsn); nt, nz = [], []; last = -9
cs = np.concatenate([[0], np.cumsum(flux)]); cs2 = np.concatenate([[0], np.cumsum(flux ** 2)])
for i in range(3, len(flux) - 3):
    if flux[i] < flux[i - 3:i + 4].max(): continue
    a, b = max(0, i - W), min(len(flux), i + W); mu = (cs[b] - cs[a]) / (b - a); sd = np.sqrt(max(1e-9, (cs2[b] - cs2[a]) / (b - a) - mu * mu)); z = (flux[i] - mu) / sd
    t = i * hsn
    if z < 1.0 or t - last < 0.14: continue
    nt.append(round(t, 2)); nz.append(round(float(z), 1)); last = t
S["notes"] = {"t": nt, "z": nz}
print("notes de synthé :", len(nt))
with open(path, "w", encoding="utf-8") as fh:
    fh.write("window.STEMS=" + json.dumps(S, separators=(",", ":")) + ";")
hv = np.array(S["high"]["v"]); vv = np.array(S["vocals"]["v"])
print("high dB percentiles 5/50/95:", np.percentile(hv, [5, 50, 95]).round(1), "| vocals dB percentiles 5/50/95:", np.percentile(vv, [5, 50, 95]).round(1))

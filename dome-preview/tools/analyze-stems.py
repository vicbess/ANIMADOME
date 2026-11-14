"""Analyse d'un mix à partir de ses stems Demucs (drums/bass/other/vocals) -> stems.js
Usage : python analyze-stems.py <dossier des stems> <sortie stems.js>
Format de sortie (window.STEMS) :
  kick/kickS  : instants (s) et force (1-9) des kicks, détectés sur le stem BATTERIE, bande 30-150 Hz
  hit/hitS    : instants et force des frappes aiguës (hats, claps, cymbales), stem BATTERIE, bande 2,5-9 kHz
  gut         : {fps:50, v:[...]} flux spectral 150-1500 Hz du stem « other » (= raclements dubstep / synthés), relatif au niveau local (x10, max 99) - même format que gut.js
  bass        : {hop:0.1, v:[...]} niveau (dB) du stem BASSE
  other       : {hop:0.1, v:[...]} niveau (dB) du stem « other »
  drums       : {hop:0.1, v:[...]} niveau (dB) du stem BATTERIE
  bpm / beats : tempo global et grille de temps (librosa.beat_track sur la batterie)
"""
import sys, json, numpy as np, librosa

d, out = sys.argv[1], sys.argv[2]
SR, N, HOP = 22050, 1024, 512
hs = HOP / SR

def load(name):
    y, _ = librosa.load(f"{d}/{name}.wav", sr=SR, mono=True)
    return y

def spec(y):
    return np.abs(librosa.stft(y, n_fft=N, hop_length=HOP))

def band_db(S, f0, f1):
    fr = librosa.fft_frequencies(sr=SR, n_fft=N)
    m = (fr >= f0) & (fr < f1)
    return 10 * np.log10((S[m] ** 2).sum(axis=0) + 1e-3)

def pick(o, min_gap, k):
    """pics de l'enveloppe d'attaque o, seuil adaptatif (moyenne + k*écart-type sur +-1 s)"""
    W = int(1.0 / hs); F = len(o); res = []; last = -10
    for f in range(4, F - 4):
        if o[f] < o[f - 4:f + 5].max(): continue
        a, b = max(0, f - W), min(F, f + W)
        m, s = o[a:b].mean(), o[a:b].std()
        if o[f] < m + k * s: continue
        t = f * hs
        if t - last < min_gap:
            if res and o[f] > res[-1][1]: res[-1] = [t, o[f], (o[f] - m) / (s + 1e-9)]; last = t
            continue
        res.append([t, o[f], (o[f] - m) / (s + 1e-9)]); last = t
    return res

def onset_env(db):
    o = np.zeros(len(db))
    for f in range(3, len(db)):
        o[f] = max(0.0, db[f] - db[f - 3:f].mean())
    return o

drums = load("drums"); Sd = spec(drums)
kicks = pick(onset_env(band_db(Sd, 30, 150)), 0.16, 1.0)
hits = pick(onset_env(band_db(Sd, 2500, 9000)), 0.09, 1.3)
tempo, bt = librosa.beat.beat_track(y=drums, sr=SR, hop_length=HOP)
tempo = float(np.atleast_1d(tempo)[0])
beats = librosa.frames_to_time(bt, sr=SR, hop_length=HOP)

other = load("other"); So = spec(other)
fr = librosa.fft_frequencies(sr=SR, n_fft=N); m = (fr >= 150) & (fr <= 1500)
mag = So[m]; flux = np.maximum(0, np.diff(mag, axis=1, prepend=mag[:, :1])).sum(axis=0)
cum = np.concatenate([[0], np.cumsum(flux)]); F = len(flux); W = int(1.0 / hs)
v = np.zeros(int(len(other) / SR * 50) + 2, dtype=int)
for f in range(F):
    a, b = max(0, f - W), min(F, f + W)
    r = min(9.9, flux[f] / ((cum[b] - cum[a]) / (b - a) + 1e-3))
    i = int(f * hs * 50)
    if i < len(v): v[i] = max(v[i], int(round(r * 10)))

def level(y):
    hop = int(SR * 0.1); n = len(y) // hop
    return [round(float(20 * np.log10(np.sqrt((y[i * hop:(i + 1) * hop] ** 2).mean()) + 1e-6)), 1) for i in range(n)]

bass = load("bass")
# --- Filtrage : la batterie est parfois (presque) silencieuse (braises, passages sous l'eau, creux...). Les « kicks » y seraient du bruit : on les rejette,
# et on les remplace par les pulsations du stem BASSE lorsque c'est lui qui porte le rythme.
dlev, blev = level(drums), level(bass)
def lv(a, t): return a[min(len(a) - 1, max(0, int(t * 10)))]
DRUM_MIN, BASS_MIN = -45.0, -40.0
Sb = spec(bass)
bk = pick(onset_env(band_db(Sb, 30, 150)), 0.16, 1.0)
kd = [k for k in kicks if lv(dlev, k[0]) >= DRUM_MIN]
ts = np.array([k[0] for k in kd]) if kd else np.array([])
kb = [k for k in bk if lv(dlev, k[0]) < DRUM_MIN and lv(blev, k[0]) >= BASS_MIN and (len(ts) == 0 or np.min(np.abs(ts - k[0])) > 0.08)]
kicks = sorted(kd + kb, key=lambda k: k[0])
hits = [h for h in hits if lv(dlev, h[0]) >= DRUM_MIN]
print("kicks batterie", len(kd), "+ kicks basse", len(kb), "(rejetés", len(kicks) - len(kd) - len(kb) if False else 0, ")")
o = {
    "kick": [round(k[0], 2) for k in kicks], "kickS": [int(min(9, max(1, round(k[2])))) for k in kicks],
    "hit": [round(h[0], 2) for h in hits], "hitS": [int(min(9, max(1, round(h[2])))) for h in hits],
    "gut": {"fps": 50, "v": v.tolist()},
    "bass": {"hop": 0.1, "v": level(bass)}, "other": {"hop": 0.1, "v": level(other)}, "drums": {"hop": 0.1, "v": level(drums)},
    "bpm": round(tempo, 1), "beats": [round(float(b), 2) for b in beats],
}
with open(out, "w", encoding="utf-8") as fh:
    fh.write("window.STEMS=" + json.dumps(o, separators=(",", ":")) + ";")
print("kicks", len(kicks), "hits", len(hits), "bpm", o["bpm"], "beats", len(beats))

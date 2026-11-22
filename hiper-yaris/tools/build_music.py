"""Yarış müziği (128 BPM elektronik döngü) ve seyirci sesi sentezler.
Çıktılar: sounds/music_race.wav (döngü), sounds/crowd.wav, sounds/crowd_loop.wav"""
import numpy as np, wave, os
SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(11)
BPM = 128
beat = 60.0 / BPM
bars = 16
n = int(SR * beat * 4 * bars)
t_all = np.arange(n) / SR

def save(name, x, stereo=False):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2 if stereo else 1); w.setsampwidth(2); w.setframerate(SR)
        data = (x * 30000).astype(np.int16)
        if stereo: data = data.reshape(-1)
        w.writeframes(data.tobytes())
    print("ok", name, round(len(x) / SR, 1), "sn")

def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); acc = 0.0
    # vektörel tek kutuplu filtre (parça parça)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)

def env(length, a=0.002, d=0.2):
    k = np.arange(length) / SR
    e = np.minimum(k / a, 1.0) * np.exp(-k / d)
    return e

mix = np.zeros(n)
step = beat / 4  # 16'lık
# Davul
for i in range(bars * 16):
    pos = int(i * step * SR)
    if i % 4 == 0:  # kick
        L = int(0.35 * SR); k = np.arange(L) / SR
        f = 45 + 110 * np.exp(-k * 25)
        kick = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-k * 7)
        mix[pos:pos + L] += 0.9 * kick[:max(0, min(L, n - pos))]
    if i % 8 == 4:  # clap/snare
        L = int(0.25 * SR)
        nz = rng.standard_normal(L) * env(L, 0.001, 0.07)
        nz = nz - lowpass(nz, 900)
        mix[pos:pos + L] += 0.45 * nz[:max(0, min(L, n - pos))]
    if i % 2 == 1:  # açık hihat
        L = int(0.08 * SR)
        hh = rng.standard_normal(L) * env(L, 0.0005, 0.025)
        hh = hh - lowpass(hh, 6000)
        mix[pos:pos + L] += 0.22 * hh[:max(0, min(L, n - pos))]
# Bas (Am - F - C - G), 16'lık sekiz nota
roots = [45, 41, 48, 43]  # MIDI: A2 F2 C3 G2
def hz(m): return 440 * 2 ** ((m - 69) / 12)
bass = np.zeros(n)
for b in range(bars):
    r = roots[b % 4]
    for i in range(16):
        if i % 4 == 0: continue  # kick ile çakışmasın (sidechain hissi)
        pos = int((b * 16 + i) * step * SR); L = int(step * SR * 0.9)
        k = np.arange(L) / SR
        f = hz(r + (12 if i % 8 == 6 else 0))
        saw = 2 * ((k * f) % 1.0) - 1
        bass[pos:pos + L] += saw * env(L, 0.003, 0.12)
mix += 0.32 * lowpass(bass, 700)
# Arp lead (minör akor arpejleri), ikinci 8 ölçüden itibaren
lead = np.zeros(n)
chords = [[57, 60, 64, 69], [53, 57, 60, 65], [60, 64, 67, 72], [55, 59, 62, 67]]
for b in range(4, bars):
    ch = chords[b % 4]
    for i in range(16):
        pos = int((b * 16 + i) * step * SR); L = int(step * SR * 0.8)
        k = np.arange(L) / SR
        f = hz(ch[[0, 1, 2, 3, 2, 1, 3, 2][i % 8]] + 12)
        sq = np.sign(np.sin(2 * np.pi * f * k)) * 0.5 + 0.5 * (2 * ((k * f * 1.003) % 1.0) - 1)
        lead[pos:pos + L] += sq * env(L, 0.002, 0.09)
mix += 0.14 * lowpass(lead, 3500)
# Pad
pad = np.zeros(n)
for b in range(bars):
    ch = chords[b % 4]
    pos = int(b * 4 * beat * SR); L = int(4 * beat * SR)
    k = np.arange(L) / SR
    s = sum(2 * ((k * hz(m) * d) % 1.0) - 1 for m in ch[:3] for d in (0.997, 1.003))
    e = np.minimum(k / 0.4, 1.0) * np.minimum((4 * beat - k) / 0.4, 1.0)
    pad[pos:pos + L] += s * e
mix += 0.05 * lowpass(pad, 1800)
# Sidechain pompası
pump = 0.55 + 0.45 * np.minimum(((t_all % beat) / beat) * 3.0, 1.0)
mix = mix * pump
mix /= np.max(np.abs(mix)) * 1.05
save("music_race.wav", mix)

# Seyirci tezahüratı (kısa) ve ortam döngüsü
def crowd(seconds, swell):
    L = int(SR * seconds); k = np.arange(L) / SR
    base = np.zeros(L)
    for _ in range(40):  # birçok "ses"
        nz = rng.standard_normal(L)
        f0 = rng.uniform(300, 1400)
        band = lowpass(nz, f0 * 1.6) - lowpass(nz, f0 * 0.6)
        mod = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(0.3, 2.5) * k + rng.uniform(0, 6))
        base += band * mod
    base /= np.max(np.abs(base))
    if swell:
        e = np.minimum(k / 0.4, 1.0) * np.exp(-np.maximum(k - 1.2, 0) / 1.2)
    else:
        e = np.ones(L) * 0.5
        fade = int(SR * 0.3); e[:fade] *= np.linspace(0, 1, fade); e[-fade:] *= np.linspace(1, 0, fade)
    return base * e
save("crowd.wav", 0.8 * crowd(3.5, True))
save("crowd_loop.wav", 0.6 * crowd(6.0, False))

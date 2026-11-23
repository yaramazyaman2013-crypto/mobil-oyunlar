"""Oyunun ses efektlerini sentezler (.wav, 22050 Hz mono). Çalıştır: python3 tools/build_sounds.py"""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(7)

def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    print("ok", name)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=None):
    e = np.ones(n); ai = max(1, int(a * SR)); e[:ai] = np.linspace(0, 1, ai)
    if r: e *= np.exp(-np.arange(n) / (r * SR))
    return e

os.makedirs(OUT, exist_ok=True)
# Coin: iki tonlu parlak "ding"
x = t(0.25); s = np.where(x < 0.07, np.sin(2*np.pi*1320*x), np.sin(2*np.pi*1760*x))
save("coin", 0.5 * s * env(len(x), r=0.08))
# Nitro: yükselen sweep
x = t(0.7); f = 200 + 900 * x; ph = 2*np.pi*np.cumsum(f)/SR
save("nitro", 0.35 * (np.sign(np.sin(ph)) * 0.4 + np.sin(ph)) * env(len(x), r=0.35))
# Tık
x = t(0.06); save("click", 0.5 * np.sin(2*np.pi*900*x) * env(len(x), r=0.015))
# Geri sayım bip'leri
x = t(0.18); save("beep", 0.4 * np.sin(2*np.pi*660*x) * env(len(x), r=0.08))
x = t(0.5); save("go", 0.4 * (np.sin(2*np.pi*990*x) + 0.5*np.sin(2*np.pi*1980*x)) * env(len(x), r=0.2))

# Rakip motoru: V8 benzeri, ateşleme darbeli, kesintisiz döngü (1 sn, tüm frekanslar tam sayı Hz)
x = t(1.0); f0 = 80
ph = 2*np.pi*f0*x
s = np.zeros_like(x)
for k, a in [(1, 1.0), (2, 0.7), (3, 0.45), (4, 0.5), (6, 0.25), (8, 0.18), (12, 0.08)]:
    s += a * np.sin(k*ph + rng.uniform(0, 6.28))
pulse = 0.55 + 0.45 * (0.5 + 0.5*np.sin(4*ph)) ** 3          # ateşleme vuruşları
noise = np.fft.irfft(np.fft.rfft(rng.normal(0, 1, len(x))) * (np.arange(len(x)//2+1) < 2500))
s = s * pulse + 0.35 * noise * pulse
s = np.tanh(s * 0.9)
save("engine_rival", 0.55 * s / np.max(np.abs(s)))
# Geçiş uğultusu: yükselip düşen filtreli gürültü (yanından araç geçince)
x = t(0.9); n = rng.normal(0, 1, len(x))
spec = np.fft.rfft(n); fr = np.fft.rfftfreq(len(x), 1/SR)
spec *= np.exp(-((fr - 700) / 900) ** 2)
w = np.fft.irfft(spec, len(x)); w /= np.max(np.abs(w))
e = np.exp(-((x - 0.3) / 0.16) ** 2)
save("whoosh", 0.6 * w * e)

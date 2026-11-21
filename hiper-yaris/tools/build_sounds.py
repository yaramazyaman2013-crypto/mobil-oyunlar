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

"""Yumuşak, gürültülü duman dokusu üretir: assets/sprites/smoke_soft.png (256x256 RGBA)"""
import numpy as np, os
from PIL import Image
N = 256
rng = np.random.default_rng(3)
y, x = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
r = np.sqrt(x * x + y * y)

def value_noise(freq):
    g = rng.random((freq + 1, freq + 1))
    xs = np.linspace(0, freq, N)
    xi = xs.astype(int).clip(0, freq - 1); xf = xs - xi
    xf = xf * xf * (3 - 2 * xf)
    a = g[np.ix_(xi, xi)]; b = g[np.ix_(xi, xi + 1)]; c = g[np.ix_(xi + 1, xi)]; d = g[np.ix_(xi + 1, xi + 1)]
    fx = xf[None, :]; fy = xf[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

fbm = sum(value_noise(f) / (i + 1) for i, f in enumerate([4, 8, 16, 32]))
fbm = (fbm - fbm.min()) / (fbm.max() - fbm.min())
falloff = np.clip(1 - r, 0, 1) ** 1.7
alpha = np.clip(falloff * (0.45 + 0.75 * fbm) * 1.25, 0, 1)
shade = 0.82 + 0.18 * fbm          # hafif iç gölgelenme
img = np.dstack([shade, shade, shade, alpha])
out = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "smoke_soft.png")
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(out)
print("yazıldı", out)

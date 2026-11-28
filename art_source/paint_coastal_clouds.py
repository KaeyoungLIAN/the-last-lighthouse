"""Bake a seamless cloud study for the Greybay skydome. Uses NumPy and Pillow."""
from pathlib import Path
import numpy as np
from PIL import Image


WIDTH, HEIGHT = 2048, 512
rng = np.random.default_rng(8241)
az, el = np.meshgrid(np.arange(WIDTH, dtype="f") * 360 / WIDTH,
                     np.arange(HEIGHT, dtype="f") * 90 / (HEIGHT - 1))


def pigment(columns, rows, bend=0):
    """Periodic brush grain, including the last-to-first panorama seam."""
    grid = rng.uniform(-1, 1, (rows + 1, columns)).astype("f")
    x = az * columns / 360
    y = np.clip(el + bend, 0, 90) * (rows - 1) / 90
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = grid[iy, ix] * (1-fx) + grid[iy, (ix+1) % columns] * fx
    b = grid[iy+1, ix] * (1-fx) + grid[iy+1, (ix+1) % columns] * fx
    return (a * (1-fy) + b * fy).astype("f")


def clamp(x):
    return np.clip(x, 0, 1)


def bearing(from_angle, to_angle):
    return (from_angle - to_angle + 180) % 360 - 180


wash = pigment(49, 49)
grain = pigment(196, 104)
azimuth = az + 1.1 * wash + .32 * grain
elevation = el + 1.0 * wash + .38 * grain + .19 * pigment(416, 218)
coverage = np.zeros_like(az)
relief = np.zeros_like(az)

# Each bank has a calm, fairly level condensation base. Nested brush shapes
# grow upward from that shelf; the smaller lobes catch light on their shoulders.
def bank(longitude, base, spread, height):
    floor = base + .9 * wash + .35 * grain
    inner = clamp((elevation - floor) / max(1.8, height * .28))
    for i in range(19):
        along = rng.uniform(-1, 1)
        profile = (1 - abs(along) ** 1.8) * (.75 + .25 * np.cos(4 * along))
        ry = height * rng.uniform(.28, .75) * (.37 + .63 * profile)
        rx = ry * rng.uniform(1.35, 2.45)
        center_x = longitude + along * spread
        center_y = base + height * profile * rng.uniform(.22, .48)
        dx = bearing(azimuth, center_x) / rx
        dy = (elevation - center_y) / ry
        sphere = 1 - dx*dx - dy*dy
        alpha = clamp(sphere * 2.5) * inner
        depth = np.sqrt(clamp(sphere))
        exposed = clamp(.43 + .43*dy - .17*dx + .17*depth + .075*wash)
        relief[:] = relief * (1-alpha) + alpha * exposed
        coverage[:] = coverage * (1-alpha) + alpha


for args in [(9, 7, 25, 13), (64, 3, 18, 9), (101, 17, 26, 16),
             (142, 4, 20, 11), (198, 9, 31, 16), (254, 17, 14, 9),
             (289, 4.5, 24, 12), (333, 23, 14, 12)]:
    bank(*args)

# Sparse strokes of cirrus are painted on a separate, higher sheet.
wind_shear = 3.2 * np.sin(np.deg2rad(az*4 + .6*el)) + 1.3*pigment(13, 9)
streak = pigment(19, 137, wind_shear)
cirrus = clamp((.36 * pigment(10, 10) + .36*streak + .12*grain + .06) * 1.8)
cirrus *= clamp((el-4) / 14) * clamp((87-el)/15)
channels = np.stack([coverage, relief, cirrus], axis=2)
destination = Path(__file__).resolve().parents[1] / "game/art/atmosphere/cloud_study.png"
destination.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(np.uint8(clamp(channels)*255 + .5)).save(destination, optimize=True)

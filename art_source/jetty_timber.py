"""Paint eight salt-washed plank faces across a single atlas. U follows the grain."""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "game" / "art" / "greybay" / "jetty_timber.png"
WIDTH, STRIP = 768, 64
atlas = np.full((STRIP * 9, WIDTH, 3), 255, dtype=np.uint8)
rng = np.random.default_rng(1753)
v, u = np.mgrid[0:STRIP, 0:WIDTH]
x, y = u / WIDTH, v / STRIP

for row in range(8):
    # A knot pushes growth lines aside. End checks follow the surrounding grain.
    kx, ky = rng.uniform(.15, .86), rng.uniform(.17, .82)
    radius = np.sqrt(((x - kx) * 12) ** 2 + ((y - ky) * 3.9) ** 2)
    warp = y + .041 * np.sin(6*x + row) + .017 * np.sin(18*x + y*3)
    warp += .28 * (y - ky) * np.exp(-radius**2 * 1.8)
    grain = np.cos(warp * 92 + 1.75*np.sin(warp*16 + 1.3*x) + row)
    fibres = np.cos(warp * 233 + .87*np.cos(x*8 + warp*16)) ** 10
    stain = np.sin(warp*8 + x*3.8 + row) + .55*np.cos(warp*21 - x*4.1)
    pigment = 8*stain - 12*np.maximum(grain, 0)**6 - 6*fibres
    pigment -= 27*np.exp(-radius*radius*5.2) + 13*(np.cos(radius*26)*.5+.5)**6*np.exp(-radius*radius*1.9)
    pigment += rng.normal(0, 1.65, (STRIP, WIDTH))
    for edge in (0, 1):
        crack_y, length = rng.uniform(.12, .86), rng.uniform(.06, .22)
        along = np.abs(x-edge) / length
        offset = np.abs(y - crack_y - .028*np.sin(x*21 + row))
        pigment -= 54 * np.clip(1-offset/(.016 + .0001),0,1) * np.clip(1-along,0,1)
    board = np.array([134,130,120]) + rng.normal(0, 4) + .85 * pigment[:,:,None]
    atlas[row*STRIP:(row+1)*STRIP] = np.clip(board, 0, 255)

Image.fromarray(atlas).save(OUT, optimize=True)

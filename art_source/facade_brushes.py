"""Bake a tileable, linear brush mask for the Greybay facade shaders."""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

SIZE = 512
rng = np.random.default_rng(412)
y, x = np.mgrid[:SIZE, :SIZE] / SIZE


def field(rows, cols, xcoord=x, ycoord=y):
    lattice = rng.random((rows, cols))
    sample = map_coordinates(lattice, (ycoord * rows, xcoord * cols),
                             order=3, mode="grid-wrap")
    return np.clip(sample, 0, 1)


# R carries larger pigment islands, G broken trowel strokes, B timber fibres.
clouds = .56 * field(5, 6) + .26 * field(17, 15) + .18 * field(39, 42)
stucco = .5 * field(41, 21) + .27 * field(97, 64) + .23 * field(226, 178)
warp = field(4, 2)
fibres = .5 * field(64, 5, x, y + .034 * warp) + .24 * field(131, 13, x, y + .03 * warp)
fibres += .26 * field(26, 3, x, y + .041 * warp)
channels = np.stack([clouds, stucco, fibres], axis=-1)
target = Path(__file__).resolve().parents[1] / "game/art/greybay/seacoast_brushes.png"
Image.fromarray((np.clip(channels, 0, 1) * 255).astype(np.uint8)).save(target, optimize=True)

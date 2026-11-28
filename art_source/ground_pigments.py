"""Paint seamless material masks for the Greybay terrain at 1024 px per six metres."""
from math import cos, pi, sin
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw


SIZE = 1024
rng = Random(19304)
noise = np.random.default_rng(184)
y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE


def wash(nx, ny):
    grid = noise.uniform(-1, 1, (ny, nx))
    u, v = x * nx, y * ny
    ix, iy = u.astype(int), v.astype(int)
    u, v = u - ix, v - iy
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    return ((1-u)*(1-v)*grid[iy,ix] + u*(1-v)*grid[iy,(ix+1)%nx]
            + (1-u)*v*grid[(iy+1)%ny,ix] + u*v*grid[(iy+1)%ny,(ix+1)%nx])


def ground_wash(strength):
    field = 128 + strength*(wash(9, 7) + .48*wash(28, 25) + .3*wash(94, 66))
    return Image.fromarray(np.uint8(np.clip(field, 0, 255)))


def dab(draw, cx, cy, a, shape, value):
    ca, sa = cos(a), sin(a)
    pts = [(cx+u*ca-v*sa, cy+u*sa+v*ca) for u,v in shape]
    # Duplicate marks crossing a tile boundary onto its opposite edge.
    xs, ys = [0], [0]
    if min(px for px,_ in pts) < 0: xs.append(SIZE)
    if max(px for px,_ in pts) >= SIZE: xs.append(-SIZE)
    if min(py for _,py in pts) < 0: ys.append(SIZE)
    if max(py for _,py in pts) >= SIZE: ys.append(-SIZE)
    for dx in xs:
        for dy in ys:
            draw.polygon([(px+dx, py+dy) for px, py in pts], fill=value)


def grass():
    surface = ground_wash(28)
    draw = ImageDraw.Draw(surface)
    for _ in range(1580):
        cx, cy = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        direction = rng.uniform(0, 2*pi)
        blades = rng.randrange(3, 8)
        for k in range(blades):
            length = rng.uniform(8, 24)
            w = rng.uniform(1.4, 3.7)
            offset = (k/(blades-1)-.5)
            shape = [(0, -w*.3), (.60*length, -w*.8), (length, -w*.95),
                     (.57*length, w*.48), (.13*length, w*.56)]
            angle = direction + offset*rng.uniform(.9, 2.4)
            tone = rng.randint(55, 97) if k%3==0 else rng.randint(149, 200)
            dab(draw, cx+offset*4, cy+offset*2, angle, shape, tone)
    return surface


def dirt():
    surface = ground_wash(30)
    draw = ImageDraw.Draw(surface)
    for _ in range(320):
        cx, cy = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        for _ in range(rng.randrange(2, 11)):
            px, py = (cx+rng.gauss(0, 21))%SIZE, (cy+rng.gauss(0, 17))%SIZE
            a = rng.uniform(0, 2*pi)
            r = rng.uniform(1.1, 8.5)
            s = r*rng.uniform(.46, .80)
            pebble = [(-r,-.12*s),(-.47*r,-.81*s),(.44*r,-.94*s),(r,-.16*s),
                      (.63*r,.71*s),(-.19*r,s),(-.88*r,.40*s)]
            dab(draw, px+1.1, py+1.4, a, pebble, rng.randint(58, 92))
            dab(draw, px, py, a, pebble, rng.randint(135, 178))
            dab(draw, px, py, a, pebble[:3]+[(.07*r, .02*s)], rng.randint(175, 210))
    return surface


def scree():
    surface = ground_wash(33)
    draw = ImageDraw.Draw(surface)
    for _ in range(1020):
        cx, cy = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        r = rng.uniform(4, 26)
        s = r*rng.uniform(.20,.58)
        a = .56 + rng.gauss(0, .6)
        shape = [(-r,.05*s),(-.58*r,-.69*s),(.16*r,-s),(.94*r,-.55*s),
                 (r,.16*s),(.40*r,.88*s),(-.50*r,.91*s)]
        dab(draw,cx+1.1,cy+1.9,a,shape,rng.randint(52,80))
        dab(draw,cx,cy,a,shape,rng.randint(101,163))
        dab(draw,cx,cy,a,shape[:4]+[(.14*r,.03*s)],rng.randint(157,198))
    return surface


def paving():
    """R carries the crown and bevel, G the individual stone, B the weathered grain."""
    crown = Image.new("L", (SIZE, SIZE), 0)
    tint = Image.new("L", (SIZE, SIZE), 110)
    crown_draw, tint_draw = ImageDraw.Draw(crown), ImageDraw.Draw(tint)
    for row in range(10):
        cuts = [(i + .50*(row%2) + rng.uniform(-.17,.17))*SIZE/8 for i in range(8)]
        for i, start in enumerate(cuts):
            end = cuts[(i+1)%8] + (SIZE if i==7 else 0)
            cx,cy = ((start+end)*.5)%SIZE,(row+.5)*SIZE/10
            w,h = (end-start)*.5-2.5,SIZE/20-3
            bevel = [rng.uniform(4,14) for k in range(8)]
            outline = [(-w+bevel[0],-h), (w-bevel[1],-h), (w,-h+bevel[2]),
                       (w,h-bevel[3]),(w-bevel[4],h),(-w+bevel[5],h),
                       (-w,h-bevel[6]),(-w,-h+bevel[7])]
            tilt = rng.uniform(-.027,.027)
            dab(crown_draw,cx,cy,tilt,outline,105)
            dab(tint_draw,cx,cy,tilt,outline,rng.randint(54,203))
            apex=[(u*.96,v*.945) for u,v in outline]
            dab(crown_draw,cx-1,cy-1,tilt,apex,244)
            if rng.random()<.28:
                # A short, shallow fissure entering from a worn corner.
                dab(crown_draw,cx,cy,tilt,[(w*.83,-h*.93),(w*.57,-h*.50),
                    (w*.57,-h*.39),(w*.20,-h*.17),(w*.52,-h*.48)],154)
    return Image.merge("RGB",(crown,tint,ground_wash(41)))


def main():
    target = Path(__file__).resolve().parents[1]/"game/art/terrain/ground_pigments.png"
    target.parent.mkdir(exist_ok=True,parents=True)
    Image.merge("RGB", (grass(), dirt(), scree())).save(target, optimize=True)
    paving().save(target.with_name("harbor_flagstones.png"), optimize=True)


if __name__ == "__main__":
    main()

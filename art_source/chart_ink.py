"""Paint the expedition desk's north-up foldout; run with Python + Pillow."""
from math import sin,cos,exp,pi,tau
from random import Random
import sys

from PIL import Image,ImageDraw
import numpy as np

W,H=1024,512
rng=Random(409)
ink="#433f35"
water="#788f87"
paper="#baa477"
sheet=Image.new("RGB",(W,H),water)
d=ImageDraw.Draw(sheet)

def coast(a):
    sp=(abs(cos(a))**3+abs(sin(a))**3)**(-1/3)
    delta=(a-3.05+pi)%tau-pi
    return sp*(1+.021*sin(3*a+.4)+.019*cos(5*a-.7)+.016*sin(9*a+1.1)+.009*cos(15*a)
               -.195*exp(-(delta/.095)**2))
shore=[(512+416*cos(tau*i/300)*coast(tau*i/300),256+196*sin(tau*i/300)*coast(tau*i/300)) for i in range(301)]
for _ in range(320):
    x,y=rng.randrange(W),rng.randrange(H)
    d.arc((x-8,y-3,x+8,y+4),15,151,fill="#849b91",width=1)
d.line(shore,fill="#799991",width=18,joint="curve")
d.line(shore,fill="#c7c8a6",width=10,joint="curve")
d.polygon(shore,fill=paper)
d.line(shore,fill="#777d68",width=3,joint="curve")
# Six charted country vignettes line up with the six physical flagstones on the table.
hues=["#9eabb1","#81a69a","#b87e68","#c69f64","#81a3ad","#889c7f"]
for i in range(6):
    a=-2.30-tau*i/6
    x=512+cos(a)*.50/1.49*W
    y=256+sin(a)*.27/.79*H
    pts=[(x+84*(1+.15*sin(3*t+i))*cos(t),y+43*(1+.15*cos(5*t+i))*sin(t)) for t in (tau*j/55 for j in range(56))]
    d.polygon(pts,fill=hues[i]);d.line(pts,fill="#838572",width=2)
    start=(507,260)
    for k in range(18):
        def trail(t):
            return (start[0]*(1-t)+x*t+10*sin(t*pi)*sin(a),start[1]*(1-t)+y*t+13*sin(t*pi*2)*cos(a))
        d.line([trail(k/18),trail((k+.65)/18)],fill="#825333",width=3)
    for dx,dy,size in [(-68,-11,13),(-51,-27,16),(30,31,14),(54,17,17),(71,-2,12)]:
        xx,yy=x+dx,y+dy
        if i in (0,2):
            d.line([(xx-size,yy+size/2),(xx,yy-size),(xx+size,yy+size/2)],fill=ink,width=2)
            d.line([(xx,yy-size),(xx-3,yy-3),(xx+4,yy-5),(xx+8,yy+3)],fill="#eee4c6",width=2)
        elif i in (1,4):
            d.arc((xx-size,yy-7,xx,yy+8),10,155,fill=ink,width=2)
            d.arc((xx-1,yy-7,xx+size,yy+8),25,160,fill=ink,width=2)
        elif i==3:
            d.arc((xx-size,yy-2,xx+size,yy+13),180,330,fill=ink,width=2)
        else:
            d.polygon([(xx,yy-size/1.7),(xx-7,yy+4),(xx+7,yy+4)],fill="#536b5c")
    d.ellipse((x-4,y-4,x+4,y+4),outline=ink,width=2)

# Light compass rulings cross the survey. The central port is picked out in red lead.
for x in range(69,986,74): d.line((x,22,x,H-23),fill="#9c977d")
for y in range(56,466,67): d.line((22,y,W-22,y),fill="#9d997d")
d.ellipse((495,242,529,276),fill="#9f6852",outline=ink,width=3)
d.polygon([(503,266),(507,260),(508,251),(516,251),(517,260),(521,266)],fill="#e6cf9a")
d.polygon([(506,250),(512,245),(518,250)],fill="#e6cf9a")
cx,cy=925,409
d.ellipse((cx-38,cy-38,cx+38,cy+38),outline=ink,width=2)
d.ellipse((cx-29,cy-29,cx+29,cy+29),outline="#87907c",width=1)
for i in range(8):
    a=tau*i/8-pi/2; r=49 if i%2==0 else 27
    tip=(cx+r*cos(a),cy+r*sin(a))
    left=(cx+6*cos(a-pi/2),cy+6*sin(a-pi/2))
    right=(cx+6*cos(a+pi/2),cy+6*sin(a+pi/2))
    d.polygon([tip,(cx,cy),left],fill="#526f6a");d.polygon([tip,(cx,cy),right],fill="#c2a571")
d.ellipse((cx-4,cy-4,cx+4,cy+4),fill=ink)
for pad,width,color in [(8,4,"#7c7056"),(16,1,"#8b7d61"),(21,2,"#bca57c")]:
    d.rectangle((pad,pad,W-1-pad,H-1-pad),outline=color,width=width)
for x in range(26,W-23,22): d.line((x,9,x,15),fill=ink,width=2)
for y in range(26,H-23,22): d.line((9,y,15,y),fill=ink,width=2)
# Ink hand-stamped on the margin of the survey.
d.rounded_rectangle((48,41,101,91),radius=3,outline="#a96e53",width=3)
d.line([(61,79),(67,76),(69,54),(80,54),(83,76),(89,79),(61,79)],fill="#a96e53",width=3)
d.polygon([(67,53),(75,46),(83,53)],fill="#a96e53")
d.ellipse((70,57,79,62),fill="#a96e53")
# Creases, slightly uneven ageing and paper grain. The geometry has corresponding folds.
pix=np.array(sheet,dtype=np.float32);yy,xx=np.mgrid[0:H,0:W]
wear=2.3*np.cos(xx*.039+yy*.015)+1.6*np.sin(yy*.048-xx*.018)
for seam in (W/3,W*2/3):
    wear+=9*np.exp(-((xx-seam+2)/2.8)**2)-12*np.exp(-((xx-seam-2)/3.2)**2)
wear+=6*np.exp(-((yy-H/2+1)/2.4)**2)-8*np.exp(-((yy-H/2-2)/3.1)**2)
wear+=np.random.default_rng(931).normal(0,1.8,size=wear.shape)
Image.fromarray(np.clip(pix+wear[:,:,None],0,255).astype("uint8")).save(sys.argv[1])

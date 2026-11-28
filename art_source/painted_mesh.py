"""Closed profile meshes and compact pigment atlases shared by the Blender models."""
from math import sin, cos, pi, tau
from pathlib import Path
from tempfile import TemporaryDirectory
import struct
import zlib
from math import ceil, sqrt
import bpy
import bmesh
from mathutils import Vector

ink = "273e49"
ivory = "ecdfb7"
ochre = "df9b36"
sun = "f6c961"
saddle = "824e37"
brass = "e8b865"
patina = "467974"
wine = "ac5548"

def xyz(v):
    return (v[0], -v[2], v[1])

def painted_material(name, colors, directory):
    """Small sRGB paint atlas shared by every rigid piece. Mipmaps preserve distant colors."""
    tiles = sorted(set(colors))
    size, count = 24, ceil(sqrt(len(tiles)))
    dim = count*size
    pixels = bytearray()
    for y in range(dim):
        pixels.append(0)
        for x in range(dim):
            idx = (count-1-y//size)*count+x//size
            c = tiles[min(idx,len(tiles)-1)]
            u,v = (x%size)/size,(y%size)/size
            wash = .972 + .025*cos(v*3+u*1.8)+.012*sin(u*18+v*7)+.008*cos(u*31-v*22)
            pixels.extend(min(255,round(int(c[i:i+2],16)*wash)) for i in (0,2,4))
    def chunk(tag,data):
        return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data))
    path=Path(directory)/(name+"_pigment.png")
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",dim,dim,8,2,0,0,0))
                     +chunk(b"IDAT",zlib.compress(pixels,9))+chunk(b"IEND",b""))
    image=bpy.data.images.load(str(path))
    image.pack()
    mat=bpy.data.materials.new("MAT_"+name+"_Paint")
    mat.use_nodes=True
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=image
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value=.79
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    return mat, {color:(i%count,i//count) for i,color in enumerate(tiles)},count

emissive = bpy.data.materials.new("MAT_LuminousIris")
emissive.use_nodes = True
iris = emissive.node_tree.nodes.get("Principled BSDF")
iris.inputs["Base Color"].default_value=(.72,.52,.23,1)
iris.inputs["Emission Color"].default_value=(.78,.54,.23,1)
iris.inputs["Emission Strength"].default_value=1.2

class Part:
    """Bake closed profile solids and stitched fabric panels into one rigid mesh."""
    def __init__(self, name):
        self.origin = (0, 0, 0)
        self.name, self.points, self.faces, self.colors, self.smoothing = name, [], [], [], []

    def polygon(self, indices, color, smooth=False):
        self.faces.append(indices)
        self.smoothing.append(smooth)
        self.colors.append(color)

    def rings(self, rings, colors, smooth=True):
        n = len(rings[0])
        start = len(self.points)
        for ring in rings:
            self.points.extend(ring)
        if isinstance(colors, str):
            colors = [colors] * len(rings)
        self.polygon(tuple(start + j for j in reversed(range(n))), colors[0])
        for i in range(len(rings)-1):
            for j in range(n):
                a = start+i*n+j
                b = start+i*n+(j+1)%n
                self.polygon((a,b,b+n,a+n), colors[min(i,len(colors)-1)], smooth)
        cap = start+(len(rings)-1)*n
        self.polygon(tuple(cap + j for j in range(n)), colors[-1])

    def loft(self, profile, colors, segments=20, folds=0, smooth=True):
        # Each row is height, half width, half depth, optional forward/side offset.
        rings = []
        for row in profile:
            y, w, d, *offset = row
            z, x = (offset+[0,0])[:2]
            ring = []
            for i in range(segments):
                a = tau*i/segments
                pleat = 1 + folds*cos(6*a)
                ring.append((x+w*sin(a)*pleat, y, z+d*cos(a)*pleat))
            rings.append(ring)
        self.rings(rings, colors, smooth)

    def oval(self, center, radii, color, tilt=0):
        x,y,z = center
        w,h,d = radii
        rings=[]
        for i in range(11):
            lat = -.5*pi+.015+(pi-.03)*i/10
            ring=[]
            for j in range(18):
                a = tau*j/18
                u,v = cos(lat)*w*sin(a), sin(lat)*h
                ring.append((x+u*cos(tilt)-v*sin(tilt),y+u*sin(tilt)+v*cos(tilt),z+d*cos(lat)*cos(a)))
            rings.append(ring)
        self.rings(rings,color)

    def sweep(self, path, widths, colors, sides=10, flat=1):
        rings=[]
        points=[Vector(p) for p in path]
        for i,p in enumerate(points):
            axis=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            ref=Vector((1,0,0)) if abs(axis.x)<.86 else Vector((0,0,1))
            u = axis.cross(ref).normalized()
            v = axis.cross(u).normalized()
            rings.append([tuple(p+widths[i]*(cos(tau*j/sides)*u*flat+sin(tau*j/sides)*v)) for j in range(sides)])
        self.rings(rings,colors)

    def panel(self, outline, color, depth=.012, axis=2):
        a = [tuple(p) for p in outline]
        back = [tuple(v + (depth if i == axis else 0) for i, v in enumerate(point)) for point in a]
        self.rings([a,back],color,False)

    def satchel(self,x,y,z,w,h,d, leather=saddle):
        # Shaped leather gusset and curved flap with contrast binding.
        self.loft([(y-h,.73*w,.78*d,z,x),(y-h*.84,w,d,z,x),(y+h*.64,.96*w,d,z,x),
                   (y+h,.78*w,.71*d,z,x)],["694737",leather,"ae7750"],16)
        outward=1 if z>0 else -1
        f=z+outward*d
        self.panel([(x-w*.85,y+h*.59,f),(x+w*.85,y+h*.59,f),(x+w*.73,y-.01,f+.008*outward),
                    (x,y-h*.30,f+.015*outward),(x-w*.73,y-.01,f+.008*outward)],"b78253",outward*.012)
        for s in [-1,1]:
            self.sweep([(x+s*w*.53,y+h*.42,f+outward*.02),(x+s*w*.53,y-h*.48,f+outward*.02)], [.018,.018], "5b4437",6)
            self.oval((x+s*w*.53,y-.005,f+outward*.032),(.024,.020,.013),brass)

    def finish(self, material, tiles, count):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([xyz(p) for p in self.points], [], self.faces)
        mesh.materials.append(material)
        if "ecd485" in self.colors:
            mesh.materials.append(emissive)
        uvs = mesh.uv_layers.new(name="Pigment")
        for p,c,s in zip(mesh.polygons,self.colors,self.smoothing):
            p.use_smooth=s
            if c=="ecd485":
                p.material_index=1
            u,v=tiles[c]
            for j in p.loop_indices:
                x,y,z=self.points[mesh.loops[j].vertex_index]
                # Continuous low-frequency paint mapping inside a padded palette cell.
                uvs.data[j].uv=((u+.50+.34*sin(5*x+2*z))/count,
                                (v+.50+.34*sin(4*y-1.2*z))/count)
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:])
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        obj=bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = xyz(self.origin)
        return obj

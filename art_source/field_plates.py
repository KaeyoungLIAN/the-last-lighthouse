"""Render the wildlife the player actually encounters into a transparent field-guide atlas.
Run with Blender in background mode. Rows follow the region order, prey at left.
"""
from pathlib import Path
from tempfile import TemporaryDirectory

import bpy
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 320, 170
REGIONS = ("snow", "tide", "volcano", "desert", "lake", "forest")
direction = Vector((4.4, 2.9, 2.45)).normalized()
orientation = (-direction).to_track_quat("-Z", "Y")
right = orientation @ Vector((1, 0, 0))
up = orientation @ Vector((0, 1, 0))
atlas = np.zeros((HEIGHT * len(REGIONS), WIDTH * 2, 4), dtype=np.float32)

with TemporaryDirectory() as folder:
    for row, region in enumerate(REGIONS):
        for col, role in enumerate(("prey", "champion")):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            scene = bpy.context.scene
            bpy.ops.import_scene.gltf(filepath=str(ROOT / "game/art/cast" / f"{region}_{role}.glb"))
            points = [obj.matrix_world @ Vector(corner) for obj in scene.objects if obj.type == "MESH"
                      for corner in obj.bound_box]
            def extent(axis):
                samples = [p.dot(axis) for p in points]
                return min(samples), max(samples)
            x0, x1 = extent(right)
            y0, y1 = extent(up)
            z0, z1 = extent(direction)
            center = right * ((x0+x1)*.5) + up * ((y0+y1)*.5) + direction * ((z0+z1)*.5)
            camera = bpy.data.objects.new("Specimen camera", bpy.data.cameras.new("Specimen lens"))
            scene.collection.objects.link(camera)
            camera.location = center + direction * 12
            camera.rotation_euler = orientation.to_euler()
            camera.data.type = "ORTHO"
            camera.data.ortho_scale = max(x1-x0,(y1-y0)*WIDTH/HEIGHT) * 1.06
            scene.camera = camera
            scene.render.engine = "BLENDER_WORKBENCH"
            style = scene.display.shading
            style.light = "STUDIO"
            style.color_type = "TEXTURE"
            style.show_specular_highlight = False
            style.show_shadows = True
            style.show_cavity = True
            style.cavity_type = "WORLD"
            style.cavity_ridge_factor = 1.0
            style.cavity_valley_factor = 1.2
            style.show_object_outline = False
            scene.view_settings.view_transform = "Standard"
            scene.render.film_transparent = True
            scene.render.image_settings.file_format = "PNG"
            scene.render.image_settings.color_mode = "RGBA"
            scene.render.resolution_x = WIDTH
            scene.render.resolution_y = HEIGHT
            scene.render.resolution_percentage = 100
            scene.render.filepath = str(Path(folder)/f"{region}_{role}.png")
            bpy.ops.render.render(write_still=True)
            plate = bpy.data.images.load(scene.render.filepath)
            pixels = np.empty(WIDTH*HEIGHT*4,dtype=np.float32)
            plate.pixels.foreach_get(pixels)
            bottom = HEIGHT * (len(REGIONS)-1-row)
            rgba = pixels.reshape(HEIGHT, WIDTH, 4)
            # Byte image pixels carry the sRGB display values; the float atlas writes in linear light.
            rgb = rgba[:,:,:3]
            rgba[:,:,:3] = np.where(rgb <= .04045, rgb/12.92, ((rgb+.055)/1.055)**2.4)
            atlas[bottom:bottom+HEIGHT, col*WIDTH:(col+1)*WIDTH] = rgba

texture = bpy.data.images.new("Greybay specimen plates", width=WIDTH*2, height=HEIGHT*len(REGIONS),
                              alpha=True, float_buffer=True)
texture.pixels.foreach_set(atlas.ravel())
target = ROOT / "game/art/fieldguide/specimens.png"
target.parent.mkdir(parents=True,exist_ok=True)
texture.save_render(str(target), scene=bpy.context.scene)

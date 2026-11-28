extends SceneTree
## Run with Godot --headless --path game --script ../art_source/bake_bathymetry.gd.
## One texel covers one world metre. The red channel stores elevations -4 to +4 m.
const ORIGIN := Vector2(-492, -512)
const SIZE := Vector2i(1152, 1024)

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var world := preload("res://world/world.gd").new()
	root.add_child(world)
	var pixels := PackedByteArray()
	pixels.resize(SIZE.x * SIZE.y)
	for z in SIZE.y:
		for x in SIZE.x:
			var at := ORIGIN + Vector2(x + 0.5, z + 0.5)
			var height: float = world._expedition.terrain_height(at)
			pixels[z * SIZE.x + x] = roundi(clampf((height + 4.0) / 8.0, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(SIZE.x, SIZE.y, false, Image.FORMAT_L8, pixels)
	var error := image.save_png("res://art/terrain/coastal_bathymetry.png")
	world.free()
	quit(error)

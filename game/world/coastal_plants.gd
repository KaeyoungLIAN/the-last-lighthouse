extends RefCounted
## Reusable meadow, beach and wildflower silhouettes, batched in 24-metre patches.

enum Kind { MEADOW, DUNE, BLOOM, ROSETTE }

var _meshes: Array[ArrayMesh] = []
var _patches: Dictionary = {}

func load_meadow(world) -> void:
	for species in ["SeaBent", "Marram", "SeaThrift", "SeaKale"]:
		_meshes.append(world.landscape_mesh(species))

func _vertex(st: SurfaceTool, p: Vector3, normal: Vector3, color: Color) -> void:
	st.set_color(color.srgb_to_linear().lerp(color, .27))
	st.set_normal(normal)
	st.set_uv(Vector2(0, clampf(p.y * 1.5, 0, 1)))
	st.add_vertex(p)

func plant(kind: int, at: Vector3, scale_factor: float, angle: float) -> void:
	var key := Vector3i(floori(at.x / 24.0),kind,floori(at.z / 24.0))
	if not _patches.has(key):
		_patches[key] = []
	var transform := Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_factor),at)
	_patches[key].append(transform)

func finish(parent: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("coastal_grass.gdshader")
	for key: Vector3i in _patches:
		var transforms: Array = _patches[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _meshes[key.y]
		batch.instance_count = transforms.size()
		for i in transforms.size():
			batch.set_instance_transform(i,transforms[i])
		var patch := MultiMeshInstance3D.new()
		patch.name = "GroundCover_%s_%d_%s" % [key.x,key.y,key.z]
		patch.multimesh = batch
		patch.material_override = material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.visibility_range_end = 66.0
		patch.extra_cull_margin = .15
		parent.add_child(patch)

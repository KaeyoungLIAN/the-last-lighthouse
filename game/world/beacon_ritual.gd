extends RefCounted
## Triggered only by the act of lighting the register. Save restoration uses its static pose.
const Voyage = preload("res://expedition_voyage.gd")
const RESONANCE = preload("res://art/lighthouse/crest_resonance.gdshader")
const DURATION := 1.10

var _register: Node3D
var _plates: Array[MeshInstance3D] = []
var _filaments: Array[MeshInstance3D] = []
var _enamels: Array[ShaderMaterial] = []
var _currents: Array[ShaderMaterial] = []
var _lens: OmniLight3D
var _tween: Tween

func prepare(register: Node3D, lamp: OmniLight3D) -> void:
	_register = register
	_lens = lamp
	for glass_name in ["DormantGlass","LitGlass"]:
		var optical_glass := ShaderMaterial.new()
		optical_glass.shader = preload("res://art/lighthouse/fresnel_lens.gdshader")
		optical_glass.set_shader_parameter("burning",glass_name == "LitGlass")
		var optic := register.get_node(glass_name) as MeshInstance3D
		optic.material_override = optical_glass
	for id: String in Voyage.ORDER:
		var plate := register.get_node("Crest_" + id) as MeshInstance3D
		var filament := register.get_node("Filament_" + id) as MeshInstance3D
		var enamel := ShaderMaterial.new()
		enamel.shader = RESONANCE
		enamel.set_shader_parameter("enamel", Color(Voyage.COLORS[id]))
		var current := enamel.duplicate() as ShaderMaterial
		current.set_shader_parameter("filament", true)
		filament.material_override = current
		filament.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		filament.hide()
		_plates.append(plate)
		_filaments.append(filament)
		_enamels.append(enamel)
		_currents.append(current)

func play() -> void:
	stop()
	for i in _plates.size():
		_plates[i].material_overlay = _enamels[i]
		_filaments[i].visible = _plates[i].visible
	_frame(0.)
	_tween = _register.create_tween()
	_tween.tween_method(_frame, 0., DURATION, DURATION)
	_tween.tween_callback(_settle)

func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_settle()

func _frame(t: float) -> void:
	for i in _plates.size():
		var beat := t - i*.088
		var pulse := smoothstep(0.,.08,beat) * (1.-smoothstep(.115,.36,beat))
		_enamels[i].set_shader_parameter("pulse",pulse)
		var progress := (beat-.055)/.40
		_currents[i].set_shader_parameter("travel",progress)
		_currents[i].set_shader_parameter("pulse",smoothstep(-.13,.07,progress)*(1.-smoothstep(1.,1.28,progress)))
	_lens.light_energy = 1.7+4.1*smoothstep(.38,.83,t)*(1.-smoothstep(.88,DURATION,t))

func _settle() -> void:
	for i in _plates.size():
		_plates[i].material_overlay = null
		_filaments[i].hide()
	_lens.light_energy = 1.7

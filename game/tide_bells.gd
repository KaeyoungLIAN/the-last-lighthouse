extends Node3D
## A physical chime rack with a view of the ropes and a keyboard-accessible inscription.
const Art = preload("res://actors/actor_art.gd")
const STRIKE = preload("res://audio/tide_bell.wav")
const SITE := "cape_chimes"
const MELODY := [1,2,0]
const BIRDS := ["鸬鹚","沙鹬","海燕"]
const PITCHES := ["低音 · 晒翅膀","中音 · 在泥里找吃的","高音 · 贴着浪飞"]
const NOTES := [0.79,1.0,1.34]
const COLORS := ["6e998a","b68955","839dac"]

var spot: Vector2
var rig := Node3D.new()
var lens := Camera3D.new()
var bells: Array[Node3D] = []
var sounds: Array[AudioStreamPlayer] = []
var swings: Array[Tween] = []
var pennant: MeshInstance3D
var step := 0
var report: Label
var progress: Label
var choices: Array[Button] = []

func build(game) -> void:
	# The rack stands east of the playing spot, facing west towards the headland.
	var at: Vector2 = game.world.POINTS.get("bellcape",game.world.POINTS.tower)
	var offset := Vector2(3.2,0) if game.world.POINTS.has("bellcape") else Vector2(-6,1)
	spot = game._walkable_near(at+offset)
	add_child(rig)
	rig.position = game._ground(spot)+Vector3.RIGHT*.80
	rig.rotation.y = -PI*.5
	for side: float in [-1.0,1.0]:
		Art.taper(rig,Vector3(side*1.64,.16,0),.32,.28,.34,"7e8883")
		Art.block(rig,Vector3(side*1.64,1.49,0),Vector3(.19,2.7,.22),"785e43")
		Art.rod(rig,Vector3(side*1.64,2.21,0),Vector3(side*1.22,2.68,0),.065,.065,"9c805a")
	Art.block(rig,Vector3(0,2.72,0),Vector3(3.80,.22,.24),"675740")
	for i in 3:
		var hanger := Art.joint(rig,Vector3((i-1)*1.10,2.62,0))
		bells.append(hanger)
		swings.append(null)
		var size := 1.0-i*.18
		Art.rod(hanger,Vector3.ZERO,Vector3.DOWN*.37,.035,.031,"c0b189")
		var y := -.37
		Art.taper(hanger,Vector3.UP*(y-.10*size),.25*size,.12*size,.20*size,COLORS[i],12)
		Art.taper(hanger,Vector3.UP*(y-.35*size),.36*size,.25*size,.30*size,COLORS[i],12)
		Art.taper(hanger,Vector3.UP*(y-.16*size),.244*size,.23*size,.032*size,"c5ad77",12)
		Art.taper(hanger,Vector3.UP*(y-.43*size),.35*size,.34*size,.035*size,"927747",12)
		Art.taper(hanger,Vector3.UP*(y-.52*size),.41*size,.36*size,.09*size,"c2a36c",12)
		Art.oval(hanger,Vector3.UP*(y-.59*size),Vector3(.16,.18,.16)*size,"695d4c")
		var cord := Vector3(0,y-.33*size,.22*size)
		Art.rod(hanger,cord,Vector3(0,-1.66,.34),.021,.018,"ccb682")
		Art.oval(hanger,Vector3(0,-1.70,.34),Vector3(.09,.15,.09),"ad784b")
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.stream = STRIKE
		player.pitch_scale = NOTES[i]
		player.volume_db = -8
		sounds.append(player)
	pennant = Art.block(rig,Vector3(1.64,2.34,.15),Vector3(.23,.51,.045),"ca6948")
	pennant.visible = false
	add_child(lens)
	lens.fov = 56
	lens.set_cull_mask_value(2,false)
	lens.position = rig.position + Vector3(-5.6,1.92,-1.35)
	# Leave the right third of the view free for the inscription.
	lens.look_at(rig.position + Vector3(0,1.74,1.90),Vector3.UP)

func sync(flags: Array) -> void:
	if is_instance_valid(pennant):
		pennant.visible = flags.has("bell_song")

func open(game) -> void:
	step = 0
	game._show("tide_bells")
	lens.make_current()
	var hud = game.hud
	var align := MarginContainer.new()
	hud.menu.add_child(align)
	align.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	align.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	align.grow_vertical = Control.GROW_DIRECTION_BOTH
	align.offset_right = -20
	var card: PanelContainer = hud._panel(align,19,16)
	card.custom_minimum_size.x = minf(398,hud.base.size.x-40)
	var col: VBoxContainer = hud._column(card,8)
	hud._label(col,"潮钟岬 · 码头留言",15,hud.GOLD)
	hud._label(col,"船回来时怎么敲钟？",29)
	var done: bool = game.taken.has("bell_song")
	if done:
		hud._label(col,"码头的人听见了。每天可以打开地图，叫一次回村的船。",18,hud.INK,true)
		hud._button(col,"离开钟架 · Esc","resume",true)
		hud._bind_focus()
		return
	hud._label(col,"退潮了，先有只长嘴鸟在泥里找吃的。船刚开，就有只鸟贴着浪飞过来。等船回到码头，那只黑鸟才爬上木桩晒翅膀。",18,hud.INK,true)
	hud._label(col,"三根钟绳上各画了一只鸟。按它们出现的顺序拉绳。",15,hud.SOFT,true)
	progress = hud._label(col,"",18,hud.GOLD)
	report = hud._label(col,"",15,hud.SOFT,true)
	report.custom_minimum_size.y = 22
	choices.clear()
	for i in 3:
		var button: Button = hud._button(col,"%d   %s   ·   %s" % [i+1,BIRDS[i],PITCHES[i]],"tide_note_"+str(i))
		choices.append(button)
	hud._button(col,"放下钟绳 · Esc","resume")
	_refresh_score()
	hud._bind_focus()

func strike(index: int,game) -> void:
	if game.screen != "tide_bells" or game.taken.has("bell_song") or index<0 or index>=bells.size(): return
	var swing := swings[index]
	if swing and swing.is_valid(): swing.kill()
	var bell := bells[index]
	bell.rotation.z = -.14
	swing = create_tween()
	for amplitude: float in [.19,-.115,.068,-.033,0.0]:
		swing.tween_property(bell,"rotation:z",amplitude,.15).set_trans(Tween.TRANS_SINE)
	swings[index] = swing
	if DisplayServer.get_name() != "headless":
		sounds[index].play()
	if index != MELODY[step]:
		step = 0
		report.text = "这次顺序不对。先找退潮时在泥里找吃的那只鸟。"
	else:
		step += 1
		report.text = "%s的钟声穿过海雾。" % BIRDS[index]
	_refresh_score()
	if step==MELODY.size():
		game.taken.append("bell_song")
		game.iron += 2
		sync(game.taken)
		report.text = "顺序对了！你得到两块废铁。每天可以打开地图，叫一次回村的船。"
		for button in choices: button.disabled = true
		game.hud._bind_focus()
		game._save()

func _refresh_score() -> void:
	var syllables := PackedStringArray()
	for i in MELODY.size():
		syllables.append(BIRDS[MELODY[i]] if i<step else "◇")
	progress.text = "  ·  ".join(syllables)

func _exit_tree() -> void:
	for sound in sounds:
		sound.stop()

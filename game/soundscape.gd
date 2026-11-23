extends Node

const MUSIC := preload("res://audio/coast.wav")
const FX := {
	"hit":preload("res://audio/hit.wav"),"pickup":preload("res://audio/pickup.wav"),
	"switch":preload("res://audio/lever.wav"),"chime":preload("res://audio/chime.wav"),
	"discover":preload("res://audio/discover.wav"),"start":preload("res://audio/harbor.wav"),
	"win":preload("res://audio/relight.wav")
}
var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var voice := 0

func _ready() -> void:
	music.stream = MUSIC
	music.volume_db = -14
	add_child(music)
	music.finished.connect(music.play)
	if DisplayServer.get_name() != "headless":
		music.play()
	for i in 4:
		var fx := AudioStreamPlayer.new()
		fx.volume_db = -8
		add_child(fx)
		voices.append(fx)

func cue(id: String) -> void:
	if not FX.has(id) or DisplayServer.get_name() == "headless": return
	var fx := voices[voice]
	voice = (voice+1) % voices.size()
	fx.stream = FX[id]
	fx.play()

func _exit_tree() -> void:
	music.stop()
	for fx in voices:
		fx.stop()

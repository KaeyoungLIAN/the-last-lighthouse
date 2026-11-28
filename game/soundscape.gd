extends Node

const MUSIC := preload("res://audio/coast.wav")
const FX := {
	"blade":preload("res://audio/blade.wav"),"strong_hit":preload("res://audio/strong_hit.wav"),
	"shell":preload("res://audio/shell.wav"),"bow_loose":preload("res://audio/bow_loose.wav"),
	"hit":preload("res://audio/hit.wav"),"pickup":preload("res://audio/pickup.wav"),
	"switch":preload("res://audio/lever.wav"),"chime":preload("res://audio/chime.wav"),
	"discover":preload("res://audio/discover.wav"),"start":preload("res://audio/harbor.wav"),
	"win":preload("res://audio/relight.wav")
}
var music := AudioStreamPlayer.new()
var narrator := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var voice := 0

func _ready() -> void:
	music.stream = MUSIC
	music.volume_db = -14
	add_child(music)
	add_child(narrator)
	narrator.volume_db = -2
	narrator.finished.connect(func(): music.volume_db = -14)
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
	fx.pitch_scale = randf_range(.96,1.04) if id in ["hit","strong_hit","shell","blade","bow_loose"] else 1.
	fx.volume_db = -12. if id == "blade" else -8.
	fx.play()

func narrate(clip: AudioStream) -> void:
	end_narration()
	if clip == null or DisplayServer.get_name() == "headless": return
	narrator.stream = clip
	music.volume_db = -24
	narrator.play()

func end_narration() -> void:
	narrator.stop()
	music.volume_db = -14

func _exit_tree() -> void:
	narrator.stop()
	music.stop()
	for fx in voices:
		fx.stop()

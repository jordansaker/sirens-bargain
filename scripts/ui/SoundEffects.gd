class_name SoundEffects
extends Node

# Central SFX router. Consumers call `play("card_bank")` etc. — the actual
# audio files live under res://assets/audio/ and are looked up by name.
# Missing files are a silent no-op so shipping without audio still works;
# real audio can be dropped in later without any code change.
#
# To wire in real sounds: drop a .wav / .ogg / .mp3 into res://assets/audio/
# with one of the names below (any of the listed extensions works, first
# match wins).

const SOUND_DIR := "res://assets/audio/"
const EXTENSIONS: Array[String] = [".wav", ".ogg", ".mp3"]

# Named SFX events emitted by the UI. Add new hooks here to grow the palette.
const EVENTS: Array[String] = [
	"card_play",     # laid a realm card
	"card_bank",     # banked a card
	"action",        # played an action / tribute
	"turn_change",   # start of any turn
	"game_over",     # win condition triggered
]

var _players: Dictionary = {}   # event_name -> AudioStreamPlayer

func _ready() -> void:
	for event in EVENTS:
		var player := AudioStreamPlayer.new()
		player.name = "sfx_" + event
		add_child(player)
		var stream := _load_stream_for(event)
		if stream != null:
			player.stream = stream
		_players[event] = player

func play(event: String) -> void:
	if not _players.has(event):
		return
	var p: AudioStreamPlayer = _players[event]
	if p.stream == null:
		return
	p.play()

# Look up the first existing audio file for this event name across the
# supported extensions. Returns null if nothing is on disk yet.
func _load_stream_for(event: String) -> AudioStream:
	for ext in EXTENSIONS:
		var path := SOUND_DIR + event + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	return null

class_name MainMenu
extends Control

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"
const HOW_TO_PLAY_PATH := "res://scenes/HowToPlay.tscn"
const LOBBY_PATH := "res://scenes/LobbyScreen.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _online_button: Button = %OnlineButton
@onready var _how_to_play_button: Button = %HowToPlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_online_button.pressed.connect(_on_online_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_status_label.text = ""
	# Clear any leftover session in case we came back from an aborted match.
	_reset_net_session()

func _on_play_pressed() -> void:
	_reset_net_session()  # vs-AI mode
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

# Autoload access via node path — the autoload identifier isn't resolved by
# `godot -s` used in verify_scenes.gd, but /root/NetSession always exists at
# runtime.
func _reset_net_session() -> void:
	var ns := get_tree().root.get_node_or_null("NetSession")
	if ns != null and ns.has_method("reset"):
		ns.reset()

func _on_online_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_PATH)

func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file(HOW_TO_PLAY_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()

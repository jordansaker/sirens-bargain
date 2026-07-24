class_name MainMenu
extends Control

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"
const HOW_TO_PLAY_PATH := "res://scenes/HowToPlay.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _how_to_play_button: Button = %HowToPlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_status_label.text = ""

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file(HOW_TO_PLAY_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()

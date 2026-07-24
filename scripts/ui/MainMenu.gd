class_name MainMenu
extends Control

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_status_label.text = ""

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

func _on_settings_pressed() -> void:
	# Settings screen isn't part of Phase 7 — show a placeholder so the button
	# still gives feedback.
	_status_label.text = "Settings coming soon"

func _on_quit_pressed() -> void:
	get_tree().quit()

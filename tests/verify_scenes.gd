extends SceneTree

# Standalone loader: instantiates each phase-7 scene and reports parse errors.
# Not a GUT test — invoked directly with `godot --headless -s`. Exits 0 on
# success, 1 on any failure.

func _init() -> void:
	var scenes := [
		"res://scenes/CardView.tscn",
		"res://scenes/PlayerBoardView.tscn",
		"res://scenes/MainMenu.tscn",
		"res://scenes/HowToPlay.tscn",
		"res://scenes/GameScreen.tscn",
		"res://scenes/LobbyScreen.tscn",
	]
	var ok := true
	for path in scenes:
		var res := load(path)
		if res == null:
			printerr("FAIL: load returned null for ", path)
			ok = false
			continue
		if not (res is PackedScene):
			printerr("FAIL: not a PackedScene: ", path)
			ok = false
			continue
		var packed: PackedScene = res
		var inst := packed.instantiate()
		if inst == null:
			printerr("FAIL: instantiate returned null for ", path)
			ok = false
			continue
		# Adding to the root actually triggers _ready, so we catch runtime setup
		# errors (bad @onready paths, null unique-name lookups, etc.).
		root.add_child(inst)
		print("OK: ", path, " -> ", inst.get_class(), " '", inst.name, "'")
		inst.queue_free()
	quit(0 if ok else 1)

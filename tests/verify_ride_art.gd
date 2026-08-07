extends SceneTree

func _init() -> void:
	var cards := DeckBuilder.load_cards()
	for c in cards:
		if c.action_effect == "ride_the_current":
			print(c.id, " art_path=", c.art_path)
			var tex := CardView._load_card_art(c.art_path)
			if tex == null:
				printerr("  Failed to load: ", c.art_path)
			else:
				print("  OK - loaded ", tex.get_class(), " ", tex.get_width(), "x", tex.get_height())
			break
	quit()

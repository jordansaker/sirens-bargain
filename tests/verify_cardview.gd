extends SceneTree

# Instantiates a CardView with a Ride card and reports whether the art
# TextureRect got the texture. Runs headless — if this passes but the
# browser fails, the issue is on the web-runtime side.

func _init() -> void:
	var cards := DeckBuilder.load_cards()
	var ride: CardData = null
	for c in cards:
		if c.action_effect == "ride_the_current":
			ride = c
			break
	if ride == null:
		printerr("No ride card in deck")
		quit(1)
		return

	var view := CardView.new()
	root.add_child(view)
	view.card = ride
	# Give the tree a frame to process _ready.
	await process_frame

	if view.get("_art") == null:
		printerr("_art not built")
		quit(1)
		return
	var art: TextureRect = view.get("_art")
	print("art.visible=", art.visible, " texture=", art.texture)
	print("placeholder_col.visible=", view.get("_placeholder_col").visible)
	view.queue_free()
	quit(0 if art.texture != null and art.visible else 1)

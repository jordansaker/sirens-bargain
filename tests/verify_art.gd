extends SceneTree

# Sanity-check: every card that declares an art_path in cards.json actually
# resolves via ResourceLoader. If any card's art fails to load, print the id
# + path so we can find the mismatch.

func _init() -> void:
	var cards := DeckBuilder.load_cards()
	var missing := 0
	for c in cards:
		if c.art_path.is_empty():
			continue
		if not ResourceLoader.exists(c.art_path):
			printerr("MISSING: ", c.id, " -> ", c.art_path)
			missing += 1
			continue
		var tex: Resource = load(c.art_path)
		if tex == null or not (tex is Texture2D):
			printerr("BAD TEX: ", c.id, " -> ", c.art_path)
			missing += 1
	print("Checked ", cards.size(), " cards. Missing/bad art: ", missing)
	quit(0 if missing == 0 else 1)

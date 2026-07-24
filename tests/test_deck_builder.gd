extends GutTest

func test_deck_has_106_cards() -> void:
	var deck := DeckBuilder.build_deck()
	assert_eq(deck.size(), 106, "Deck should contain 106 cards")

func test_per_type_counts() -> void:
	var deck := DeckBuilder.build_deck()
	var counts := {}
	for c in deck:
		var t := CardData.type_to_string(c.type)
		counts[t] = int(counts.get(t, 0)) + 1
	assert_eq(int(counts.get("REALM", 0)), 28, "REALM count")
	assert_eq(int(counts.get("WILD_REALM", 0)), 11, "WILD_REALM count")
	assert_eq(int(counts.get("PEARL", 0)), 20, "PEARL count")
	assert_eq(int(counts.get("TRIBUTE", 0)), 13, "TRIBUTE count")
	assert_eq(int(counts.get("ACTION", 0)), 34, "ACTION count")

func test_per_realm_counts() -> void:
	var deck := DeckBuilder.build_deck()
	var counts := {}
	for c in deck:
		if c.type == CardData.Type.REALM:
			counts[c.realm] = int(counts.get(c.realm, 0)) + 1
	assert_eq(int(counts.get("Tide Pools", 0)), 2)
	assert_eq(int(counts.get("Kelp Forest", 0)), 3)
	assert_eq(int(counts.get("Coral Gardens", 0)), 3)
	assert_eq(int(counts.get("Pearl Beds", 0)), 3)
	assert_eq(int(counts.get("Shipwreck Cove", 0)), 3)
	assert_eq(int(counts.get("Sunken Temple", 0)), 3)
	assert_eq(int(counts.get("Seagrass Lagoon", 0)), 3)
	assert_eq(int(counts.get("Abyssal Trench", 0)), 2)
	assert_eq(int(counts.get("Ocean Currents", 0)), 4)
	assert_eq(int(counts.get("Mystic Springs", 0)), 2)

func test_ids_are_unique() -> void:
	var deck := DeckBuilder.build_deck()
	var seen := {}
	for c in deck:
		assert_false(seen.has(c.id), "Duplicate id: %s" % c.id)
		seen[c.id] = true

func test_rainbow_conch_cannot_be_banked() -> void:
	var deck := DeckBuilder.build_deck()
	var conches := 0
	for c in deck:
		if c.name == "Rainbow Conch":
			conches += 1
			assert_eq(c.value, 0, "Rainbow Conch should have value 0 (cannot bank)")
	assert_eq(conches, 2, "Should have 2 Rainbow Conches")

func test_shuffle_is_deterministic() -> void:
	var a := DeckBuilder.shuffle(DeckBuilder.build_deck(), 42)
	var b := DeckBuilder.shuffle(DeckBuilder.build_deck(), 42)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(a[i].id, b[i].id, "Same seed should give same order at index %d" % i)

func test_shuffle_changes_order() -> void:
	var deck := DeckBuilder.build_deck()
	var shuffled := DeckBuilder.shuffle(deck, 1)
	var same := true
	for i in range(deck.size()):
		if deck[i].id != shuffled[i].id:
			same = false
			break
	assert_false(same, "Shuffle should produce a different order")

func test_different_seeds_give_different_orders() -> void:
	var a := DeckBuilder.shuffle(DeckBuilder.build_deck(), 1)
	var b := DeckBuilder.shuffle(DeckBuilder.build_deck(), 2)
	var same := true
	for i in range(a.size()):
		if a[i].id != b[i].id:
			same = false
			break
	assert_false(same, "Different seeds should produce different orders")

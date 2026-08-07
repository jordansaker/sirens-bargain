extends GutTest

func _pearl(id: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "%d Pearl" % value
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _realm(id: String, realm: String, value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _tribute(id: String, realms: Array[String], value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Tribute"
	c.type = CardData.Type.TRIBUTE
	c.value = value
	c.realms = realms
	return c

func _sirens_toll(id: String = "toll_1") -> CardData:
	return _tribute(id, [] as Array[String], 3)

func _high_tide(id: String = "ht_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "High Tide"
	c.type = CardData.Type.ACTION
	c.value = 1
	c.action_effect = "high_tide"
	return c

func _cottage(id: String = "cottage_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Coral Cottage"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "coral_cottage"
	return c

func _palace(id: String = "palace_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Pearl Palace"
	c.type = CardData.Type.ACTION
	c.value = 4
	c.action_effect = "pearl_palace"
	return c

func _game(num_players: int) -> GameState:
	return GameState.new(num_players, [] as Array[CardData], 42)

func _stock_realm(p: PlayerState, realm: String, count: int) -> void:
	for i in range(count):
		var c := _realm("%s_p%d_%d" % [realm, p.id, i], realm)
		p.hand.append(c)
		p.play_realm(c, realm)

# ---- Standard tribute charges all opponents ----

func test_standard_tribute_charges_all_opponents() -> void:
	var gs := _game(3)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Sunken Temple", 3) # rent 6
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	charger.hand.append(trib)
	var owed := tm.charge_tribute(trib, "Sunken Temple")
	assert_eq(owed.size(), 2, "Both opponents owe")
	assert_eq(int(owed[1]), 6)
	assert_eq(int(owed[2]), 6)
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(trib), "Tribute goes to discard")

func test_tribute_rejects_realm_not_on_card() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Kelp Forest", 2)
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	charger.hand.append(trib)
	var owed := tm.charge_tribute(trib, "Kelp Forest")
	assert_true(owed.is_empty(), "Kelp Forest isn't on this tribute")
	assert_true(charger.hand.has(trib), "Rejected tribute stays in hand")
	assert_eq(tm.plays_this_turn, 0)

func test_tribute_requires_charger_to_own_the_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	charger.hand.append(trib)
	var owed := tm.charge_tribute(trib, "Sunken Temple")
	assert_true(owed.is_empty(), "Charger owns no Sunken Temple cards")
	assert_eq(tm.plays_this_turn, 0)

func test_tribute_rejects_realm_with_only_rainbow_conch() -> void:
	# Rainbow Conch alone doesn't establish ownership — you need at least
	# one real realm or wild card in the set to charge rent.
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	# Lay a Rainbow Conch (all-realm wild) into Sunken Temple.
	var conch := CardData.new()
	conch.id = "wild_rainbow_conch_test"
	conch.name = "Rainbow Conch"
	conch.type = CardData.Type.WILD_REALM
	conch.value = 0
	conch.realms = Realms.all_realms()
	charger.hand.append(conch)
	charger.play_realm(conch, "Sunken Temple")
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	charger.hand.append(trib)
	var owed := tm.charge_tribute(trib, "Sunken Temple")
	assert_true(owed.is_empty(), "Rainbow Conch alone can't anchor a tribute")
	assert_eq(tm.plays_this_turn, 0, "Play not consumed")
	assert_true(charger.hand.has(trib), "Tribute card stays in hand")

# ---- Siren's Toll ----

func test_sirens_toll_charges_one_chosen_player() -> void:
	var gs := _game(3)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Ocean Currents", 4) # complete, rent 4
	var toll := _sirens_toll()
	charger.hand.append(toll)
	var owed := tm.charge_tribute(toll, "Ocean Currents", 2)
	assert_eq(owed.size(), 1)
	assert_eq(int(owed[2]), 4)
	assert_false(owed.has(1), "Player 1 was not targeted")

func test_sirens_toll_works_on_any_realm_you_own() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Kelp Forest", 1) # rent 1
	var toll := _sirens_toll()
	charger.hand.append(toll)
	var owed := tm.charge_tribute(toll, "Kelp Forest", 1)
	assert_eq(int(owed[1]), 1)

func test_sirens_toll_requires_a_target() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Kelp Forest", 1)
	var toll := _sirens_toll()
	charger.hand.append(toll)
	var owed := tm.charge_tribute(toll, "Kelp Forest")
	assert_true(owed.is_empty(), "Siren's Toll needs an explicit target player")

func test_sirens_toll_cannot_target_charger() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Kelp Forest", 1)
	var toll := _sirens_toll()
	charger.hand.append(toll)
	var owed := tm.charge_tribute(toll, "Kelp Forest", 0)
	assert_true(owed.is_empty())

# ---- High Tide ----

func test_high_tide_doubles_rent_and_is_free() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Sunken Temple", 3) # rent 6 → 12 with High Tide
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	var ht := _high_tide()
	charger.hand.append_array([trib, ht])
	var owed := tm.charge_tribute(trib, "Sunken Temple", -1, ht)
	assert_eq(int(owed[1]), 12)
	# High Tide rides along with the tribute — only the tribute burns a play.
	assert_eq(tm.plays_this_turn, 1, "High Tide is a free rider on the tribute")
	assert_true(gs.discard_pile.has(ht), "High Tide goes to discard")

func test_high_tide_works_on_final_play() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Sunken Temple", 3)
	# Burn 2 plays first — one play left, and that's all a High-Tide-boosted
	# tribute needs (the tribute itself; High Tide is free).
	tm.plays_this_turn = 2
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	var ht := _high_tide()
	# Filler so removing both cards doesn't empty the hand and trigger the
	# reshuffle-and-refill that would pull them back out of the discard pile.
	charger.hand.append(_pearl("filler", 1))
	charger.hand.append_array([trib, ht])
	var owed := tm.charge_tribute(trib, "Sunken Temple", -1, ht)
	assert_eq(int(owed[1]), 12, "Doubled rent on the final play")
	assert_eq(tm.plays_this_turn, 3)
	assert_false(charger.hand.has(trib))
	assert_false(charger.hand.has(ht))

# ---- Cottage / Palace via TurnManager ----

func test_cottage_requires_completed_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Kelp Forest", 2) # incomplete
	var c := _cottage()
	charger.hand.append(c)
	assert_false(tm.play_coral_cottage(c, "Kelp Forest"))
	assert_true(charger.hand.has(c))
	assert_eq(tm.plays_this_turn, 0)

func test_cottage_attaches_and_boosts_rent() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Tide Pools", 2)
	var c := _cottage()
	charger.hand.append(c)
	assert_true(tm.play_coral_cottage(c, "Tide Pools"))
	assert_true(charger.has_cottage("Tide Pools"))
	assert_eq(RentCalculator.rent(charger, "Tide Pools"), 5)
	assert_eq(tm.plays_this_turn, 1)

func test_palace_requires_cottage() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Tide Pools", 2)
	var pl := _palace()
	charger.hand.append(pl)
	assert_false(tm.play_pearl_palace(pl, "Tide Pools"))
	assert_true(charger.hand.has(pl))

func test_palace_stacks_on_top_of_cottage() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Tide Pools", 2)
	var c := _cottage()
	var pl := _palace()
	charger.hand.append_array([c, pl])
	assert_true(tm.play_coral_cottage(c, "Tide Pools"))
	assert_true(tm.play_pearl_palace(pl, "Tide Pools"))
	assert_eq(RentCalculator.rent(charger, "Tide Pools"), 9)
	assert_eq(tm.plays_this_turn, 2)

# ---- End-to-end: tribute → payment ----

func test_charged_player_pays_via_payment_resolver() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	_stock_realm(charger, "Sunken Temple", 3) # rent 6
	victim.bank.append_array([
		_realm_as_pearl("v_p_1", 5),
		_realm_as_pearl("v_p_2", 2),
	])
	var trib := _tribute("t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String])
	charger.hand.append(trib)
	var owed := tm.charge_tribute(trib, "Sunken Temple")
	assert_eq(int(owed[1]), 6)
	var paid := PaymentResolver.settle_greedy(victim, charger, int(owed[1]))
	assert_eq(paid, 7, "5 + 2 covers 6 with 1 pearl of unavoidable overpay")
	assert_eq(victim.bank.size(), 0)
	assert_eq(charger.total_bank_value(), 7)

func _realm_as_pearl(id: String, value: int) -> CardData:
	# Helper: a plain pearl-style card for stocking a bank
	var c := CardData.new()
	c.id = id
	c.name = "%d Pearls" % value
	c.type = CardData.Type.PEARL
	c.value = value
	return c

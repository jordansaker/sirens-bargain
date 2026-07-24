extends GutTest

func _pearl(id: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test Pearl %s" % id
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _ride(id: String = "ride_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Ride the Current"
	c.type = CardData.Type.ACTION
	c.value = 1
	c.action_effect = "ride_the_current"
	return c

func _deck(size: int, start_index: int = 0) -> Array[CardData]:
	var d: Array[CardData] = []
	for i in range(size):
		d.append(_pearl("d%d" % (start_index + i)))
	return d

func _game(num_players: int, deck: Array[CardData]) -> GameState:
	return GameState.new(num_players, deck, 42)

# ---- Ride the Current ----

func test_ride_the_current_draws_two_cards() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	# Filler so removing Ride doesn't empty the hand and trigger the
	# empty-hand refill on top of Ride's own +2 draw.
	player.hand.append(_pearl("filler"))
	var ride := _ride()
	player.hand.append(ride)
	assert_true(tm.play_ride_the_current(ride))
	assert_eq(player.hand.size(), 3, "Card left hand, filler still there, 2 drawn")
	assert_false(player.hand.has(ride))

func test_ride_the_current_discards_the_action() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var ride := _ride()
	player.hand.append(ride)
	assert_true(tm.play_ride_the_current(ride))
	assert_true(gs.discard_pile.has(ride))

func test_ride_the_current_consumes_one_play() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var ride := _ride()
	player.hand.append(ride)
	tm.play_ride_the_current(ride)
	assert_eq(tm.plays_this_turn, 1)

func test_ride_the_current_blocked_when_no_plays_remaining() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var player := gs.current_player()
	var ride := _ride()
	player.hand.append(ride)
	assert_false(tm.play_ride_the_current(ride))
	assert_true(player.hand.has(ride))
	assert_eq(player.hand.size(), 1, "Nothing drawn")

func test_ride_the_current_rejects_card_not_in_hand() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var stray := _ride("stray")
	assert_false(tm.play_ride_the_current(stray))
	assert_eq(tm.plays_this_turn, 0)

func test_ride_the_current_rejects_wrong_action_card() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var fake := CardData.new()
	fake.id = "fake"
	fake.type = CardData.Type.ACTION
	fake.action_effect = "mermaids_feast"
	player.hand.append(fake)
	assert_false(tm.play_ride_the_current(fake))
	assert_true(player.hand.has(fake))

func test_ride_the_current_draws_what_it_can_when_deck_short() -> void:
	# Only 1 card in deck + discard combined
	var gs := _game(2, _deck(1))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var ride := _ride()
	player.hand.append(ride)
	assert_true(tm.play_ride_the_current(ride))
	# 1 drawn from deck, then deck+discard empty → only 1 total
	# (the played Ride card lands in discard AFTER the draw completes, so it
	# doesn't get reshuffled into this same draw.)
	assert_eq(player.hand.size(), 1, "Only 1 available to draw")

func test_ride_the_current_can_be_played_alongside_other_plays() -> void:
	var gs := _game(2, _deck(10))
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var ride := _ride()
	var seed := _pearl("seed", 2)
	player.hand.append_array([ride, seed])
	assert_true(tm.play_ride_the_current(ride))
	assert_true(tm.bank_card(seed))
	assert_eq(tm.plays_this_turn, 2)

# ---- Mermaid's Feast ----

func _feast(id: String = "feast_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Mermaid's Feast"
	c.type = CardData.Type.ACTION
	c.value = 2
	c.action_effect = "mermaids_feast"
	return c

func test_mermaids_feast_charges_every_opponent_two() -> void:
	var gs := _game(4, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var feast := _feast()
	charger.hand.append(feast)
	var owed := tm.play_mermaids_feast(feast)
	assert_eq(owed.size(), 3, "Every opponent owes")
	for pid in [1, 2, 3]:
		assert_eq(int(owed[pid]), 2)
	assert_false(owed.has(0), "Charger is not charged")

func test_mermaids_feast_two_player_game() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var feast := _feast()
	charger.hand.append(feast)
	var owed := tm.play_mermaids_feast(feast)
	assert_eq(owed.size(), 1)
	assert_eq(int(owed[1]), 2)

func test_mermaids_feast_consumes_one_play_and_discards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var feast := _feast()
	charger.hand.append(feast)
	tm.play_mermaids_feast(feast)
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(feast))
	assert_false(charger.hand.has(feast))

func test_mermaids_feast_rejects_when_no_plays_remaining() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var charger := gs.current_player()
	var feast := _feast()
	charger.hand.append(feast)
	var owed := tm.play_mermaids_feast(feast)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(feast))

func test_mermaids_feast_rejects_wrong_action_effect() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var wrong := _ride()
	charger.hand.append(wrong)
	var owed := tm.play_mermaids_feast(wrong)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(wrong))

func test_mermaids_feast_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var stray := _feast("stray")
	var owed := tm.play_mermaids_feast(stray)
	assert_true(owed.is_empty())
	assert_eq(tm.plays_this_turn, 0)

func test_mermaids_feast_broke_opponent_pays_nothing() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	var feast := _feast()
	charger.hand.append(feast)
	var owed := tm.play_mermaids_feast(feast)
	var paid := PaymentResolver.settle_greedy(victim, charger, int(owed[1]))
	assert_eq(paid, 0)
	assert_eq(charger.total_bank_value(), 0)

# ---- Toll of the Tides ----

func _toll(id: String = "toll_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Toll of the Tides"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "toll_of_the_tides"
	return c

func test_toll_charges_chosen_opponent_five() -> void:
	var gs := _game(3, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 2)
	assert_eq(owed.size(), 1)
	assert_eq(int(owed[2]), 5)
	assert_false(owed.has(1), "Only the chosen opponent is charged")

func test_toll_rejects_self_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 0)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(toll))
	assert_eq(tm.plays_this_turn, 0)

func test_toll_rejects_unknown_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 99)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(toll))

func test_toll_consumes_one_play_and_discards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var toll := _toll()
	charger.hand.append(toll)
	tm.play_toll_of_the_tides(toll, 1)
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(toll))
	assert_false(charger.hand.has(toll))

func test_toll_rejects_when_no_plays_remaining() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var charger := gs.current_player()
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 1)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(toll))

func test_toll_rejects_wrong_action_effect() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var wrong := _feast()
	charger.hand.append(wrong)
	var owed := tm.play_toll_of_the_tides(wrong, 1)
	assert_true(owed.is_empty())
	assert_true(charger.hand.has(wrong))

func test_toll_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var stray := _toll("stray")
	var owed := tm.play_toll_of_the_tides(stray, 1)
	assert_true(owed.is_empty())

func test_toll_broke_opponent_pays_partial() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	victim.bank.append(_pearl("v", 2))
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 1)
	assert_eq(int(owed[1]), 5)
	var paid := PaymentResolver.settle_greedy(victim, charger, int(owed[1]))
	assert_eq(paid, 2, "Broke victim pays what they have")
	assert_eq(charger.total_bank_value(), 2)
	assert_eq(victim.bank.size(), 0)

func test_toll_opponent_pays_full_via_settle_greedy() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	# Bank of [5, 3] → smallest-first takes 3 then 5, overpaying by 3.
	# This preserves the pattern (smallest coins go first) at the cost of
	# some overpay — the payer keeps high-denomination cards only when the
	# small change already covers the debt.
	victim.bank.append_array([_pearl("v1", 5), _pearl("v2", 3)])
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 1)
	var paid := PaymentResolver.settle_greedy(victim, charger, int(owed[1]))
	assert_eq(paid, 8, "Greedy takes smallest coins first, no change given")
	assert_eq(victim.bank.size(), 0)
	assert_eq(charger.total_bank_value(), 8)

func test_toll_opponent_keeps_big_coin_when_small_change_covers() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	victim.bank.append_array([_pearl("v_ten", 10), _pearl("v_five", 5)])
	var toll := _toll()
	charger.hand.append(toll)
	var owed := tm.play_toll_of_the_tides(toll, 1)
	var paid := PaymentResolver.settle_greedy(victim, charger, int(owed[1]))
	assert_eq(paid, 5, "5 exactly covers 5")
	assert_eq(victim.bank.size(), 1, "10-pearl preserved")

# ---- Slippery Eel ----

func _realm_card(id: String, realm: String, value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _wild_card(id: String, realms: Array[String], value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test Wild"
	c.type = CardData.Type.WILD_REALM
	c.value = value
	c.realms = realms
	return c

func _eel(id: String = "eel_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Slippery Eel"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "slippery_eel"
	return c

func _stock_realm(p: PlayerState, realm: String, count: int) -> void:
	for i in range(count):
		var c := _realm_card("%s_p%d_%d" % [realm, p.id, i], realm)
		p.hand.append(c)
		p.play_realm(c, realm)

func test_eel_steals_loose_realm_card() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2) # incomplete (needs 3)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	assert_true(tm.play_slippery_eel(eel, 1, stolen, "Kelp Forest"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 1)
	assert_eq((thief.realms["Kelp Forest"] as Array).size(), 1)
	assert_true((thief.realms["Kelp Forest"] as Array).has(stolen))

func test_eel_cannot_steal_from_completed_set() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3) # complete
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 1, stolen, "Kelp Forest"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 3, "Untouched")
	assert_false(thief.realms.has("Kelp Forest"))
	assert_true(thief.hand.has(eel), "Rejected eel stays in hand")
	assert_eq(tm.plays_this_turn, 0)

func test_eel_cannot_steal_card_not_owned_by_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var stray := _realm_card("stray", "Kelp Forest")
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 1, stray, "Kelp Forest"))
	assert_true(thief.hand.has(eel))

func test_eel_rejects_self_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	_stock_realm(thief, "Kelp Forest", 2)
	var own_card: CardData = (thief.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 0, own_card, "Kelp Forest"))
	assert_true(thief.hand.has(eel))

func test_eel_rejects_unknown_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 99, stolen, "Kelp Forest"))

func test_eel_can_flip_stolen_wild_to_different_realm() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	# Target lays a wild in Kelp Forest (incomplete: 1 wild, needs 3)
	var wild := _wild_card("w1", ["Kelp Forest", "Tide Pools"] as Array[String], 1)
	target.hand.append(wild)
	target.play_realm(wild, "Kelp Forest")
	var eel := _eel()
	thief.hand.append(eel)
	# Thief steals it and places under Tide Pools instead
	assert_true(tm.play_slippery_eel(eel, 1, wild, "Tide Pools"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 0)
	assert_eq((thief.realms["Tide Pools"] as Array).size(), 1)

func test_eel_rejects_wild_placed_in_incompatible_realm() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	var wild := _wild_card("w1", ["Kelp Forest", "Tide Pools"] as Array[String], 1)
	target.hand.append(wild)
	target.play_realm(wild, "Kelp Forest")
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 1, wild, "Sunken Temple"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 1, "Wild still there")
	assert_true(thief.hand.has(eel))

func test_eel_consumes_one_play_and_discards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	tm.play_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(eel))
	assert_false(thief.hand.has(eel))

func test_eel_rejects_when_no_plays_remaining() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	assert_false(tm.play_slippery_eel(eel, 1, stolen, "Kelp Forest"))
	assert_true(thief.hand.has(eel))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 2, "Untouched")

func test_eel_rejects_wrong_action_effect() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var wrong := _feast()
	thief.hand.append(wrong)
	assert_false(tm.play_slippery_eel(wrong, 1, stolen, "Kelp Forest"))
	assert_true(thief.hand.has(wrong))

func test_eel_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var stray := _eel("stray")
	assert_false(tm.play_slippery_eel(stray, 1, stolen, "Kelp Forest"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 2, "Untouched")

# ---- Trade Winds ----

func _trade(id: String = "trade_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Trade Winds"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "trade_winds"
	return c

func test_trade_winds_swaps_two_realm_cards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1) # incomplete
	_stock_realm(you, "Tide Pools", 1) # incomplete
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	assert_true(tm.play_trade_winds(
		trade, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_eq((me.realms["Kelp Forest"] as Array).size(), 0)
	assert_eq((you.realms["Kelp Forest"] as Array).size(), 1,
		"My Kelp went to you")
	assert_eq((me.realms["Tide Pools"] as Array).size(), 1,
		"Your Tide came to me")
	assert_eq((you.realms["Tide Pools"] as Array).size(), 0)

func test_trade_winds_refuses_when_own_side_completed() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 3) # completed
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_eq((me.realms["Kelp Forest"] as Array).size(), 3, "Untouched")
	assert_true(me.hand.has(trade))
	assert_eq(tm.plays_this_turn, 0)

func test_trade_winds_refuses_when_their_side_completed() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 2) # completed (Tide Pools needs 2)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_eq((you.realms["Tide Pools"] as Array).size(), 2, "Untouched")

func test_trade_winds_refuses_incompatible_destination_for_own_card() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	# Try to send a plain Kelp Forest card to "Sunken Temple" on the target
	assert_false(tm.play_trade_winds(
		trade, 1, mine, "Sunken Temple", theirs, "Tide Pools"
	))
	assert_eq((me.realms["Kelp Forest"] as Array).size(), 1, "Untouched")

func test_trade_winds_wild_can_flip_to_new_realm_on_receiver() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	# My wild lives in Kelp Forest; I'll trade it to you as Tide Pools
	var wild := _wild_card("w1", ["Kelp Forest", "Tide Pools"] as Array[String], 1)
	me.hand.append(wild)
	me.play_realm(wild, "Kelp Forest")
	_stock_realm(you, "Coral Gardens", 1)
	var theirs: CardData = (you.realms["Coral Gardens"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	assert_true(tm.play_trade_winds(
		trade, 1, wild, "Tide Pools", theirs, "Coral Gardens"
	))
	assert_eq((you.realms["Tide Pools"] as Array).size(), 1,
		"Wild landed under Tide Pools on receiver's side")
	assert_eq((me.realms["Coral Gardens"] as Array).size(), 1)

func test_trade_winds_rejects_self_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	_stock_realm(me, "Kelp Forest", 2)
	var stack: Array = me.realms["Kelp Forest"]
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 0, stack[0], "Kelp Forest", stack[1], "Kelp Forest"
	))
	assert_true(me.hand.has(trade))

func test_trade_winds_rejects_unknown_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	_stock_realm(me, "Kelp Forest", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var stray := _realm_card("stray", "Tide Pools")
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 99, mine, "Kelp Forest", stray, "Tide Pools"
	))

func test_trade_winds_rejects_card_not_owned_by_initiator() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(you, "Tide Pools", 1)
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var stray := _realm_card("stray", "Kelp Forest")
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 1, stray, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_true(me.hand.has(trade))

func test_trade_winds_rejects_card_not_owned_by_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	_stock_realm(me, "Kelp Forest", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var stray := _realm_card("stray", "Tide Pools")
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 1, mine, "Tide Pools", stray, "Kelp Forest"
	))
	assert_true(me.hand.has(trade))

func test_trade_winds_consumes_one_play_and_discards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	tm.play_trade_winds(trade, 1, mine, "Kelp Forest", theirs, "Tide Pools")
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(trade))
	assert_false(me.hand.has(trade))

func test_trade_winds_rejects_when_no_plays_remaining() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	assert_false(tm.play_trade_winds(
		trade, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_true(me.hand.has(trade))
	assert_eq((me.realms["Kelp Forest"] as Array).size(), 1, "Untouched")

func test_trade_winds_rejects_wrong_action_effect() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var wrong := _feast()
	me.hand.append(wrong)
	assert_false(tm.play_trade_winds(
		wrong, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))
	assert_true(me.hand.has(wrong))

func test_trade_winds_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var stray := _trade("stray")
	assert_false(tm.play_trade_winds(
		stray, 1, mine, "Kelp Forest", theirs, "Tide Pools"
	))

# ---- Kraken's Grasp ----

func _kraken(id: String = "kraken_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Kraken's Grasp"
	c.type = CardData.Type.ACTION
	c.value = 5
	c.action_effect = "krakens_grasp"
	return c

func _cottage_card(id: String = "cottage_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Coral Cottage"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "coral_cottage"
	return c

func _palace_card(id: String = "palace_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Pearl Palace"
	c.type = CardData.Type.ACTION
	c.value = 4
	c.action_effect = "pearl_palace"
	return c

func test_kraken_steals_completed_realm() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3) # complete
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_true(tm.play_krakens_grasp(kraken, 1, "Kelp Forest"))
	assert_eq((thief.realms["Kelp Forest"] as Array).size(), 3)
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 0)
	assert_true(thief.is_realm_complete("Kelp Forest"))

func test_kraken_refuses_incomplete_realm() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2) # incomplete
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_false(tm.play_krakens_grasp(kraken, 1, "Kelp Forest"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 2, "Untouched")
	assert_true(thief.hand.has(kraken))
	assert_eq(tm.plays_this_turn, 0)

func test_kraken_refuses_realm_target_does_not_own() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_false(tm.play_krakens_grasp(kraken, 1, "Kelp Forest"))
	assert_true(thief.hand.has(kraken))

func test_kraken_rejects_self_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	_stock_realm(thief, "Kelp Forest", 3)
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_false(tm.play_krakens_grasp(kraken, 0, "Kelp Forest"))
	assert_true(thief.hand.has(kraken))

func test_kraken_rejects_unknown_target() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_false(tm.play_krakens_grasp(kraken, 99, "Kelp Forest"))

func test_kraken_transfers_cottage_and_palace_with_the_set() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Tide Pools", 2) # complete (Tide Pools needs 2)
	var cottage := _cottage_card()
	var palace := _palace_card()
	target.hand.append_array([cottage, palace])
	target.attach_modifier(cottage, "Tide Pools")
	target.attach_modifier(palace, "Tide Pools")
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_true(tm.play_krakens_grasp(kraken, 1, "Tide Pools"))
	assert_true(thief.has_cottage("Tide Pools"))
	assert_true(thief.has_palace("Tide Pools"))
	assert_false(target.has_cottage("Tide Pools"))
	assert_false(target.has_palace("Tide Pools"))
	# Rent should compute using thief's new set + modifiers
	# Tide Pools base rent for 2 = 2, +3 cottage +4 palace = 9
	assert_eq(RentCalculator.rent(thief, "Tide Pools"), 9)

func test_kraken_duplicate_cottage_goes_to_discard() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	# Both players have a completed Tide Pools with a cottage
	_stock_realm(thief, "Tide Pools", 2)
	_stock_realm(target, "Tide Pools", 2)
	var thief_cottage := _cottage_card("thief_cottage")
	thief.hand.append(thief_cottage)
	thief.attach_modifier(thief_cottage, "Tide Pools")
	var target_cottage := _cottage_card("target_cottage")
	target.hand.append(target_cottage)
	target.attach_modifier(target_cottage, "Tide Pools")
	# Reset play counter so the Kraken's play is legal
	tm.plays_this_turn = 0
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_true(tm.play_krakens_grasp(kraken, 1, "Tide Pools"))
	# Thief still has just one cottage on Tide Pools (the duplicate went away)
	var mods: Array = thief.realm_modifiers["Tide Pools"]
	var cottage_count := 0
	for m in mods:
		if m.action_effect == "coral_cottage":
			cottage_count += 1
	assert_eq(cottage_count, 1, "Duplicate cottage dropped, not stacked")
	assert_true(gs.discard_pile.has(target_cottage))

func test_kraken_can_trigger_win_condition() -> void:
	var gs := _game(3, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(thief, "Tide Pools", 2)
	_stock_realm(thief, "Mystic Springs", 2)
	_stock_realm(target, "Kelp Forest", 3)
	assert_eq(gs.winner(), -1)
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_true(tm.play_krakens_grasp(kraken, 1, "Kelp Forest"))
	assert_eq(gs.winner(), 0)
	assert_true(gs.is_game_over())

func test_kraken_consumes_one_play_and_discards() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3)
	var kraken := _kraken()
	thief.hand.append(kraken)
	tm.play_krakens_grasp(kraken, 1, "Kelp Forest")
	assert_eq(tm.plays_this_turn, 1)
	assert_true(gs.discard_pile.has(kraken))
	assert_false(thief.hand.has(kraken))

func test_kraken_rejects_when_no_plays_remaining() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	tm.plays_this_turn = 3
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3)
	var kraken := _kraken()
	thief.hand.append(kraken)
	assert_false(tm.play_krakens_grasp(kraken, 1, "Kelp Forest"))
	assert_true(thief.hand.has(kraken))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 3, "Untouched")

func test_kraken_rejects_wrong_action_effect() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3)
	var wrong := _feast()
	thief.hand.append(wrong)
	assert_false(tm.play_krakens_grasp(wrong, 1, "Kelp Forest"))
	assert_true(thief.hand.has(wrong))

func test_kraken_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3)
	var stray := _kraken("stray")
	assert_false(tm.play_krakens_grasp(stray, 1, "Kelp Forest"))
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 3, "Untouched")

func test_mermaids_feast_opponent_pays_via_settle_greedy() -> void:
	var gs := _game(3, [] as Array[CardData])
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var v1 := gs.players[1]
	var v2 := gs.players[2]
	v1.bank.append(_pearl("v1a", 2))
	v2.bank.append_array([_pearl("v2a", 1), _pearl("v2b", 1)])
	var feast := _feast()
	charger.hand.append(feast)
	var owed := tm.play_mermaids_feast(feast)
	assert_eq(PaymentResolver.settle_greedy(v1, charger, int(owed[1])), 2)
	assert_eq(PaymentResolver.settle_greedy(v2, charger, int(owed[2])), 2)
	assert_eq(charger.total_bank_value(), 4)
	assert_eq(v1.bank.size(), 0)
	assert_eq(v2.bank.size(), 0)

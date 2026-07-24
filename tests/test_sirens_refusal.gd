extends GutTest

func _realm_card(id: String, realm: String, value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _pearl(id: String, value: int) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "%d Pearls" % value
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _refusal(id: String = "ref_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Siren's Refusal"
	c.type = CardData.Type.ACTION
	c.value = 4
	c.action_effect = "sirens_refusal"
	return c

func _eel(id: String = "eel_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Slippery Eel"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "slippery_eel"
	return c

func _trade(id: String = "trade_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Trade Winds"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "trade_winds"
	return c

func _kraken(id: String = "kraken_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Kraken's Grasp"
	c.type = CardData.Type.ACTION
	c.value = 5
	c.action_effect = "krakens_grasp"
	return c

func _toll(id: String = "toll_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Toll of the Tides"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "toll_of_the_tides"
	return c

func _feast(id: String = "feast_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Mermaid's Feast"
	c.type = CardData.Type.ACTION
	c.value = 2
	c.action_effect = "mermaids_feast"
	return c

func _ride(id: String = "ride_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Ride the Current"
	c.type = CardData.Type.ACTION
	c.value = 1
	c.action_effect = "ride_the_current"
	return c

func _cottage_card(id: String = "cottage_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Coral Cottage"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "coral_cottage"
	return c

func _tribute(id: String, realms: Array[String], value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Tribute"
	c.type = CardData.Type.TRIBUTE
	c.value = value
	c.realms = realms
	return c

func _game(num_players: int) -> GameState:
	return GameState.new(num_players, [] as Array[CardData], 42)

func _stock_realm(p: PlayerState, realm: String, count: int) -> void:
	for i in range(count):
		var c := _realm_card("%s_p%d_%d" % [realm, p.id, i], realm)
		p.hand.append(c)
		p.play_realm(c, realm)

# ---- Cancels a Slippery Eel ----

func test_refusal_cancels_slippery_eel() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	# Filler cards so neither hand goes empty when the eel/refusal is spent —
	# an empty hand would trigger the auto-refill, which reshuffles the
	# discard back into the draw pile and pulls the just-played eel out.
	thief.hand.append(_pearl("thief_filler", 1))
	target.hand.append(_pearl("target_filler", 1))
	var eel := _eel()
	thief.hand.append(eel)
	var refusal := _refusal()
	target.hand.append(refusal)

	var pending := tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_not_null(pending)
	assert_true(tm.refuse(1, 1, refusal))
	var result: Variant = tm.resolve_pending()
	assert_eq(result, false, "Effect blocked by refusal")

	assert_eq((target.realms["Kelp Forest"] as Array).size(), 2,
		"Target still owns both cards")
	assert_false(thief.realms.has("Kelp Forest"),
		"Thief never received the card")
	assert_true(gs.discard_pile.has(refusal), "Refusal spent regardless")
	assert_true(gs.discard_pile.has(eel), "Eel spent regardless")
	assert_null(gs.pending_action, "Pending cleared")
	assert_eq(tm.plays_this_turn, 1, "Play consumed even on refusal")

# ---- Stack alternation: refuse + counter → effect proceeds ----

func test_refusal_counter_refusal_allows_effect_through() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	# Filler so no side goes empty — see rationale in the sibling test above.
	thief.hand.append(_pearl("thief_filler", 1))
	target.hand.append(_pearl("target_filler", 1))
	var eel := _eel()
	thief.hand.append(eel)
	var target_ref := _refusal("target_ref")
	target.hand.append(target_ref)
	var thief_ref := _refusal("thief_ref")
	thief.hand.append(thief_ref)

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_true(tm.refuse(1, 1, target_ref), "Target refuses")
	assert_true(tm.refuse(1, 0, thief_ref), "Initiator counter-refuses")
	var result: Variant = tm.resolve_pending()
	assert_eq(result, true, "Even-height stack lets the effect through")

	assert_eq((thief.realms["Kelp Forest"] as Array).size(), 1)
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 1)
	assert_true(gs.discard_pile.has(target_ref))
	assert_true(gs.discard_pile.has(thief_ref))

func test_three_refusals_cancel_the_effect_again() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var t1 := _refusal("t1")
	var t2 := _refusal("t2")
	var i1 := _refusal("i1")
	target.hand.append_array([t1, t2])
	thief.hand.append(i1)

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_true(tm.refuse(1, 1, t1), "Target refuses")
	assert_true(tm.refuse(1, 0, i1), "Initiator counters")
	assert_true(tm.refuse(1, 1, t2), "Target counter-counters")
	var result: Variant = tm.resolve_pending()
	assert_eq(result, false, "Odd stack cancels")
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 2, "Untouched")

# ---- Alternation enforcement ----

func test_target_cannot_refuse_twice_in_a_row() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var t1 := _refusal("t1")
	var t2 := _refusal("t2")
	target.hand.append_array([t1, t2])

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_true(tm.refuse(1, 1, t1))
	assert_false(tm.refuse(1, 1, t2), "Target can't skip the initiator's counter")
	assert_true(target.hand.has(t2), "Rejected refusal stays in hand")

func test_initiator_cannot_refuse_first() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var ref := _refusal()
	thief.hand.append(ref)

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_false(tm.refuse(1, 0, ref),
		"Initiator can only counter after the target refuses")
	assert_true(thief.hand.has(ref))

# ---- refuse() input validation ----

func test_refuse_rejects_wrong_action_effect() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var not_a_refusal := _pearl("nope", 1)
	target.hand.append(not_a_refusal)

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_false(tm.refuse(1, 1, not_a_refusal))
	assert_true(target.hand.has(not_a_refusal))

func test_refuse_rejects_card_not_in_refusers_hand() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var stray := _refusal("stray")

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	assert_false(tm.refuse(1, 1, stray))

func test_refuse_rejects_when_no_pending_action() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var target := gs.players[1]
	var ref := _refusal()
	target.hand.append(ref)
	assert_false(tm.refuse(1, 1, ref))
	assert_true(target.hand.has(ref))

func test_refuse_rejects_target_id_not_in_pending() -> void:
	var gs := _game(3)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 2)
	var stolen: CardData = (target.realms["Kelp Forest"] as Array)[0]
	var eel := _eel()
	thief.hand.append(eel)
	var bystander := gs.players[2]
	var ref := _refusal()
	bystander.hand.append(ref)

	tm.initiate_slippery_eel(eel, 1, stolen, "Kelp Forest")
	# Player 2 isn't in pending.targets — can't refuse "on behalf of" 2
	assert_false(tm.refuse(2, 2, ref))
	assert_true(bystander.hand.has(ref))

# ---- Per-target refusal (Mermaid's Feast) ----

func test_per_target_refusal_on_mermaids_feast() -> void:
	var gs := _game(3)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var p1 := gs.players[1]
	var p2 := gs.players[2]
	var feast := _feast()
	charger.hand.append(feast)
	var p1_ref := _refusal("p1_ref")
	p1.hand.append(p1_ref)

	var pending := tm.initiate_mermaids_feast(feast)
	assert_not_null(pending)
	assert_true(tm.refuse(1, 1, p1_ref), "P1 refuses their share")
	# P2 does not refuse
	var owed: Variant = tm.resolve_pending()
	assert_true(owed is Dictionary)
	var owed_dict: Dictionary = owed
	assert_false(owed_dict.has(1), "P1 owes nothing after cancelling")
	assert_eq(int(owed_dict[2]), 2, "P2 still owes 2")

func test_per_target_refusal_on_standard_tribute() -> void:
	var gs := _game(3)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	_stock_realm(charger, "Sunken Temple", 3) # rent 6
	var p1 := gs.players[1]
	var trib := _tribute(
		"t1", ["Shipwreck Cove", "Sunken Temple"] as Array[String]
	)
	charger.hand.append(trib)
	var ref := _refusal()
	p1.hand.append(ref)

	tm.initiate_tribute(trib, "Sunken Temple")
	assert_true(tm.refuse(1, 1, ref))
	var owed: Variant = tm.resolve_pending()
	var owed_dict: Dictionary = owed
	assert_false(owed_dict.has(1))
	assert_eq(int(owed_dict[2]), 6)

# ---- Trade Winds, Kraken's Grasp, Toll ----

func test_refusal_cancels_trade_winds() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var me := gs.current_player()
	var you := gs.players[1]
	_stock_realm(me, "Kelp Forest", 1)
	_stock_realm(you, "Tide Pools", 1)
	var mine: CardData = (me.realms["Kelp Forest"] as Array)[0]
	var theirs: CardData = (you.realms["Tide Pools"] as Array)[0]
	var trade := _trade()
	me.hand.append(trade)
	var ref := _refusal()
	you.hand.append(ref)

	tm.initiate_trade_winds(trade, 1, mine, "Kelp Forest", theirs, "Tide Pools")
	assert_true(tm.refuse(1, 1, ref))
	var result: Variant = tm.resolve_pending()
	assert_eq(result, false)
	assert_eq((me.realms["Kelp Forest"] as Array).size(), 1, "Nobody swapped")
	assert_eq((you.realms["Tide Pools"] as Array).size(), 1)

func test_refusal_cancels_krakens_grasp() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var thief := gs.current_player()
	var target := gs.players[1]
	_stock_realm(target, "Kelp Forest", 3)
	var kraken := _kraken()
	thief.hand.append(kraken)
	var ref := _refusal()
	target.hand.append(ref)

	tm.initiate_krakens_grasp(kraken, 1, "Kelp Forest")
	assert_true(tm.refuse(1, 1, ref))
	var result: Variant = tm.resolve_pending()
	assert_eq(result, false)
	assert_eq((target.realms["Kelp Forest"] as Array).size(), 3, "Set stays")
	assert_false(thief.realms.has("Kelp Forest"))

func test_refusal_cancels_toll() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	var toll := _toll()
	charger.hand.append(toll)
	var ref := _refusal()
	victim.hand.append(ref)

	tm.initiate_toll_of_the_tides(toll, 1)
	assert_true(tm.refuse(1, 1, ref))
	var owed: Variant = tm.resolve_pending()
	var owed_dict: Dictionary = owed
	assert_false(owed_dict.has(1), "No debt after refusal")

# ---- Refusal does NOT consume plays ----

func test_refusal_does_not_consume_charger_plays() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	var toll := _toll()
	charger.hand.append(toll)
	var ref := _refusal()
	victim.hand.append(ref)

	tm.initiate_toll_of_the_tides(toll, 1)
	assert_eq(tm.plays_this_turn, 1)
	tm.refuse(1, 1, ref)
	assert_eq(tm.plays_this_turn, 1, "Refusal is reactive, not a play")
	tm.resolve_pending()
	assert_eq(tm.plays_this_turn, 1)

# ---- Unrefusable actions have no pending window ----

func test_ride_the_current_leaves_no_pending() -> void:
	var deck: Array[CardData] = []
	for i in range(4):
		deck.append(_pearl("d%d" % i, 1))
	var gs := GameState.new(2, deck, 42)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var ride := _ride()
	player.hand.append(ride)
	tm.play_ride_the_current(ride)
	assert_null(gs.pending_action, "Ride the Current has no refusal window")

func test_coral_cottage_leaves_no_pending() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	_stock_realm(player, "Tide Pools", 2) # complete
	var cot := _cottage_card()
	player.hand.append(cot)
	tm.play_coral_cottage(cot, "Tide Pools")
	assert_null(gs.pending_action, "Cottage attachment is not refusable")

# ---- Payment integration ----

func test_refused_toll_needs_no_payment() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var charger := gs.current_player()
	var victim := gs.players[1]
	victim.bank.append(_pearl("v1", 5))
	var toll := _toll()
	charger.hand.append(toll)
	var ref := _refusal()
	victim.hand.append(ref)

	tm.initiate_toll_of_the_tides(toll, 1)
	tm.refuse(1, 1, ref)
	var owed: Variant = tm.resolve_pending()
	var owed_dict: Dictionary = owed
	# Nothing to settle
	var paid := PaymentResolver.settle_greedy(
		victim, charger, int(owed_dict.get(1, 0))
	)
	assert_eq(paid, 0)
	assert_eq(victim.bank.size(), 1, "Bank untouched")
	assert_eq(charger.total_bank_value(), 0)

# ---- resolve_pending on empty ----

func test_resolve_pending_returns_null_when_nothing_pending() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var r: Variant = tm.resolve_pending()
	assert_null(r)

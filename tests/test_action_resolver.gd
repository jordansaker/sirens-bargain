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
	var ride := _ride()
	player.hand.append(ride)
	assert_true(tm.play_ride_the_current(ride))
	assert_eq(player.hand.size(), 2, "Card left hand, 2 drawn")
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

extends GutTest

func _pearl(id: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test Pearl %s" % id
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _deck(size: int, start_index: int = 0) -> Array[CardData]:
	var d: Array[CardData] = []
	for i in range(size):
		d.append(_pearl("p%d" % (start_index + i), 1))
	return d

func _game(num_players: int, deck: Array[CardData]) -> GameState:
	return GameState.new(num_players, deck, 42)

func test_start_turn_draws_two_when_hand_not_empty() -> void:
	var gs := _game(2, _deck(20))
	var tm := TurnManager.new(gs)
	# Seed hand with one card so it's not empty
	gs.current_player().hand.append(_pearl("seed"))
	tm.start_turn()
	assert_eq(gs.current_player().hand.size(), 3, "Should have seed + 2 drawn = 3")

func test_start_turn_draws_five_when_hand_empty() -> void:
	var gs := _game(2, _deck(20))
	var tm := TurnManager.new(gs)
	tm.start_turn()
	assert_eq(gs.current_player().hand.size(), 5, "Empty hand draws 5")

func test_three_play_limit_enforced() -> void:
	var gs := _game(2, _deck(20))
	var tm := TurnManager.new(gs)
	tm.start_turn()
	var player := gs.current_player()
	assert_eq(player.hand.size(), 5)
	var c1 := player.hand[0]
	var c2 := player.hand[1]
	var c3 := player.hand[2]
	var c4 := player.hand[3]
	assert_true(tm.bank_card(c1), "1st bank should succeed")
	assert_true(tm.bank_card(c2), "2nd bank should succeed")
	assert_true(tm.bank_card(c3), "3rd bank should succeed")
	assert_false(tm.bank_card(c4), "4th bank should be blocked")
	assert_eq(player.bank.size(), 3, "Bank should have 3 cards")
	assert_true(player.hand.has(c4), "Blocked card should still be in hand")

func test_bank_card_removes_from_hand_and_updates_value() -> void:
	var gs := _game(2, [])
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var a := _pearl("a", 3)
	var b := _pearl("b", 5)
	player.hand.append(a)
	player.hand.append(b)
	assert_true(tm.bank_card(a))
	assert_true(tm.bank_card(b))
	assert_eq(player.hand.size(), 0)
	assert_eq(player.bank.size(), 2)
	assert_eq(player.total_bank_value(), 8)

func test_bank_card_rejects_card_not_in_hand() -> void:
	var gs := _game(2, [])
	var tm := TurnManager.new(gs)
	var stray := _pearl("stray")
	assert_false(tm.bank_card(stray), "Should not bank a card that's not in hand")

func test_end_turn_requires_discard_when_over_seven() -> void:
	var gs := _game(2, [])
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	for i in range(10):
		player.hand.append(_pearl("h%d" % i))
	assert_eq(player.hand.size(), 10)
	var to_discard: Array[CardData] = [player.hand[0], player.hand[1], player.hand[2]]
	tm.end_turn(to_discard)
	assert_eq(gs.players[0].hand.size(), 7, "Hand should be trimmed to 7")
	assert_eq(gs.discard_pile.size(), 3, "3 cards should be in discard pile")
	assert_eq(gs.current_player_index, 1, "Turn should advance to player 1")

func test_end_turn_advances_player() -> void:
	var gs := _game(3, _deck(30))
	var tm := TurnManager.new(gs)
	tm.start_turn()
	tm.end_turn()
	assert_eq(gs.current_player_index, 1)
	tm.start_turn()
	tm.end_turn()
	assert_eq(gs.current_player_index, 2)
	tm.start_turn()
	tm.end_turn()
	assert_eq(gs.current_player_index, 0, "Should wrap around")

func test_end_turn_resets_play_counter_next_turn() -> void:
	var gs := _game(2, _deck(30))
	var tm := TurnManager.new(gs)
	tm.start_turn()
	var p0 := gs.current_player()
	assert_true(tm.bank_card(p0.hand[0]))
	assert_true(tm.bank_card(p0.hand[0]))
	assert_true(tm.bank_card(p0.hand[0]))
	assert_false(tm.bank_card(p0.hand[0]))
	tm.end_turn()
	assert_eq(gs.current_player_index, 1)
	tm.start_turn()
	assert_eq(tm.plays_this_turn, 0, "Play counter should reset")
	var p1 := gs.current_player()
	assert_true(tm.bank_card(p1.hand[0]))

func test_reshuffle_discard_into_draw_when_empty() -> void:
	var deck := _deck(4)
	var gs := _game(1, deck)
	# Empty the draw pile into a fake "already played" state by moving cards to discard
	gs.discard_pile = gs.draw_pile.duplicate()
	gs.draw_pile.clear()
	assert_eq(gs.draw_pile.size(), 0)
	assert_eq(gs.discard_pile.size(), 4)
	var card := gs.draw_card()
	assert_not_null(card, "Should reshuffle discard and draw a card")
	assert_eq(gs.discard_pile.size(), 0, "Discard should be empty after reshuffle")
	assert_eq(gs.draw_pile.size(), 3, "Draw pile should have 3 remaining")

func test_draw_returns_null_when_both_piles_empty() -> void:
	var gs := _game(1, [])
	assert_null(gs.draw_card())

func test_start_turn_stops_when_deck_and_discard_exhausted() -> void:
	# Only 1 card total, empty hand → asks for 5, gets 1
	var gs := _game(1, _deck(1))
	var tm := TurnManager.new(gs)
	tm.start_turn()
	assert_eq(gs.current_player().hand.size(), 1)

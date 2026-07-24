extends GutTest

func _realm(id: String, realm: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s Realm" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _wild(id: String, realms: Array[String], value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test Wild"
	c.type = CardData.Type.WILD_REALM
	c.value = value
	c.realms = realms
	return c

func _rainbow_conch(id: String = "wild_rainbow_conch_01") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Rainbow Conch"
	c.type = CardData.Type.WILD_REALM
	c.value = 0
	c.realms = Realms.all_realms()
	return c

func _pearl(id: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Pearl"
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _game(num_players: int) -> GameState:
	return GameState.new(num_players, [] as Array[CardData], 42)

# ---- Playing a REALM card ----

func test_playing_realm_places_it_under_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var card := _realm("r1", "Kelp Forest")
	player.hand.append(card)
	assert_true(tm.play_realm(card, "Kelp Forest"))
	assert_false(player.hand.has(card))
	assert_true(player.realms.has("Kelp Forest"))
	var stack: Array = player.realms["Kelp Forest"]
	assert_eq(stack.size(), 1)
	assert_eq(tm.plays_this_turn, 1)

func test_playing_realm_rejects_wrong_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var card := _realm("r1", "Kelp Forest")
	player.hand.append(card)
	assert_false(tm.play_realm(card, "Tide Pools"),
		"Realm card can't be laid under a different realm")
	assert_true(player.hand.has(card))
	assert_eq(tm.plays_this_turn, 0)

func test_playing_realm_consumes_a_play() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var r1 := _realm("r1", "Kelp Forest")
	var r2 := _realm("r2", "Kelp Forest")
	var r3 := _realm("r3", "Kelp Forest")
	var r4 := _realm("r4", "Kelp Forest")
	player.hand.append_array([r1, r2, r3, r4])
	assert_true(tm.play_realm(r1, "Kelp Forest"))
	assert_true(tm.play_realm(r2, "Kelp Forest"))
	assert_true(tm.play_realm(r3, "Kelp Forest"))
	assert_false(tm.play_realm(r4, "Kelp Forest"), "4th play blocked by 3-play limit")

func test_pearl_cannot_be_played_as_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var p := _pearl("p1")
	player.hand.append(p)
	assert_false(tm.play_realm(p, "Kelp Forest"))

# ---- Wild realm cards ----

func test_wild_realm_can_be_assigned_to_either_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var w := _wild("w1", ["Coral Gardens", "Pearl Beds"] as Array[String])
	player.hand.append(w)
	assert_true(tm.play_realm(w, "Coral Gardens"))
	assert_eq((player.realms["Coral Gardens"] as Array).size(), 1)

func test_wild_realm_rejects_non_matching_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var w := _wild("w1", ["Coral Gardens", "Pearl Beds"] as Array[String])
	player.hand.append(w)
	assert_false(tm.play_realm(w, "Kelp Forest"),
		"Wild without Kelp Forest in its realm list can't be laid there")

func test_wild_realm_can_be_flipped() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	var w := _wild("w1", ["Coral Gardens", "Pearl Beds"] as Array[String])
	player.hand.append(w)
	player.play_realm(w, "Coral Gardens")
	player.reassign_wild(w, "Coral Gardens", "Pearl Beds")
	assert_eq((player.realms["Coral Gardens"] as Array).size(), 0)
	assert_eq((player.realms["Pearl Beds"] as Array).size(), 1)

# ---- Rainbow Conch ----

func test_rainbow_conch_cannot_be_banked() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var conch := _rainbow_conch()
	player.hand.append(conch)
	assert_false(tm.bank_card(conch), "Rainbow Conch cannot be banked")
	assert_true(player.hand.has(conch), "Rainbow Conch stays in hand")
	assert_eq(tm.plays_this_turn, 0)

func test_rainbow_conch_can_be_assigned_to_any_realm() -> void:
	var gs := _game(2)
	var tm := TurnManager.new(gs)
	var player := gs.current_player()
	var conch := _rainbow_conch()
	player.hand.append(conch)
	assert_true(tm.play_realm(conch, "Abyssal Trench"))
	assert_eq((player.realms["Abyssal Trench"] as Array).size(), 1)

# ---- Realm completion ----

func test_tide_pools_complete_at_two_cards() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	var a := _realm("t1", "Tide Pools")
	var b := _realm("t2", "Tide Pools")
	player.hand.append_array([a, b])
	player.play_realm(a, "Tide Pools")
	assert_false(player.is_realm_complete("Tide Pools"))
	player.play_realm(b, "Tide Pools")
	assert_true(player.is_realm_complete("Tide Pools"))

func test_kelp_forest_complete_at_three_cards() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	for i in range(3):
		var c := _realm("k%d" % i, "Kelp Forest")
		player.hand.append(c)
		player.play_realm(c, "Kelp Forest")
	assert_true(player.is_realm_complete("Kelp Forest"))

func test_ocean_currents_needs_four_cards() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	for i in range(3):
		var c := _realm("oc%d" % i, "Ocean Currents")
		player.hand.append(c)
		player.play_realm(c, "Ocean Currents")
	assert_false(player.is_realm_complete("Ocean Currents"),
		"3 cards is not enough for Ocean Currents")
	var extra := _realm("oc3", "Ocean Currents")
	player.hand.append(extra)
	player.play_realm(extra, "Ocean Currents")
	assert_true(player.is_realm_complete("Ocean Currents"))

func test_wild_counts_toward_completion() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	var a := _realm("t1", "Tide Pools")
	var w := _wild("w1", ["Kelp Forest", "Tide Pools"] as Array[String], 1)
	player.hand.append_array([a, w])
	player.play_realm(a, "Tide Pools")
	player.play_realm(w, "Tide Pools")
	assert_true(player.is_realm_complete("Tide Pools"))

func test_flipping_wild_breaks_prior_completion() -> void:
	var gs := _game(2)
	var player := gs.current_player()
	var a := _realm("t1", "Tide Pools")
	var w := _wild("w1", ["Kelp Forest", "Tide Pools"] as Array[String], 1)
	player.hand.append_array([a, w])
	player.play_realm(a, "Tide Pools")
	player.play_realm(w, "Tide Pools")
	assert_true(player.is_realm_complete("Tide Pools"))
	player.reassign_wild(w, "Tide Pools", "Kelp Forest")
	assert_false(player.is_realm_complete("Tide Pools"),
		"Removing the wild should uncomplete Tide Pools")

# ---- Win condition ----

func test_sets_to_win_two_players() -> void:
	var gs := _game(2)
	assert_eq(gs.sets_to_win(), 4)

func test_sets_to_win_three_players() -> void:
	var gs := _game(3)
	assert_eq(gs.sets_to_win(), 3)

func test_sets_to_win_four_players() -> void:
	var gs := _game(4)
	assert_eq(gs.sets_to_win(), 3)

func test_winner_returns_neg_one_before_any_completion() -> void:
	var gs := _game(2)
	assert_eq(gs.winner(), -1)
	assert_false(gs.is_game_over())

func _complete_realm(player: PlayerState, realm: String) -> void:
	var size := Realms.size_of(realm)
	for i in range(size):
		var c := _realm("%s_%d_%d" % [realm, player.id, i], realm)
		player.hand.append(c)
		player.play_realm(c, realm)

func test_two_player_win_triggers_at_four_realms() -> void:
	var gs := _game(2)
	var p := gs.players[0]
	_complete_realm(p, "Tide Pools")
	_complete_realm(p, "Mystic Springs")
	_complete_realm(p, "Abyssal Trench")
	assert_eq(gs.winner(), -1, "3 completed realms is not a win in a 2-player match")
	_complete_realm(p, "Kelp Forest")
	assert_eq(gs.winner(), 0)
	assert_true(gs.is_game_over())

func test_three_player_win_triggers_at_three_realms() -> void:
	var gs := _game(3)
	var p := gs.players[1]
	_complete_realm(p, "Tide Pools")
	_complete_realm(p, "Mystic Springs")
	assert_eq(gs.winner(), -1)
	_complete_realm(p, "Abyssal Trench")
	assert_eq(gs.winner(), 1)
	assert_true(gs.is_game_over())

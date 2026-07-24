extends GutTest

# Runs many AI-vs-AI matches with seeded RNG and asserts none crash or stall.
# Also reports the average turn count so we can spot balance drift.

const NUM_MATCHES := 100
const TURN_CAP := 800
const STARTING_HAND := 5

func _fresh_deck(seed_value: int) -> Array[CardData]:
	var cards := DeckBuilder.build_deck()
	return DeckBuilder.shuffle(cards, seed_value)

func _new_match(num_players: int, seed_value: int) -> Dictionary:
	var deck := _fresh_deck(seed_value)
	var gs := GameState.new(num_players, deck, seed_value)
	# Deal starting hands.
	for p in gs.players:
		for _i in range(STARTING_HAND):
			var c := gs.draw_card()
			if c != null:
				p.hand.append(c)
	var tm := TurnManager.new(gs)
	var ais: Dictionary = {}
	for i in range(num_players):
		ais[i] = AIOpponent.new(i)
	return { "gs": gs, "tm": tm, "ais": ais }

func _run_match(num_players: int, seed_value: int) -> Dictionary:
	var ctx := _new_match(num_players, seed_value)
	var gs: GameState = ctx["gs"]
	var tm: TurnManager = ctx["tm"]
	var ais: Dictionary = ctx["ais"]
	var turns := 0
	while not gs.is_game_over() and turns < TURN_CAP:
		var current_ai: AIOpponent = ais[gs.current_player_index]
		current_ai.take_turn(tm, ais)
		turns += 1
	return { "gs": gs, "turns": turns, "winner": gs.winner() }

func test_hundred_two_player_matches_finish_without_crashing() -> void:
	var total_turns := 0
	var wins_by: Dictionary = {0: 0, 1: 0}
	for i in range(NUM_MATCHES):
		var result := _run_match(2, 1000 + i)
		var winner: int = result["winner"]
		var turns: int = result["turns"]
		assert_true(winner != -1,
			"Match %d stalled after %d turns (cap %d)" % [i, turns, TURN_CAP])
		assert_true(turns < TURN_CAP,
			"Match %d exceeded turn cap" % i)
		total_turns += turns
		wins_by[winner] = int(wins_by.get(winner, 0)) + 1
	var avg := float(total_turns) / float(NUM_MATCHES)
	gut.p("AI vs AI (2p): avg turns per match = %.1f, wins %s" % [avg, wins_by])

func test_three_player_matches_finish() -> void:
	# Smaller sample so the suite stays quick; three players share the same
	# code path but hit different branches (multi-target refusals, more
	# tribute payers, etc.).
	var sample := 20
	var total_turns := 0
	for i in range(sample):
		var result := _run_match(3, 2000 + i)
		assert_true(result["winner"] != -1,
			"3p match %d stalled after %d turns" % [i, result["turns"]])
		total_turns += int(result["turns"])
	var avg := float(total_turns) / float(sample)
	gut.p("AI vs AI (3p): avg turns per match = %.1f" % avg)

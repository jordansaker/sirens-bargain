class_name GameState
extends RefCounted

var players: Array[PlayerState] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_player_index: int = 0
var rng: RandomNumberGenerator

func _init(num_players: int, deck: Array[CardData], seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(num_players):
		players.append(PlayerState.new(i))
	for c in deck:
		draw_pile.append(c)

func current_player() -> PlayerState:
	return players[current_player_index]

func sets_to_win() -> int:
	return 4 if players.size() == 2 else 3

func winner() -> int:
	var target := sets_to_win()
	for p in players:
		if p.completed_realm_count() >= target:
			return p.id
	return -1

func is_game_over() -> bool:
	return winner() != -1

func advance_player() -> void:
	current_player_index = (current_player_index + 1) % players.size()

func draw_card() -> CardData:
	if draw_pile.is_empty():
		_reshuffle_discard_into_draw()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()

func _reshuffle_discard_into_draw() -> void:
	if discard_pile.is_empty():
		return
	for i in range(discard_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CardData = discard_pile[i]
		discard_pile[i] = discard_pile[j]
		discard_pile[j] = tmp
	for c in discard_pile:
		draw_pile.append(c)
	discard_pile.clear()

class_name TurnManager
extends RefCounted

const MAX_PLAYS := 3
const HAND_LIMIT := 7
const NORMAL_DRAW := 2
const EMPTY_HAND_DRAW := 5

var game_state: GameState
var plays_this_turn: int = 0

func _init(gs: GameState) -> void:
	game_state = gs

func start_turn() -> void:
	plays_this_turn = 0
	var player := game_state.current_player()
	var draw_count := EMPTY_HAND_DRAW if player.hand.is_empty() else NORMAL_DRAW
	for i in range(draw_count):
		var card := game_state.draw_card()
		if card == null:
			break
		player.hand.append(card)

func can_play() -> bool:
	return plays_this_turn < MAX_PLAYS

func bank_card(card: CardData) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	player.bank_card(card)
	plays_this_turn += 1
	return true

func end_turn(discards: Array[CardData] = []) -> void:
	var player := game_state.current_player()
	var over := player.hand.size() - HAND_LIMIT
	var required: int = over if over > 0 else 0
	assert(discards.size() == required,
		"Must discard exactly %d cards, got %d" % [required, discards.size()])
	for c in discards:
		player.discard_from_hand(c)
		game_state.discard_pile.append(c)
	game_state.advance_player()

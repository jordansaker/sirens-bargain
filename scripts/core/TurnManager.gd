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
	if not card.can_bank():
		return false
	player.bank_card(card)
	plays_this_turn += 1
	return true

func play_realm(card: CardData, target_realm: String) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	if card.type != CardData.Type.REALM and card.type != CardData.Type.WILD_REALM:
		return false
	if not card.can_be_assigned_to(target_realm):
		return false
	player.play_realm(card, target_realm)
	plays_this_turn += 1
	return true

func play_coral_cottage(card: CardData, target_realm: String) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	if card.action_effect != "coral_cottage":
		return false
	if not player.is_realm_complete(target_realm):
		return false
	if player.has_cottage(target_realm):
		return false
	player.attach_modifier(card, target_realm)
	plays_this_turn += 1
	return true

func play_pearl_palace(card: CardData, target_realm: String) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	if card.action_effect != "pearl_palace":
		return false
	if not player.is_realm_complete(target_realm):
		return false
	if not player.has_cottage(target_realm):
		return false
	if player.has_palace(target_realm):
		return false
	player.attach_modifier(card, target_realm)
	plays_this_turn += 1
	return true

# Play a tribute against opponents. Returns a { player_id: amount_owed } map
# on success, or an empty dict if the play is illegal. Payment is a separate
# step — the caller uses PaymentResolver once defensive plays (Siren's Refusal,
# phase 5) have had their chance to intervene.
#
# charger_realm — one of the charger's laid realms. For standard tributes it
# must be one of the tribute's realms; for Siren's Toll it can be any realm
# the charger owns cards in.
# target_player — required for Siren's Toll, ignored otherwise.
# high_tide_card — optional High Tide from the charger's hand; doubles the
# rent and consumes a second card play.
func charge_tribute(
	tribute_card: CardData,
	charger_realm: String,
	target_player: int = -1,
	high_tide_card: CardData = null,
) -> Dictionary:
	var empty: Dictionary = {}
	var plays_needed: int = 2 if high_tide_card != null else 1
	if plays_this_turn + plays_needed > MAX_PLAYS:
		return empty
	var charger := game_state.current_player()
	if not charger.hand.has(tribute_card):
		return empty
	if tribute_card.type != CardData.Type.TRIBUTE:
		return empty
	if high_tide_card != null:
		if not charger.hand.has(high_tide_card):
			return empty
		if high_tide_card.action_effect != "high_tide":
			return empty
	var count_in_realm := 0
	if charger.realms.has(charger_realm):
		count_in_realm = (charger.realms[charger_realm] as Array).size()
	if count_in_realm == 0:
		return empty

	var is_sirens_toll := tribute_card.realms.is_empty()
	var payers: Array[int] = []
	if is_sirens_toll:
		if target_player < 0 or target_player == charger.id:
			return empty
		var found := false
		for p in game_state.players:
			if p.id == target_player:
				found = true
				break
		if not found:
			return empty
		payers.append(target_player)
	else:
		if not tribute_card.realms.has(charger_realm):
			return empty
		for p in game_state.players:
			if p.id != charger.id:
				payers.append(p.id)

	var per_payer := RentCalculator.rent(charger, charger_realm, high_tide_card != null)
	var owed: Dictionary = {}
	for pid in payers:
		owed[pid] = per_payer

	charger.hand.erase(tribute_card)
	game_state.discard_pile.append(tribute_card)
	if high_tide_card != null:
		charger.hand.erase(high_tide_card)
		game_state.discard_pile.append(high_tide_card)
	plays_this_turn += plays_needed
	return owed

func play_slippery_eel(
	card: CardData,
	target_id: int,
	stolen_card: CardData,
	dest_realm: String,
) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	if card.action_effect != "slippery_eel":
		return false
	if target_id == player.id:
		return false
	var target_exists := false
	for p in game_state.players:
		if p.id == target_id:
			target_exists = true
			break
	if not target_exists:
		return false
	if not ActionResolver.slippery_eel(game_state, target_id, stolen_card, dest_realm):
		return false
	player.hand.erase(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	return true

func play_toll_of_the_tides(card: CardData, target_id: int) -> Dictionary:
	var empty: Dictionary = {}
	if not can_play():
		return empty
	var player := game_state.current_player()
	if not player.hand.has(card):
		return empty
	if card.action_effect != "toll_of_the_tides":
		return empty
	if target_id == player.id:
		return empty
	var target_exists := false
	for p in game_state.players:
		if p.id == target_id:
			target_exists = true
			break
	if not target_exists:
		return empty
	player.hand.erase(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	return ActionResolver.toll_of_the_tides(game_state, target_id)

func play_mermaids_feast(card: CardData) -> Dictionary:
	var empty: Dictionary = {}
	if not can_play():
		return empty
	var player := game_state.current_player()
	if not player.hand.has(card):
		return empty
	if card.action_effect != "mermaids_feast":
		return empty
	player.hand.erase(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	return ActionResolver.mermaids_feast(game_state)

func play_ride_the_current(card: CardData) -> bool:
	if not can_play():
		return false
	var player := game_state.current_player()
	if not player.hand.has(card):
		return false
	if card.action_effect != "ride_the_current":
		return false
	# Remove from hand up-front so the card can't be redrawn if the deck runs
	# out mid-effect, but delay putting it into the discard pile until AFTER
	# the resolver has drawn — otherwise a reshuffle would pull the same Ride
	# card straight back into the player's hand.
	player.hand.erase(card)
	plays_this_turn += 1
	ActionResolver.ride_the_current(game_state)
	game_state.discard_pile.append(card)
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

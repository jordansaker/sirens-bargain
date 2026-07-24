class_name TurnManager
extends RefCounted

const MAX_PLAYS := 3
const HAND_LIMIT := 7
const NORMAL_DRAW := 2
const EMPTY_HAND_DRAW := 5

# Fired after any successful play or refusable-action initiation. `text` uses
# "P%d" tokens for player references (e.g. "took Anemone Grove from P0 with
# Slippery Eel"); UI is expected to substitute names for display.
signal play_logged(actor_id: int, text: String)

var game_state: GameState
var plays_this_turn: int = 0

func _init(gs: GameState) -> void:
	game_state = gs
	# Empty-hand refill fires the moment any player empties their hand — via
	# playing, refusing, banking or attaching a modifier — regardless of
	# whose turn it is. Draws EMPTY_HAND_DRAW; may reshuffle discard.
	for p in game_state.players:
		p.hand_emptied.connect(_on_player_hand_emptied.bind(p))

func _on_player_hand_emptied(player: PlayerState) -> void:
	var drawn := 0
	for i in range(EMPTY_HAND_DRAW):
		var c := game_state.draw_card()
		if c == null:
			break
		player.hand.append(c)
		drawn += 1
	if drawn > 0:
		play_logged.emit(player.id, "drew %d (empty hand)" % drawn)

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
	play_logged.emit(player.id, "banked %s (%d ◈)" % [card.name, card.value])
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
	play_logged.emit(player.id, "laid %s in %s" % [card.name, target_realm])
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
	play_logged.emit(player.id, "attached Coral Cottage to %s" % target_realm)
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
	play_logged.emit(player.id, "attached Pearl Palace to %s" % target_realm)
	return true

# --- Refusable actions ---------------------------------------------------
#
# Each refusable action is a two-step protocol:
#   1. initiate_X(...)  → returns PendingAction, consumes the play, discards
#                          the action card. Effect NOT applied yet.
#   2. resolve_pending() → applies the effect for any target whose refusal
#                          stack is even (including zero refusals), then
#                          moves all spent refusal cards to discard and
#                          clears game_state.pending_action.
#
# Between the two steps, callers can call refuse(...) to add Siren's Refusal
# cards to the pending action's per-target stacks. Refusals do NOT consume
# the current player's 3-play budget — they're reactive out-of-turn plays.
#
# Convenience: the pre-existing play_X wrappers still exist and just do
# initiate + resolve back-to-back (i.e. no refusal window).

func initiate_slippery_eel(
	card: CardData,
	target_id: int,
	stolen_card: CardData,
	dest_realm: String,
) -> PendingAction:
	if not can_play():
		return null
	var player := game_state.current_player()
	if not player.hand.has(card):
		return null
	if card.action_effect != "slippery_eel":
		return null
	if target_id == player.id:
		return null
	if not ActionResolver.can_slippery_eel(game_state, target_id, stolen_card, dest_realm):
		return null
	player.remove_from_hand(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	var pending := PendingAction.new(
		"slippery_eel", player.id, [target_id] as Array[int],
		{ "stolen_card": stolen_card, "dest_realm": dest_realm },
	)
	game_state.pending_action = pending
	play_logged.emit(player.id, "took %s from P%d with Slippery Eel" % [stolen_card.name, target_id])
	return pending

func play_slippery_eel(
	card: CardData, target_id: int, stolen_card: CardData, dest_realm: String
) -> bool:
	if initiate_slippery_eel(card, target_id, stolen_card, dest_realm) == null:
		return false
	var result: Variant = resolve_pending()
	return bool(result)

func initiate_trade_winds(
	card: CardData,
	target_id: int,
	own_card: CardData,
	their_dest_realm: String,
	their_card: CardData,
	own_dest_realm: String,
) -> PendingAction:
	if not can_play():
		return null
	var player := game_state.current_player()
	if not player.hand.has(card):
		return null
	if card.action_effect != "trade_winds":
		return null
	if target_id == player.id:
		return null
	if not ActionResolver.can_trade_winds(
		game_state, target_id,
		own_card, their_dest_realm, their_card, own_dest_realm,
	):
		return null
	player.remove_from_hand(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	var pending := PendingAction.new(
		"trade_winds", player.id, [target_id] as Array[int],
		{
			"own_card": own_card,
			"their_dest_realm": their_dest_realm,
			"their_card": their_card,
			"own_dest_realm": own_dest_realm,
		},
	)
	game_state.pending_action = pending
	play_logged.emit(player.id,
		"traded %s for %s with P%d (Trade Winds)" % [own_card.name, their_card.name, target_id])
	return pending

func play_trade_winds(
	card: CardData,
	target_id: int,
	own_card: CardData,
	their_dest_realm: String,
	their_card: CardData,
	own_dest_realm: String,
) -> bool:
	if initiate_trade_winds(
		card, target_id, own_card, their_dest_realm, their_card, own_dest_realm
	) == null:
		return false
	var result: Variant = resolve_pending()
	return bool(result)

func initiate_krakens_grasp(
	card: CardData, target_id: int, realm_name: String
) -> PendingAction:
	if not can_play():
		return null
	var player := game_state.current_player()
	if not player.hand.has(card):
		return null
	if card.action_effect != "krakens_grasp":
		return null
	if target_id == player.id:
		return null
	if not ActionResolver.can_krakens_grasp(game_state, target_id, realm_name):
		return null
	player.remove_from_hand(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	var pending := PendingAction.new(
		"krakens_grasp", player.id, [target_id] as Array[int],
		{ "realm_name": realm_name },
	)
	game_state.pending_action = pending
	play_logged.emit(player.id, "took %s from P%d with Kraken's Grasp" % [realm_name, target_id])
	return pending

func play_krakens_grasp(card: CardData, target_id: int, realm_name: String) -> bool:
	if initiate_krakens_grasp(card, target_id, realm_name) == null:
		return false
	var result: Variant = resolve_pending()
	return bool(result)

func initiate_toll_of_the_tides(card: CardData, target_id: int) -> PendingAction:
	if not can_play():
		return null
	var player := game_state.current_player()
	if not player.hand.has(card):
		return null
	if card.action_effect != "toll_of_the_tides":
		return null
	if target_id == player.id:
		return null
	if ActionResolver._player_by_id(game_state, target_id) == null:
		return null
	player.remove_from_hand(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	var pending := PendingAction.new(
		"toll_of_the_tides", player.id, [target_id] as Array[int],
		{ "per_target": ActionResolver.TOLL_OF_THE_TIDES_AMOUNT },
	)
	game_state.pending_action = pending
	play_logged.emit(player.id,
		"took Toll of the Tides from P%d — %d ◈ owed" %
		[target_id, ActionResolver.TOLL_OF_THE_TIDES_AMOUNT])
	return pending

func play_toll_of_the_tides(card: CardData, target_id: int) -> Dictionary:
	if initiate_toll_of_the_tides(card, target_id) == null:
		return {}
	var result: Variant = resolve_pending()
	if result is Dictionary:
		return result
	return {}

func initiate_mermaids_feast(card: CardData) -> PendingAction:
	if not can_play():
		return null
	var player := game_state.current_player()
	if not player.hand.has(card):
		return null
	if card.action_effect != "mermaids_feast":
		return null
	var targets: Array[int] = []
	for p in game_state.players:
		if p.id != player.id:
			targets.append(p.id)
	player.remove_from_hand(card)
	game_state.discard_pile.append(card)
	plays_this_turn += 1
	var pending := PendingAction.new(
		"mermaids_feast", player.id, targets,
		{ "per_target": ActionResolver.MERMAIDS_FEAST_AMOUNT },
	)
	game_state.pending_action = pending
	play_logged.emit(player.id,
		"served Mermaid's Feast — everyone owes %d ◈" % ActionResolver.MERMAIDS_FEAST_AMOUNT)
	return pending

func play_mermaids_feast(card: CardData) -> Dictionary:
	if initiate_mermaids_feast(card) == null:
		return {}
	var result: Variant = resolve_pending()
	if result is Dictionary:
		return result
	return {}

# Tributes — standard (charges every opponent on a matching realm) or
# Siren's Toll (charges one chosen opponent on any realm the charger owns).
# High Tide is optional and consumes an extra play; it doubles the per-payer
# amount for every non-cancelled target.
func initiate_tribute(
	tribute_card: CardData,
	charger_realm: String,
	target_player: int = -1,
	high_tide_card: CardData = null,
) -> PendingAction:
	var plays_needed: int = 2 if high_tide_card != null else 1
	if plays_this_turn + plays_needed > MAX_PLAYS:
		return null
	var charger := game_state.current_player()
	if not charger.hand.has(tribute_card):
		return null
	if tribute_card.type != CardData.Type.TRIBUTE:
		return null
	if high_tide_card != null:
		if not charger.hand.has(high_tide_card):
			return null
		if high_tide_card.action_effect != "high_tide":
			return null
	var count_in_realm := 0
	if charger.realms.has(charger_realm):
		count_in_realm = (charger.realms[charger_realm] as Array).size()
	if count_in_realm == 0:
		return null

	var is_sirens_toll := tribute_card.realms.is_empty()
	var payers: Array[int] = []
	if is_sirens_toll:
		if target_player < 0 or target_player == charger.id:
			return null
		if ActionResolver._player_by_id(game_state, target_player) == null:
			return null
		payers.append(target_player)
	else:
		if not tribute_card.realms.has(charger_realm):
			return null
		for p in game_state.players:
			if p.id != charger.id:
				payers.append(p.id)

	var per_payer := RentCalculator.rent(charger, charger_realm, high_tide_card != null)

	charger.remove_from_hand(tribute_card)
	game_state.discard_pile.append(tribute_card)
	if high_tide_card != null:
		charger.remove_from_hand(high_tide_card)
		game_state.discard_pile.append(high_tide_card)
	plays_this_turn += plays_needed

	var kind := "sirens_toll" if is_sirens_toll else "tribute"
	var pending := PendingAction.new(
		kind, charger.id, payers,
		{ "per_target": per_payer, "charger_realm": charger_realm },
	)
	game_state.pending_action = pending
	var ht_note := " with High Tide" if high_tide_card != null else ""
	if is_sirens_toll:
		play_logged.emit(charger.id,
			"charged Siren's Toll from P%d on %s%s — %d ◈ owed" %
			[payers[0], charger_realm, ht_note, per_payer])
	else:
		play_logged.emit(charger.id,
			"charged Tribute on %s%s — %d ◈ per opponent" %
			[charger_realm, ht_note, per_payer])
	return pending

func charge_tribute(
	tribute_card: CardData,
	charger_realm: String,
	target_player: int = -1,
	high_tide_card: CardData = null,
) -> Dictionary:
	if initiate_tribute(tribute_card, charger_realm, target_player, high_tide_card) == null:
		return {}
	var result: Variant = resolve_pending()
	if result is Dictionary:
		return result
	return {}

# Add a Siren's Refusal to the pending action's stack for target_id. The
# refuser is either the target defending, or the initiator counter-refusing.
# Alternation is enforced: the same side can't play two refusals in a row.
# The card is spent immediately (moved to discard) regardless of whether a
# later counter neutralises it.
func refuse(target_id: int, refuser_id: int, refusal_card: CardData) -> bool:
	var pending := game_state.pending_action
	if pending == null:
		return false
	if not pending.targets.has(target_id):
		return false
	if pending.next_refuser_for(target_id) != refuser_id:
		return false
	var refuser := ActionResolver._player_by_id(game_state, refuser_id)
	if refuser == null:
		return false
	if not refuser.hand.has(refusal_card):
		return false
	if refusal_card.action_effect != "sirens_refusal":
		return false
	refuser.remove_from_hand(refusal_card)
	game_state.discard_pile.append(refusal_card)
	pending.push_refusal(target_id, refusal_card)
	return true

# Apply the pending action for every non-cancelled target. Returns:
#   Dictionary  — for owed-map actions (tribute, sirens_toll, toll_of_the_tides,
#                 mermaids_feast). Keyed by target_id; cancelled targets omitted.
#   bool        — for one-shot theft/swap actions (slippery_eel, trade_winds,
#                 krakens_grasp). true if the effect actually fired.
#   null        — no pending action to resolve.
#
# Refusal cards are already in the discard pile (moved when played); the
# stacks themselves are just cleared alongside pending_action.
func resolve_pending() -> Variant:
	var pending := game_state.pending_action
	if pending == null:
		return null
	var result: Variant = null
	match pending.kind:
		"slippery_eel":
			var target_id: int = pending.targets[0]
			if pending.is_cancelled_for(target_id):
				result = false
			else:
				var stolen_card: CardData = pending.payload["stolen_card"]
				var dest_realm: String = pending.payload["dest_realm"]
				result = ActionResolver.slippery_eel(
					game_state, target_id, stolen_card, dest_realm
				)
		"trade_winds":
			var target_id: int = pending.targets[0]
			if pending.is_cancelled_for(target_id):
				result = false
			else:
				result = ActionResolver.trade_winds(
					game_state, target_id,
					pending.payload["own_card"],
					pending.payload["their_dest_realm"],
					pending.payload["their_card"],
					pending.payload["own_dest_realm"],
				)
		"krakens_grasp":
			var target_id: int = pending.targets[0]
			if pending.is_cancelled_for(target_id):
				result = false
			else:
				result = ActionResolver.krakens_grasp(
					game_state, target_id, pending.payload["realm_name"]
				)
		"toll_of_the_tides", "tribute", "sirens_toll", "mermaids_feast":
			var per: int = int(pending.payload["per_target"])
			var owed: Dictionary = {}
			for t in pending.effective_targets():
				owed[t] = per
			result = owed
		_:
			pass
	game_state.pending_action = null
	return result

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
	player.remove_from_hand(card)
	plays_this_turn += 1
	ActionResolver.ride_the_current(game_state)
	game_state.discard_pile.append(card)
	play_logged.emit(player.id, "drew 2 (Ride the Current)")
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

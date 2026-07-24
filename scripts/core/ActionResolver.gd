class_name ActionResolver
extends RefCounted

# Standalone action-card effects. Each method mutates GameState and returns
# any useful result to the caller (e.g. the cards drawn). Action cards are
# discarded by TurnManager after resolution — resolvers should not touch the
# card that triggered them.

const MERMAIDS_FEAST_AMOUNT := 2
const TOLL_OF_THE_TIDES_AMOUNT := 5

static func ride_the_current(gs: GameState) -> Array[CardData]:
	var drawn: Array[CardData] = []
	var player := gs.current_player()
	for i in range(2):
		var c := gs.draw_card()
		if c == null:
			break
		player.hand.append(c)
		drawn.append(c)
	return drawn

# Charges every opponent MERMAIDS_FEAST_AMOUNT pearls. Returns a
# { opponent_id: amount } map; payment is a separate step so Siren's Refusal
# (phase 5, later) can intervene per-target.
static func mermaids_feast(gs: GameState) -> Dictionary:
	var owed: Dictionary = {}
	var charger := gs.current_player()
	for p in gs.players:
		if p.id != charger.id:
			owed[p.id] = MERMAIDS_FEAST_AMOUNT
	return owed

# Charges one chosen opponent TOLL_OF_THE_TIDES_AMOUNT pearls.
static func toll_of_the_tides(gs: GameState, target_id: int) -> Dictionary:
	return { target_id: TOLL_OF_THE_TIDES_AMOUNT }

# Steal one loose realm card from an opponent — never from a completed set —
# and place it under one of the thief's realms. Returns true on success.
static func slippery_eel(
	gs: GameState,
	target_id: int,
	stolen_card: CardData,
	dest_realm: String,
) -> bool:
	var thief := gs.current_player()
	var target: PlayerState = null
	for p in gs.players:
		if p.id == target_id:
			target = p
			break
	if target == null:
		return false
	var source_realm := ""
	for r in target.realms.keys():
		var stack: Array = target.realms[r]
		if stack.has(stolen_card):
			source_realm = r
			break
	if source_realm == "":
		return false
	if target.is_realm_complete(source_realm):
		return false
	if not stolen_card.can_be_assigned_to(dest_realm):
		return false
	target.pay_cards([] as Array[CardData], [stolen_card] as Array[CardData])
	thief.receive_realm_card(stolen_card, dest_realm)
	return true

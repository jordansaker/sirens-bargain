class_name ActionResolver
extends RefCounted

# Standalone action-card effects. Each method mutates GameState and returns
# any useful result to the caller (e.g. the cards drawn). Action cards are
# discarded by TurnManager after resolution — resolvers should not touch the
# card that triggered them.

const MERMAIDS_FEAST_AMOUNT := 2

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

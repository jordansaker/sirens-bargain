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
	# Rainbow Conch is untouchable by Slippery Eel — it's a shared "any realm"
	# wild and letting it hop between players via a single-card steal would
	# make it too swingy.
	if stolen_card.is_rainbow_conch():
		return false
	var source_realm := _find_realm(target, stolen_card)
	if source_realm == "":
		return false
	# Allow when the source realm has a surplus card OR is still incomplete
	# — Kraken owns the "steal a complete set with no surplus" case.
	if not target.has_stealable_loose_card(source_realm):
		return false
	if not stolen_card.can_be_assigned_to(dest_realm):
		return false
	target.pay_cards([] as Array[CardData], [stolen_card] as Array[CardData])
	thief.receive_realm_card(stolen_card, dest_realm)
	return true

# Swap one realm card with an opponent. Both cards must be in incomplete
# sets, and each must land in a realm it can legally be assigned to on the
# receiving player's board. Returns true on success.
static func trade_winds(
	gs: GameState,
	target_id: int,
	own_card: CardData,
	their_dest_realm: String,
	their_card: CardData,
	own_dest_realm: String,
) -> bool:
	var initiator := gs.current_player()
	var target: PlayerState = null
	for p in gs.players:
		if p.id == target_id:
			target = p
			break
	if target == null:
		return false
	# Rainbow Conch is untouchable — swapping it either direction would let
	# it change owners outside a full-set steal.
	if own_card.is_rainbow_conch() or their_card.is_rainbow_conch():
		return false
	var own_source := _find_realm(initiator, own_card)
	if own_source == "":
		return false
	if not initiator.has_stealable_loose_card(own_source):
		return false
	var their_source := _find_realm(target, their_card)
	if their_source == "":
		return false
	if not target.has_stealable_loose_card(their_source):
		return false
	if not own_card.can_be_assigned_to(their_dest_realm):
		return false
	if not their_card.can_be_assigned_to(own_dest_realm):
		return false
	initiator.pay_cards([] as Array[CardData], [own_card] as Array[CardData])
	target.pay_cards([] as Array[CardData], [their_card] as Array[CardData])
	target.receive_realm_card(own_card, their_dest_realm)
	initiator.receive_realm_card(their_card, own_dest_realm)
	return true

# Steal an entire completed realm from an opponent. Realm cards move as-is
# (wilds keep their current assignment); Cottage/Palace modifiers move with
# the set. If the thief already had a Cottage or Palace on that realm, the
# incoming duplicate is sent to the discard pile so the one-of-each invariant
# holds. Returns true on success.
static func krakens_grasp(gs: GameState, target_id: int, realm_name: String) -> bool:
	var thief := gs.current_player()
	var target: PlayerState = null
	for p in gs.players:
		if p.id == target_id:
			target = p
			break
	if target == null:
		return false
	if not target.realms.has(realm_name):
		return false
	if not target.is_realm_complete(realm_name):
		return false

	var stolen_cards: Array[CardData] = target.realms[realm_name]
	target.realms[realm_name] = [] as Array[CardData]
	var thief_stack: Array[CardData] = thief.realms.get(realm_name, [] as Array[CardData])
	thief_stack.append_array(stolen_cards)
	thief.realms[realm_name] = thief_stack

	if target.realm_modifiers.has(realm_name):
		var stolen_mods: Array[CardData] = target.realm_modifiers[realm_name]
		target.realm_modifiers.erase(realm_name)
		var thief_mods: Array[CardData] = thief.realm_modifiers.get(
			realm_name, [] as Array[CardData]
		)
		for m in stolen_mods:
			var is_dup := (
				(m.action_effect == "coral_cottage" and thief.has_cottage(realm_name))
				or (m.action_effect == "pearl_palace" and thief.has_palace(realm_name))
			)
			if is_dup:
				gs.discard_pile.append(m)
			else:
				thief_mods.append(m)
		thief.realm_modifiers[realm_name] = thief_mods
	return true

static func _find_realm(player: PlayerState, card: CardData) -> String:
	for r in player.realms.keys():
		var stack: Array = player.realms[r]
		if stack.has(card):
			return r
	return ""

static func _player_by_id(gs: GameState, id: int) -> PlayerState:
	for p in gs.players:
		if p.id == id:
			return p
	return null

# Non-mutating preflights used by TurnManager.initiate_X — check the same
# conditions the resolver checks, without changing any state.

static func can_slippery_eel(
	gs: GameState, target_id: int, stolen_card: CardData, dest_realm: String
) -> bool:
	var target := _player_by_id(gs, target_id)
	if target == null:
		return false
	if stolen_card.is_rainbow_conch():
		return false
	var source_realm := _find_realm(target, stolen_card)
	if source_realm == "":
		return false
	if not target.has_stealable_loose_card(source_realm):
		return false
	return stolen_card.can_be_assigned_to(dest_realm)

static func can_trade_winds(
	gs: GameState,
	target_id: int,
	own_card: CardData,
	their_dest_realm: String,
	their_card: CardData,
	own_dest_realm: String,
) -> bool:
	var initiator := gs.current_player()
	var target := _player_by_id(gs, target_id)
	if target == null:
		return false
	if own_card.is_rainbow_conch() or their_card.is_rainbow_conch():
		return false
	var own_source := _find_realm(initiator, own_card)
	if own_source == "":
		return false
	if not initiator.has_stealable_loose_card(own_source):
		return false
	var their_source := _find_realm(target, their_card)
	if their_source == "":
		return false
	if not target.has_stealable_loose_card(their_source):
		return false
	if not own_card.can_be_assigned_to(their_dest_realm):
		return false
	return their_card.can_be_assigned_to(own_dest_realm)

static func can_krakens_grasp(gs: GameState, target_id: int, realm_name: String) -> bool:
	var target := _player_by_id(gs, target_id)
	if target == null:
		return false
	if not target.realms.has(realm_name):
		return false
	return target.is_realm_complete(realm_name)

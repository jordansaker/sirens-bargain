class_name PlayerState
extends RefCounted

# Fired the moment `hand` becomes empty via `remove_from_hand`. TurnManager
# hooks this to immediately refill via a 5-card draw — the "empty hand →
# draw 5" rule fires whenever it happens, not just at start of turn.
signal hand_emptied

var id: int = 0
var hand: Array[CardData] = []
var bank: Array[CardData] = []
var realms: Dictionary = {}
var realm_modifiers: Dictionary = {}

func _init(player_id: int = 0) -> void:
	id = player_id

# Central hand-removal helper. Every path that takes a card out of hand
# should go through this so the empty-hand refill fires reliably.
func remove_from_hand(card: CardData) -> void:
	assert(hand.has(card), "Card not in hand")
	hand.erase(card)
	if hand.is_empty():
		hand_emptied.emit()

func bank_card(card: CardData) -> void:
	assert(card.can_bank(), "Card cannot be banked (Rainbow Conch)")
	remove_from_hand(card)
	bank.append(card)

func discard_from_hand(card: CardData) -> void:
	remove_from_hand(card)

func total_bank_value() -> int:
	var total := 0
	for c in bank:
		total += c.value
	return total

func play_realm(card: CardData, target_realm: String) -> void:
	assert(card.type == CardData.Type.REALM or card.type == CardData.Type.WILD_REALM,
		"Card is not a realm or wild")
	assert(card.can_be_assigned_to(target_realm),
		"Card cannot be assigned to %s" % target_realm)
	remove_from_hand(card)
	_append_to_realm(card, target_realm)

func reassign_wild(card: CardData, from_realm: String, to_realm: String) -> void:
	assert(card.type == CardData.Type.WILD_REALM, "Only wild realm cards can flip")
	assert(from_realm != to_realm, "Wild is already in %s" % to_realm)
	assert(card.can_be_assigned_to(to_realm),
		"Wild cannot be assigned to %s" % to_realm)
	assert(realms.has(from_realm), "No cards laid in %s" % from_realm)
	var src: Array[CardData] = realms[from_realm]
	assert(src.has(card), "Wild not present in %s" % from_realm)
	src.erase(card)
	realms[from_realm] = src
	_append_to_realm(card, to_realm)

func _append_to_realm(card: CardData, target_realm: String) -> void:
	var stack: Array[CardData] = realms.get(target_realm, [] as Array[CardData])
	stack.append(card)
	realms[target_realm] = stack

# A realm can only be charged rent (or used as the anchor for Siren's Toll)
# if it contains at least one "real" card — Rainbow Conch is a shared wild
# and doesn't on its own establish ownership of a realm.
func has_chargeable_card_in(realm: String) -> bool:
	if not realms.has(realm):
		return false
	var stack: Array = realms[realm]
	for c in stack:
		if c is CardData and not (c as CardData).is_rainbow_conch():
			return true
	return false

func is_realm_complete(realm: String) -> bool:
	if not realms.has(realm):
		return false
	var stack: Array[CardData] = realms[realm]
	return stack.size() >= Realms.size_of(realm)

func completed_realm_count() -> int:
	var count := 0
	for r in realms.keys():
		if is_realm_complete(r):
			count += 1
	return count

func modifiers_on(realm: String) -> Array[CardData]:
	var mods: Array[CardData] = realm_modifiers.get(realm, [] as Array[CardData])
	return mods

func has_cottage(realm: String) -> bool:
	for m in modifiers_on(realm):
		if m.action_effect == "coral_cottage":
			return true
	return false

func has_palace(realm: String) -> bool:
	for m in modifiers_on(realm):
		if m.action_effect == "pearl_palace":
			return true
	return false

func attach_modifier(card: CardData, realm: String) -> void:
	assert(card.type == CardData.Type.ACTION,
		"Only action cards attach as modifiers")
	assert(card.action_effect == "coral_cottage" or card.action_effect == "pearl_palace",
		"Only Coral Cottage and Pearl Palace attach to realms")
	assert(is_realm_complete(realm),
		"Modifiers only attach to completed realms")
	if card.action_effect == "coral_cottage":
		assert(not has_cottage(realm),
			"%s already has a Coral Cottage" % realm)
	elif card.action_effect == "pearl_palace":
		assert(has_cottage(realm),
			"Pearl Palace requires a Coral Cottage on %s" % realm)
		assert(not has_palace(realm),
			"%s already has a Pearl Palace" % realm)
	remove_from_hand(card)
	var mods: Array[CardData] = modifiers_on(realm)
	mods.append(card)
	realm_modifiers[realm] = mods

# Move an already-laid Coral Cottage / Pearl Palace between two of this
# player's completed realms. Free action — doesn't consume a play. Palace
# still requires a Coral Cottage on the destination.
func move_modifier(card: CardData, from_realm: String, to_realm: String) -> bool:
	if from_realm == to_realm:
		return false
	if not is_realm_complete(to_realm):
		return false
	var from_stack: Array[CardData] = modifiers_on(from_realm)
	if not from_stack.has(card):
		return false
	if card.action_effect == "coral_cottage" and has_cottage(to_realm):
		return false
	if card.action_effect == "pearl_palace":
		if not has_cottage(to_realm):
			return false
		if has_palace(to_realm):
			return false
	from_stack.erase(card)
	if from_stack.is_empty():
		realm_modifiers.erase(from_realm)
	else:
		realm_modifiers[from_realm] = from_stack
	var to_stack: Array[CardData] = modifiers_on(to_realm)
	to_stack.append(card)
	realm_modifiers[to_realm] = to_stack
	return true

func receive_realm_card(card: CardData, target_realm: String) -> void:
	assert(card.type == CardData.Type.REALM or card.type == CardData.Type.WILD_REALM,
		"Only realm and wild cards can be received into a realm")
	assert(card.can_be_assigned_to(target_realm),
		"Card cannot be assigned to %s" % target_realm)
	_append_to_realm(card, target_realm)

func receive_payment(cards: Array[CardData]) -> void:
	# Realm and wild cards received as payment are laid onto the receiver's
	# board (auto-routed to the realm making the most progress). This keeps
	# them playable instead of trapping them in the bank — historically a
	# one-way leak that would stall late-game tributes.
	for c in cards:
		if c.type == CardData.Type.REALM or c.type == CardData.Type.WILD_REALM:
			var dest := _pick_incoming_realm_destination(c)
			if dest.is_empty():
				# Truly no legal destination (shouldn't happen for any card
				# in the deck) — fall through to banking so nothing is lost.
				bank.append(c)
			else:
				_append_to_realm(c, dest)
		else:
			bank.append(c)

# Greedy auto-router for realm/wild cards received as payment: prefer the
# realm we already have the most progress in (skipping already-complete
# sets so extra cards don't pile on a done set). Falls back to any legal
# destination if every candidate is already complete.
func _pick_incoming_realm_destination(card: CardData) -> String:
	var candidates: Array[String] = []
	match card.type:
		CardData.Type.REALM:
			candidates.append(card.realm)
		CardData.Type.WILD_REALM:
			if card.is_rainbow_conch():
				for r in Realms.all_realms():
					candidates.append(r)
			else:
				for r in card.realms:
					candidates.append(r)
	var best := ""
	var best_score := -1
	for r in candidates:
		var stack: Array = realms.get(r, [])
		if stack.size() >= Realms.size_of(r):
			continue
		var score: int = stack.size() + 1
		if score > best_score:
			best_score = score
			best = r
	if best.is_empty() and not candidates.is_empty():
		best = candidates[0]
	return best

func pay_cards(from_bank: Array[CardData], from_realms: Array[CardData]) -> void:
	for c in from_bank:
		assert(bank.has(c), "Card %s not in bank" % c.id)
	for c in from_realms:
		var found_in := ""
		for r in realms.keys():
			var stack: Array = realms[r]
			if stack.has(c):
				found_in = r
				break
		assert(found_in != "", "Card %s not laid in any realm" % c.id)
	for c in from_bank:
		bank.erase(c)
	for c in from_realms:
		for r in realms.keys():
			var stack: Array[CardData] = realms[r]
			if stack.has(c):
				stack.erase(c)
				realms[r] = stack
				# If the realm just lost its last card, drop its modifiers too
				# so a future re-complete doesn't inherit stale houses.
				if stack.is_empty() and realm_modifiers.has(r):
					realm_modifiers.erase(r)
				break

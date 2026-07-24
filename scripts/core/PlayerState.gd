class_name PlayerState
extends RefCounted

var id: int = 0
var hand: Array[CardData] = []
var bank: Array[CardData] = []
var realms: Dictionary = {}
var realm_modifiers: Dictionary = {}

func _init(player_id: int = 0) -> void:
	id = player_id

func bank_card(card: CardData) -> void:
	assert(hand.has(card), "Card not in hand")
	assert(card.can_bank(), "Card cannot be banked (Rainbow Conch)")
	hand.erase(card)
	bank.append(card)

func discard_from_hand(card: CardData) -> void:
	assert(hand.has(card), "Card not in hand")
	hand.erase(card)

func total_bank_value() -> int:
	var total := 0
	for c in bank:
		total += c.value
	return total

func play_realm(card: CardData, target_realm: String) -> void:
	assert(hand.has(card), "Card not in hand")
	assert(card.type == CardData.Type.REALM or card.type == CardData.Type.WILD_REALM,
		"Card is not a realm or wild")
	assert(card.can_be_assigned_to(target_realm),
		"Card cannot be assigned to %s" % target_realm)
	hand.erase(card)
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
	assert(hand.has(card), "Modifier not in hand")
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
	hand.erase(card)
	var mods: Array[CardData] = modifiers_on(realm)
	mods.append(card)
	realm_modifiers[realm] = mods

func receive_payment(cards: Array[CardData]) -> void:
	for c in cards:
		bank.append(c)

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

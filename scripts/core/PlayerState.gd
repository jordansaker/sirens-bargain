class_name PlayerState
extends RefCounted

var id: int = 0
var hand: Array[CardData] = []
var bank: Array[CardData] = []
var realms: Dictionary = {}

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

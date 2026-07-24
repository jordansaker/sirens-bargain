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

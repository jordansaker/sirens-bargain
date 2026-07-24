class_name PendingAction
extends RefCounted

# An in-flight action that opens a window for Siren's Refusal responses.
#
# Each target has its own refusal stack. The initial refusal is the target's
# defence; the initiator can counter with their own Refusal; the target can
# counter that, and so on. Odd stack size → cancelled for that target; even
# (including zero) → the effect applies.
#
# `kind` values used by TurnManager:
#   "slippery_eel", "trade_winds", "krakens_grasp"
#   "toll_of_the_tides", "mermaids_feast"
#   "tribute", "sirens_toll"
#
# `payload` is action-specific — see each initiate_X in TurnManager for what
# it carries.

var kind: String = ""
var initiator_id: int = -1
var targets: Array[int] = []
var payload: Dictionary = {}
var refusal_stacks: Dictionary = {} # target_id -> Array[CardData]

func _init(
	kind_: String = "",
	initiator_id_: int = -1,
	targets_: Array[int] = [],
	payload_: Dictionary = {},
) -> void:
	kind = kind_
	initiator_id = initiator_id_
	targets = targets_.duplicate()
	payload = payload_

func refusal_count(target_id: int) -> int:
	if not refusal_stacks.has(target_id):
		return 0
	return (refusal_stacks[target_id] as Array).size()

func is_cancelled_for(target_id: int) -> bool:
	return refusal_count(target_id) % 2 == 1

func effective_targets() -> Array[int]:
	var out: Array[int] = []
	for t in targets:
		if not is_cancelled_for(t):
			out.append(t)
	return out

# Whose turn is it to add the next refusal for this target?
#   0 refusals → target defends
#   odd count → initiator can counter
#   even (>0) → target can counter again
func next_refuser_for(target_id: int) -> int:
	if refusal_count(target_id) % 2 == 0:
		return target_id
	return initiator_id

func push_refusal(target_id: int, card: CardData) -> void:
	var stack: Array[CardData] = refusal_stacks.get(target_id, [] as Array[CardData])
	stack.append(card)
	refusal_stacks[target_id] = stack

func all_refusal_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for t in refusal_stacks.keys():
		var stack: Array = refusal_stacks[t]
		for c in stack:
			out.append(c)
	return out

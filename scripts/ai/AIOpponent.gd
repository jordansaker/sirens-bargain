class_name AIOpponent
extends RefCounted

# A greedy AI that orchestrates a full turn end-to-end. It calls TurnManager
# for legal plays, opens the refusal window on refusable actions so other AIs
# can defend, and settles owed maps via PaymentResolver.
#
# Priority per play (highest first):
#   1. Play a realm card that completes a set (winning-set first).
#   2. Kraken's Grasp on the leading opponent's most valuable completed set.
#   3. Tribute — highest per-payer amount, add High Tide when the extra rent
#      clearly exceeds the High Tide's bank value.
#   4. Play a realm card that most advances an incomplete set.
#   5. Coral Cottage / Pearl Palace on a completed realm.
#   6. Slippery Eel on the leading opponent's highest-value loose realm card.
#   7. Toll of the Tides on the leading opponent.
#   8. Mermaid's Feast.
#   9. Ride the Current.
#  10. Bank the least useful card (never Siren's Refusal).
#
# Defense: refuse Kraken always; refuse Tribute/Toll if owed >= 3; refuse
# Slippery Eel when it targets our most-progressed incomplete set; ignore
# Mermaid's Feast (2 pearls isn't worth a Refusal).

const HIGH_TIDE_BANK_VALUE := 1

var player_id: int

# Optional coroutine invoked when a refusable action is initiated against a
# player that has no AI in the `all_ais` dict (i.e. the human). Signature is
# `(target_id: int, pending: PendingAction) -> bool`. Return true to refuse.
# Left unset in headless AI-vs-AI matches — the human branch short-circuits
# and no await ever fires.
var human_refusal_hook: Callable

# Optional coroutine invoked when this AI needs to collect payment from a human
# payer. Signature is `(payer: PlayerState, receiver: PlayerState,
# amount: int) -> Variant`. Return a Dictionary `{bank: Array[CardData],
# realms: Array[CardData]}` to override; return null to fall back to the AI's
# smart auto-pay. Unset in headless AI-vs-AI matches.
var human_payment_hook: Callable

func _init(pid: int) -> void:
	player_id = pid

# --- Turn orchestration --------------------------------------------------

func take_turn(tm: TurnManager, all_ais: Dictionary) -> void:
	tm.start_turn()
	# Play loop. Each iteration attempts one play; if we can't find anything
	# to do, break so we don't spin forever. `_make_one_play` is a coroutine
	# because refusable actions may await a human hook; in AI-vs-AI matches
	# the hook is unset so every await resolves immediately and this runs
	# fully synchronously.
	while tm.can_play():
		if not await _make_one_play(tm, all_ais):
			break
		if tm.game_state.is_game_over():
			return
	_end_turn_with_discards(tm)

# --- Public per-step API for external drivers ---------------------------
#
# When the UI wants to interleave AI plays with visual updates (refresh the
# hand, delay a few hundred ms between plays so the player can follow along),
# it calls these three in place of take_turn(). Headless tests keep using
# take_turn() — same underlying logic, no per-step overhead.

func begin_turn(tm: TurnManager) -> void:
	tm.start_turn()

func try_one_play(tm: TurnManager, all_ais: Dictionary) -> bool:
	return await _make_one_play(tm, all_ais)

func finish_turn(tm: TurnManager) -> void:
	_end_turn_with_discards(tm)

func _end_turn_with_discards(tm: TurnManager) -> void:
	var player := tm.game_state.players[player_id]
	var over := player.hand.size() - TurnManager.HAND_LIMIT
	var discards: Array[CardData] = []
	if over > 0:
		var ranked := _hand_sorted_by_discard_preference(player)
		for i in range(over):
			discards.append(ranked[i])
	tm.end_turn(discards)

# Cards worst-to-keep first — used both for banking (bank the worst usable
# first, keep the good stuff in hand) and for discarding.
func _hand_sorted_by_discard_preference(player: PlayerState) -> Array[CardData]:
	var out: Array[CardData] = []
	out.append_array(player.hand)
	out.sort_custom(_discard_preference)
	return out

func _discard_preference(a: CardData, b: CardData) -> bool:
	# Return true if a should be discarded before b.
	return _keep_score(a) < _keep_score(b)

func _keep_score(c: CardData) -> int:
	# Higher = more valuable to keep. Refusals top, then aggressive actions,
	# then realm/wild/tribute cards, then pearls/misc.
	if c.action_effect == "sirens_refusal":
		return 100
	if c.action_effect == "krakens_grasp":
		return 90
	if c.type == CardData.Type.TRIBUTE:
		return 80
	if c.action_effect == "slippery_eel":
		return 70
	if c.action_effect == "toll_of_the_tides":
		return 60
	if c.action_effect == "mermaids_feast":
		return 55
	if c.type == CardData.Type.WILD_REALM or c.type == CardData.Type.REALM:
		return 50 + c.value
	if c.action_effect == "high_tide":
		return 45
	if c.action_effect == "coral_cottage" or c.action_effect == "pearl_palace":
		return 40
	if c.action_effect == "ride_the_current":
		return 20
	return c.value

# --- Play selection ------------------------------------------------------

func _make_one_play(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var player := gs.players[player_id]

	# Non-refusable attempts are sync. The refusable ones (kraken/tribute/
	# eel/toll/feast) await the refusal window — safe to await sync-returning
	# ones too since `await value` just returns the value.
	if _try_complete_set(tm, player):
		return true
	if await _try_kraken(tm, all_ais):
		return true
	if await _try_tribute(tm, all_ais):
		return true
	if _try_progress_realm(tm, player):
		return true
	if _try_attach_modifier(tm, player):
		return true
	if await _try_slippery_eel(tm, all_ais):
		return true
	if await _try_toll(tm, all_ais):
		return true
	if await _try_feast(tm, all_ais):
		return true
	if _try_ride(tm, player):
		return true
	if _try_bank(tm, player):
		return true
	return false

func _try_complete_set(tm: TurnManager, player: PlayerState) -> bool:
	var best_card: CardData = null
	var best_realm := ""
	for c in player.hand:
		if c.type != CardData.Type.REALM and c.type != CardData.Type.WILD_REALM:
			continue
		for r in _candidate_realms(c):
			var current: int = 0
			if player.realms.has(r):
				current = (player.realms[r] as Array).size()
			if current + 1 >= Realms.size_of(r) and not player.is_realm_complete(r):
				# Prefer completing a realm with higher rent when multiple options.
				if best_card == null or Realms.rent_for(r, Realms.size_of(r)) > \
					Realms.rent_for(best_realm, Realms.size_of(best_realm)):
					best_card = c
					best_realm = r
	if best_card == null:
		return false
	return tm.play_realm(best_card, best_realm)

func _try_progress_realm(tm: TurnManager, player: PlayerState) -> bool:
	var best_card: CardData = null
	var best_realm := ""
	var best_score := -1
	for c in player.hand:
		if c.type != CardData.Type.REALM and c.type != CardData.Type.WILD_REALM:
			continue
		for r in _candidate_realms(c):
			var current: int = 0
			if player.realms.has(r):
				current = (player.realms[r] as Array).size()
			if current >= Realms.size_of(r):
				continue # already complete
			# Score: higher when closer to completion. Break ties by realm rent.
			var progress_after: int = current + 1
			var target: int = Realms.size_of(r)
			var score: int = progress_after * 100 / target
			score += Realms.rent_for(r, target)
			if score > best_score:
				best_score = score
				best_card = c
				best_realm = r
	if best_card == null:
		return false
	return tm.play_realm(best_card, best_realm)

func _try_attach_modifier(tm: TurnManager, player: PlayerState) -> bool:
	# Palace first (higher rent bump), but only if a completed set already has
	# a cottage. Then cottage.
	for c in player.hand:
		if c.action_effect == "pearl_palace":
			for r in player.realms.keys():
				if player.is_realm_complete(r) and player.has_cottage(r) and not player.has_palace(r):
					if tm.play_pearl_palace(c, r):
						return true
	for c in player.hand:
		if c.action_effect == "coral_cottage":
			for r in player.realms.keys():
				if player.is_realm_complete(r) and not player.has_cottage(r):
					if tm.play_coral_cottage(c, r):
						return true
	return false

func _try_tribute(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var charger := gs.players[player_id]
	# Enumerate all (tribute, realm) combos. We only charge if the target(s)
	# can pay from bank — otherwise they'd dismantle their laid realms, which
	# leaks realm cards permanently into banks (they can never re-enter play).
	var options: Array = []
	for c in charger.hand:
		if c.type != CardData.Type.TRIBUTE:
			continue
		if c.realms.is_empty():
			for r in charger.realms.keys():
				var count: int = (charger.realms[r] as Array).size()
				if count == 0:
					continue
				var rent := RentCalculator.rent(charger, r, false)
				if rent <= 0:
					continue
				var target := _pick_wealthiest_opponent(gs, rent)
				if target == -1:
					continue
				options.append({
					"card": c, "realm": r, "rent": rent, "kind": "toll",
					"target": target, "payer_count": 1,
				})
		else:
			for r in c.realms:
				if not charger.realms.has(r):
					continue
				var count: int = (charger.realms[r] as Array).size()
				if count == 0:
					continue
				var rent := RentCalculator.rent(charger, r, false)
				if rent <= 0:
					continue
				if not _all_opponents_can_pay(gs, rent):
					continue
				var payer_count := gs.players.size() - 1
				options.append({
					"card": c, "realm": r, "rent": rent, "kind": "standard",
					"payer_count": payer_count,
				})
	if options.is_empty():
		return false
	# Score each: total pearls at stake (cap per payer by their bank).
	options.sort_custom(func(a, b):
		var av: int = int(a["rent"]) * (a.get("payer_count", 1) as int)
		var bv: int = int(b["rent"]) * (b.get("payer_count", 1) as int)
		return av > bv
	)
	var pick: Dictionary = options[0]
	# High Tide: free rider on the tribute — no extra play cost — so add it
	# whenever the extra rent beats banking the card and the doubled amount
	# is still payable from bank.
	var ht_card: CardData = null
	var doubled: int = int(pick["rent"]) * 2
	var payable_when_doubled := true
	if pick["kind"] == "standard":
		payable_when_doubled = _all_opponents_can_pay(gs, doubled)
	else:
		var t: PlayerState = gs.players[int(pick["target"])]
		payable_when_doubled = t.total_bank_value() >= doubled
	if payable_when_doubled:
		var payers: int = pick.get("payer_count", 1)
		var extra: int = int(pick["rent"]) * payers
		if extra > HIGH_TIDE_BANK_VALUE:
			ht_card = _find_action(charger, "high_tide")
	var target_id: int = -1
	if pick["kind"] == "toll":
		target_id = pick["target"]
	var pending := tm.initiate_tribute(pick["card"], pick["realm"], target_id, ht_card)
	if pending == null:
		return false
	await _run_refusal_window(tm, all_ais)
	var owed: Variant = tm.resolve_pending()
	if owed is Dictionary:
		await _settle_owed(tm, owed)
	return true

func _all_opponents_can_pay(gs: GameState, amount: int) -> bool:
	for p in gs.players:
		if p.id == player_id:
			continue
		if p.total_bank_value() < amount:
			return false
	return true

func _pick_wealthiest_opponent(gs: GameState, min_bank: int) -> int:
	var best_id := -1
	var best_bank := -1
	for p in gs.players:
		if p.id == player_id:
			continue
		var bv := p.total_bank_value()
		if bv < min_bank:
			continue
		if bv > best_bank:
			best_bank = bv
			best_id = p.id
	return best_id

func _try_kraken(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var thief := gs.players[player_id]
	var kraken := _find_action(thief, "krakens_grasp")
	if kraken == null:
		return false
	var best_target := -1
	var best_realm := ""
	var best_rent := 0
	for p in gs.players:
		if p.id == player_id:
			continue
		for r in p.realms.keys():
			if not p.is_realm_complete(r):
				continue
			var rent := RentCalculator.rent(p, r, false)
			if rent > best_rent:
				best_rent = rent
				best_target = p.id
				best_realm = r
	if best_target == -1:
		return false
	var pending := tm.initiate_krakens_grasp(kraken, best_target, best_realm)
	if pending == null:
		return false
	await _run_refusal_window(tm, all_ais)
	tm.resolve_pending()
	return true

func _try_slippery_eel(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var thief := gs.players[player_id]
	var eel := _find_action(thief, "slippery_eel")
	if eel == null:
		return false
	# Find leader's most valuable loose realm card that we can place somewhere.
	var leader := _pick_leading_opponent(gs)
	if leader == -1:
		return false
	var target: PlayerState = gs.players[leader]
	var best_card: CardData = null
	var best_dest := ""
	var best_score := -1
	for r in target.realms.keys():
		# Include complete sets that have surplus — the resolver now allows
		# stealing surplus without breaking the set below its target size.
		if not target.has_stealable_loose_card(r):
			continue
		var stack: Array = target.realms[r]
		for c in stack:
			# Choose the realm on our side that maximises progress.
			var dest := _best_destination_for(thief, c)
			if dest == "":
				continue
			var score: int = c.value * 10
			# Bonus if it completes one of our sets.
			var my_count: int = 0
			if thief.realms.has(dest):
				my_count = (thief.realms[dest] as Array).size()
			if my_count + 1 >= Realms.size_of(dest):
				score += 100
			if score > best_score:
				best_score = score
				best_card = c
				best_dest = dest
	if best_card == null:
		return false
	var pending := tm.initiate_slippery_eel(eel, leader, best_card, best_dest)
	if pending == null:
		return false
	await _run_refusal_window(tm, all_ais)
	tm.resolve_pending()
	return true

func _try_toll(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var charger := gs.players[player_id]
	var toll := _find_action(charger, "toll_of_the_tides")
	if toll == null:
		return false
	# Target the wealthiest opponent who can pay from bank — avoids leaking
	# laid realm cards into a bank where they'd get stuck.
	var target := _pick_wealthiest_opponent(gs, ActionResolver.TOLL_OF_THE_TIDES_AMOUNT)
	if target == -1:
		return false
	var pending := tm.initiate_toll_of_the_tides(toll, target)
	if pending == null:
		return false
	await _run_refusal_window(tm, all_ais)
	var owed: Variant = tm.resolve_pending()
	if owed is Dictionary:
		await _settle_owed(tm, owed)
	return true

func _try_feast(tm: TurnManager, all_ais: Dictionary) -> bool:
	var gs := tm.game_state
	var charger := gs.players[player_id]
	var feast := _find_action(charger, "mermaids_feast")
	if feast == null:
		return false
	if not _all_opponents_can_pay(gs, ActionResolver.MERMAIDS_FEAST_AMOUNT):
		return false
	var pending := tm.initiate_mermaids_feast(feast)
	if pending == null:
		return false
	await _run_refusal_window(tm, all_ais)
	var owed: Variant = tm.resolve_pending()
	if owed is Dictionary:
		await _settle_owed(tm, owed)
	return true

func _try_ride(tm: TurnManager, player: PlayerState) -> bool:
	var ride := _find_action(player, "ride_the_current")
	if ride == null:
		return false
	return tm.play_ride_the_current(ride)

func _try_bank(tm: TurnManager, player: PlayerState) -> bool:
	# Bank the least valuable card that is bankable and that we don't want to
	# keep. Never bank Siren's Refusal. Prefer pearls / Ride first.
	var ranked := _hand_sorted_by_discard_preference(player)
	for c in ranked:
		if not c.can_bank():
			continue
		if c.action_effect == "sirens_refusal":
			continue
		if tm.bank_card(c):
			return true
	return false

# --- Refusal window ------------------------------------------------------

func _run_refusal_window(tm: TurnManager, all_ais: Dictionary) -> void:
	var pending := tm.game_state.pending_action
	if pending == null:
		return
	# Iterate targets in a stable order.
	var targets: Array[int] = pending.targets.duplicate()
	for target_id in targets:
		await _refusal_cycle(tm, all_ais, target_id)

# Per-target refusal cycle. Loops so counter-refusals chain unlimited per
# the rules: defender refuses → initiator can counter → defender can counter
# that, and on until whichever side is next either has no Refusal card or
# declines. Greedy AI still returns false when asked to counter (heuristic
# in _wants_to_refuse), so the loop closes quickly if AI is the one being
# asked — but the human always gets a chance to counter.
func _refusal_cycle(tm: TurnManager, all_ais: Dictionary, target_id: int) -> void:
	while true:
		var pa: PendingAction = tm.game_state.pending_action
		if pa == null:
			return
		var next_refuser_id: int = pa.next_refuser_for(target_id)
		var refuser: PlayerState = tm.game_state.players[next_refuser_id]
		var refusal_card := _find_action(refuser, "sirens_refusal")
		if refusal_card == null:
			return
		var wants_refuse := false
		var refuser_ai_var: Variant = all_ais.get(next_refuser_id)
		if refuser_ai_var != null:
			var refuser_ai: AIOpponent = refuser_ai_var
			wants_refuse = refuser_ai._wants_to_refuse(tm.game_state, pa, target_id)
		elif human_refusal_hook.is_valid():
			wants_refuse = await human_refusal_hook.call(target_id, pa)
		if not wants_refuse:
			return
		tm.refuse(target_id, next_refuser_id, refusal_card)

func _wants_to_refuse(gs: GameState, pending: PendingAction, target_id: int) -> bool:
	if target_id != player_id:
		return false
	match pending.kind:
		"krakens_grasp":
			return true
		"slippery_eel":
			var stolen_var: Variant = pending.payload.get("stolen_card")
			if not (stolen_var is CardData):
				return false
			var stolen: CardData = stolen_var
			# Refuse if the stolen card is from our most-progressed incomplete set.
			var me: PlayerState = gs.players[player_id]
			for r in me.realms.keys():
				var stack: Array = me.realms[r]
				if stack.has(stolen):
					var count: int = stack.size()
					var target_size: int = Realms.size_of(r)
					return count >= target_size - 1
			return false
		"trade_winds":
			return true
		"tribute", "sirens_toll", "toll_of_the_tides":
			var per: int = int(pending.payload.get("per_target", 0))
			return per >= 3
		"mermaids_feast":
			return false
	return false

# --- Small helpers -------------------------------------------------------

func _find_action(player: PlayerState, effect: String) -> CardData:
	for c in player.hand:
		if c.action_effect == effect:
			return c
	return null

func _candidate_realms(card: CardData) -> Array[String]:
	var out: Array[String] = []
	if card.type == CardData.Type.REALM:
		out.append(card.realm)
	elif card.type == CardData.Type.WILD_REALM:
		for r in card.realms:
			out.append(r)
	return out

func _best_destination_for(player: PlayerState, card: CardData) -> String:
	var best := ""
	var best_score := -1
	for r in _candidate_realms(card):
		var current: int = 0
		if player.realms.has(r):
			current = (player.realms[r] as Array).size()
		if current >= Realms.size_of(r):
			continue
		var progress_after: int = current + 1
		var target: int = Realms.size_of(r)
		var score: int = progress_after * 100 / target
		if score > best_score:
			best_score = score
			best = r
	return best

func _pick_leading_opponent(gs: GameState) -> int:
	var best_id: int = -1
	var best_completed: int = -1
	var best_progress: int = -1
	for p in gs.players:
		if p.id == player_id:
			continue
		var completed := p.completed_realm_count()
		var progress: int = 0
		for r in p.realms.keys():
			progress += (p.realms[r] as Array).size()
		if completed > best_completed \
			or (completed == best_completed and progress > best_progress):
			best_completed = completed
			best_progress = progress
			best_id = p.id
	return best_id

func _settle_owed(tm: TurnManager, owed: Dictionary) -> void:
	var gs := tm.game_state
	var receiver: PlayerState = gs.players[player_id]
	for key in owed.keys():
		var payer_id: int = int(key)
		var amount: int = int(owed[key])
		if amount <= 0:
			continue
		var payer: PlayerState = gs.players[payer_id]
		# Give the UI a chance to prompt a human payer for a manual pick
		# (e.g. "no pearls in bank — choose which realm cards to spend").
		# Hook returns null for payers it doesn't want to handle.
		if human_payment_hook.is_valid():
			var picks: Variant = await human_payment_hook.call(payer, receiver, amount)
			if picks is Dictionary:
				var from_bank: Array[CardData] = picks.get("bank", [] as Array[CardData])
				var from_realms: Array[CardData] = picks.get("realms", [] as Array[CardData])
				PaymentResolver.pay(payer, receiver, amount, from_bank, from_realms)
				tm.log_payment(payer_id, player_id, from_bank, from_realms)
				continue
		# Fall-through: compute picks so we can log, then apply.
		var auto_picks := PaymentResolver.smart_picks(payer, amount)
		PaymentResolver.pay(payer, receiver, amount, auto_picks["bank"], auto_picks["realms"])
		tm.log_payment(payer_id, player_id, auto_picks["bank"], auto_picks["realms"])

# Delegates to PaymentResolver.settle_smart — same realm-layout-aware pool
# order, same min-overpay-with-tiebreak selection.
func _settle_smart(payer: PlayerState, receiver: PlayerState, amount: int) -> int:
	return PaymentResolver.settle_smart(payer, receiver, amount)

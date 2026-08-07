class_name PaymentResolver
extends RefCounted

# Moves cards from the payer's bank and/or laid realms to the receiver's bank.
# The spec's payment rule: no change is given, and a player with nothing pays
# nothing. Selection is the payer's choice — pay() takes explicit lists, while
# settle_greedy() is a convenience for tests and the AI.

static func total_available(player: PlayerState) -> int:
	# Sums only positive-value cards. Zero-value cards (e.g. Rainbow Conch,
	# which has pearl value 0) can't pay off any debt, so they don't count
	# toward "can this player still pay?" — otherwise the underpayment
	# assertion in pay() would demand they be sent as courtesy giveaways.
	var total := 0
	for c in player.bank:
		if c.value > 0:
			total += c.value
	for r in player.realms.keys():
		var stack: Array = player.realms[r]
		for c in stack:
			if c.value > 0:
				total += c.value
	return total

static func pay(
	payer: PlayerState,
	receiver: PlayerState,
	amount: int,
	from_bank: Array[CardData] = [],
	from_realms: Array[CardData] = [],
) -> int:
	if amount <= 0:
		return 0
	var paid_value := 0
	for c in from_bank:
		paid_value += c.value
	for c in from_realms:
		paid_value += c.value

	if paid_value < amount:
		# Underpayment is only legal if the payer has nothing more to give.
		var available := total_available(payer)
		assert(paid_value == available,
			"Underpayment: paid %d of %d owed but %d was still available" %
				[paid_value, amount, available])
	# Overpayment is allowed by the caller (no change is given); the excess
	# just becomes a gift. We don't reject it — the caller chose those cards.

	payer.pay_cards(from_bank, from_realms)
	var moved: Array[CardData] = []
	moved.append_array(from_bank)
	moved.append_array(from_realms)
	receiver.receive_payment(moved)
	return paid_value

static func settle_greedy(payer: PlayerState, receiver: PlayerState, amount: int) -> int:
	if amount <= 0:
		return 0
	var from_bank: Array[CardData] = []
	var from_realms: Array[CardData] = []
	var bank_total := payer.total_bank_value()

	if bank_total >= amount:
		# Bank can cover — pick the subset that minimises overpayment so a
		# 7 P bank paying 4 P doesn't get zeroed by a naive smallest-first
		# sweep that overshoots on the last coin.
		from_bank = _min_overpay_subset(payer.bank, amount)
	else:
		# Bank is short — spend it all, then raid realms smallest-first for
		# the remainder (still not optimal across realms, but a rare edge).
		from_bank = payer.bank.duplicate()
		var remaining := amount - bank_total
		var realm_cards: Array[CardData] = []
		for r in payer.realms.keys():
			var stack: Array = payer.realms[r]
			for c in stack:
				realm_cards.append(c)
		realm_cards.sort_custom(func(a, b): return a.value < b.value)
		for c in realm_cards:
			if remaining <= 0:
				break
			from_realms.append(c)
			remaining -= c.value

	return pay(payer, receiver, amount, from_bank, from_realms)

# Subset of `cards` whose value sum is >= amount and minimises (sum - amount).
# Ties broken by `prefer_fewer_cards`:
#   false → keep large denominations (subset with smallest max card wins). Use
#           for bank pools — spending the small change first leaves single-shot
#           firepower behind.
#   true  → protect set progress (subset with fewest cards wins). Use for
#           per-realm pools — `{3}` beats `{1,2}` because taking one card out
#           of the realm hurts completion less than taking two.
# Brute-forced via bitmask — bank/realm sizes are small; falls back to
# smallest-first if the pool is huge.
static func _min_overpay_subset(cards: Array, amount: int, prefer_fewer_cards: bool = false) -> Array[CardData]:
	var out: Array[CardData] = []
	if amount <= 0 or cards.is_empty():
		return out
	var n := cards.size()
	if n > 20:
		var sorted := cards.duplicate()
		sorted.sort_custom(func(a, b): return a.value < b.value)
		var remaining := amount
		for c in sorted:
			if remaining <= 0:
				break
			out.append(c)
			remaining -= c.value
		return out

	var best_sum := -1
	var best_max := -1
	var best_count := -1
	var best_mask := 0
	var total_masks := 1 << n
	for mask in range(1, total_masks):
		var s := 0
		var mx := 0
		var cnt := 0
		for i in range(n):
			if mask & (1 << i):
				s += cards[i].value
				cnt += 1
				if cards[i].value > mx:
					mx = cards[i].value
		if s < amount:
			continue
		var better := false
		if best_sum < 0 or s < best_sum:
			better = true
		elif s == best_sum:
			if prefer_fewer_cards:
				# Realm mode: fewer cards spent = more cards kept in the realm.
				# Secondary tiebreak still favours keeping big cards.
				if cnt < best_count or (cnt == best_count and mx < best_max):
					better = true
			else:
				# Bank mode: keep big coins; secondary tiebreak = fewer cards.
				if mx < best_max or (mx == best_max and cnt < best_count):
					better = true
		if better:
			best_sum = s
			best_max = mx
			best_count = cnt
			best_mask = mask
	if best_mask == 0:
		return out
	for i in range(n):
		if best_mask & (1 << i):
			out.append(cards[i])
	return out

# Realm-layout-aware payment: pools are drained in order of least-strategic
# first (bank pearls → dead banked realm cards → weakest incomplete realms →
# strongest incomplete realms → complete realms). Within each pool, the
# min-overpay subset (see _min_overpay_subset) is taken. Filters zero-value
# cards from every pool so Rainbow Conch etc. can't be dumped as courtesy.
static func settle_smart(payer: PlayerState, receiver: PlayerState, amount: int) -> int:
	if amount <= 0:
		return 0
	var picks := smart_picks(payer, amount)
	return pay(payer, receiver, amount, picks["bank"], picks["realms"])

# Compute the cards `settle_smart` WOULD spend without actually applying the
# payment. Used by the HvH online flow so the payer's peer can decide what to
# pay, broadcast the selection, and let both peers apply pay(...) with the
# same explicit card lists.
static func smart_picks(payer: PlayerState, amount: int) -> Dictionary:
	var out := {"bank": [] as Array[CardData], "realms": [] as Array[CardData]}
	if amount <= 0:
		return out
	var from_bank: Array[CardData] = out["bank"]
	var from_realms: Array[CardData] = out["realms"]
	var remaining := amount

	var bank_non_realm: Array[CardData] = []
	var bank_realm: Array[CardData] = []
	for c in payer.bank:
		if c.value <= 0:
			continue
		if c.type == CardData.Type.REALM or c.type == CardData.Type.WILD_REALM:
			bank_realm.append(c)
		else:
			bank_non_realm.append(c)

	# Incomplete realms grouped and ordered by progress ratio ASC — the
	# further from completion, the more expendable. A 1/3 realm's card is
	# less painful to give up than a 2/3 realm's card, which would kill a
	# near-win.
	var incomplete_groups: Array = []
	for r in payer.realms.keys():
		if payer.is_realm_complete(r):
			continue
		var stack: Array = payer.realms[r]
		var positive: Array[CardData] = []
		for c in stack:
			if c.value > 0:
				positive.append(c)
		if positive.is_empty():
			continue
		var target_size := Realms.size_of(r)
		var progress := float(stack.size()) / float(target_size) if target_size > 0 else 1.0
		incomplete_groups.append({"progress": progress, "cards": positive})
	incomplete_groups.sort_custom(func(a, b): return a["progress"] < b["progress"])

	var complete: Array[CardData] = []
	for r in payer.realms.keys():
		if not payer.is_realm_complete(r):
			continue
		for c in payer.realms[r]:
			if c.value > 0:
				complete.append(c)

	var pools: Array = []
	pools.append({"cards": bank_non_realm, "bucket": "bank"})
	pools.append({"cards": bank_realm, "bucket": "bank"})
	for g in incomplete_groups:
		pools.append({"cards": g["cards"], "bucket": "realms"})
	pools.append({"cards": complete, "bucket": "realms"})

	for pool in pools:
		if remaining <= 0:
			break
		var pool_cards: Array[CardData] = pool["cards"]
		if pool_cards.is_empty():
			continue
		var bucket: String = pool["bucket"]
		var pool_total := 0
		for c in pool_cards:
			pool_total += c.value
		var target := from_bank if bucket == "bank" else from_realms
		if pool_total >= remaining:
			# Realm pools protect set progress (fewer-cards tiebreak); bank
			# pools preserve high-denomination coins (keep-large tiebreak).
			var prefer_fewer := bucket == "realms"
			var picks := _min_overpay_subset(pool_cards, remaining, prefer_fewer)
			for p in picks:
				target.append(p)
			remaining = 0
		else:
			for c in pool_cards:
				target.append(c)
			remaining -= pool_total

	return out

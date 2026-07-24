class_name PaymentResolver
extends RefCounted

# Moves cards from the payer's bank and/or laid realms to the receiver's bank.
# The spec's payment rule: no change is given, and a player with nothing pays
# nothing. Selection is the payer's choice — pay() takes explicit lists, while
# settle_greedy() is a convenience for tests and the AI.

static func total_available(player: PlayerState) -> int:
	var total := player.total_bank_value()
	for r in player.realms.keys():
		var stack: Array = player.realms[r]
		for c in stack:
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
	var remaining := amount

	# Bank first, smallest coins first so we don't overpay by more than needed.
	var bank_sorted := payer.bank.duplicate()
	bank_sorted.sort_custom(func(a, b): return a.value < b.value)
	for c in bank_sorted:
		if remaining <= 0:
			break
		from_bank.append(c)
		remaining -= c.value

	if remaining > 0:
		# Then raid realms, again smallest-first to minimise the loss.
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

extends GutTest

func _pearl(id: String, value: int) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "%d Pearls" % value
	c.type = CardData.Type.PEARL
	c.value = value
	return c

func _realm(id: String, realm: String, value: int = 2) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _stock_bank(p: PlayerState, values: Array[int]) -> void:
	var i := 0
	for v in values:
		p.bank.append(_pearl("p%d_%d" % [p.id, i], v))
		i += 1

# ---- Explicit-selection pay() ----

func test_pay_transfers_selected_bank_cards() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1, 2, 5] as Array[int])
	var owed := 4
	var give: Array[CardData] = [payer.bank[1], payer.bank[2]] # 2 + 5 = 7
	var moved := PaymentResolver.pay(payer, receiver, owed, give, [] as Array[CardData])
	assert_eq(moved, 7, "Overpayment is allowed — no change is given")
	assert_eq(payer.bank.size(), 1)
	assert_eq(receiver.bank.size(), 2)
	assert_eq(receiver.total_bank_value(), 7)

func test_pay_zero_is_noop() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1, 2] as Array[int])
	assert_eq(PaymentResolver.pay(payer, receiver, 0), 0)
	assert_eq(payer.bank.size(), 2)
	assert_eq(receiver.bank.size(), 0)

func test_paying_with_realm_cards() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	var r1 := _realm("r1", "Coral Gardens", 2)
	var r2 := _realm("r2", "Coral Gardens", 2)
	payer.hand.append_array([r1, r2])
	payer.play_realm(r1, "Coral Gardens")
	payer.play_realm(r2, "Coral Gardens")
	var moved := PaymentResolver.pay(
		payer, receiver, 3,
		[] as Array[CardData],
		[r1, r2] as Array[CardData],
	)
	assert_eq(moved, 4)
	assert_eq((payer.realms["Coral Gardens"] as Array).size(), 0)
	# Realm cards paid to the receiver are laid onto their board (auto-routed
	# to Coral Gardens, since that's the plain realm's only legal home). They
	# do NOT enter the receiver's bank — that used to be a one-way leak.
	assert_eq(receiver.bank.size(), 0, "Paid realm cards should not enter bank")
	assert_eq((receiver.realms["Coral Gardens"] as Array).size(), 2,
		"Paid realm cards land on receiver's board")

func test_paying_from_bank_and_realms_mixed() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1] as Array[int])
	var r1 := _realm("r1", "Sunken Temple", 3)
	payer.hand.append(r1)
	payer.play_realm(r1, "Sunken Temple")
	var moved := PaymentResolver.pay(
		payer, receiver, 4,
		[payer.bank[0]] as Array[CardData],
		[r1] as Array[CardData],
	)
	assert_eq(moved, 4)
	assert_eq(payer.bank.size(), 0)
	assert_eq((payer.realms["Sunken Temple"] as Array).size(), 0)
	# The 1-pearl banked coin lands in the bank; the Sunken Temple realm
	# card is auto-laid on the receiver's board.
	assert_eq(receiver.total_bank_value(), 1)
	assert_eq((receiver.realms["Sunken Temple"] as Array).size(), 1)

# ---- Underpayment (no change given) ----

func test_underpayment_allowed_when_bank_empty() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	# Payer has nothing at all
	var moved := PaymentResolver.pay(payer, receiver, 5)
	assert_eq(moved, 0, "A player with nothing pays nothing")
	assert_eq(receiver.bank.size(), 0)

func test_underpayment_allowed_when_paying_all_available() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1, 1] as Array[int])
	var give: Array[CardData] = [payer.bank[0], payer.bank[1]]
	var moved := PaymentResolver.pay(payer, receiver, 5, give, [] as Array[CardData])
	assert_eq(moved, 2)
	assert_eq(payer.bank.size(), 0)
	assert_eq(receiver.total_bank_value(), 2)

# ---- settle_greedy convenience ----

func test_settle_greedy_uses_bank_first() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1, 2, 3] as Array[int])
	var r1 := _realm("r1", "Coral Gardens", 2)
	payer.hand.append(r1)
	payer.play_realm(r1, "Coral Gardens")
	var moved := PaymentResolver.settle_greedy(payer, receiver, 3)
	assert_eq(moved, 3)
	assert_eq((payer.realms["Coral Gardens"] as Array).size(), 1,
		"Realms untouched while bank could cover")
	# Bank pool prefers keeping large denominations — spends 1+2, keeps the 3.
	assert_eq(payer.bank.size(), 1, "3-pearl preserved for future single-shot debts")

func test_settle_greedy_minimises_overpayment() -> void:
	# Regression: a 7 P bank paying 4 P used to zero the bank via smallest-first
	# greedy that overshot on the final coin. The optimal subset leaves 3 P.
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [3, 4] as Array[int])
	var moved := PaymentResolver.settle_greedy(payer, receiver, 4)
	assert_eq(moved, 4, "Exact match preferred over paying whole bank")
	assert_eq(payer.total_bank_value(), 3, "3 P left in payer's bank")
	assert_eq(receiver.total_bank_value(), 4)

func test_settle_greedy_raids_realms_when_bank_short() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1] as Array[int])
	var r1 := _realm("r1", "Sunken Temple", 3)
	payer.hand.append(r1)
	payer.play_realm(r1, "Sunken Temple")
	var moved := PaymentResolver.settle_greedy(payer, receiver, 3)
	assert_eq(moved, 4, "Overpay by 1 rather than fail")
	assert_eq(payer.bank.size(), 0)
	assert_eq((payer.realms["Sunken Temple"] as Array).size(), 0)

func test_settle_greedy_broke_player_pays_nothing() -> void:
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	assert_eq(PaymentResolver.settle_greedy(payer, receiver, 7), 0)

func test_total_available_sums_bank_and_realms() -> void:
	var p := PlayerState.new(0)
	_stock_bank(p, [1, 5] as Array[int])
	var r1 := _realm("r1", "Sunken Temple", 3)
	p.hand.append(r1)
	p.play_realm(r1, "Sunken Temple")
	assert_eq(PaymentResolver.total_available(p), 9)

# ---- settle_smart tiebreaks ----

func test_settle_smart_bank_keeps_large_denominations() -> void:
	# Bank [1, 2, 3] paying 3 → picks {1, 2} to preserve the 3-pearl for a
	# future single-shot debt. "Keep large denominations" tiebreak.
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	_stock_bank(payer, [1, 2, 3] as Array[int])
	var moved := PaymentResolver.settle_smart(payer, receiver, 3)
	assert_eq(moved, 3)
	assert_eq(payer.bank.size(), 1, "3-pearl preserved")
	assert_eq(payer.total_bank_value(), 3)

func test_settle_smart_realm_pool_spends_lowest_values() -> void:
	# Realm pool [1P, 2P, 3P] paying 3 → picks {1, 2} to spend the smallest
	# cards and keep the 3 for a future single-shot debt. Feedback: don't
	# preserve set progress at all costs; low-value cards are the ones you
	# actually want to hand over first.
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	for v in [1, 2, 3]:
		var c := _realm("temple_%d" % v, "Sunken Temple", v)
		payer.hand.append(c)
		payer.play_realm(c, "Sunken Temple")
	var moved := PaymentResolver.settle_smart(payer, receiver, 3)
	assert_eq(moved, 3)
	var left: Array = payer.realms["Sunken Temple"]
	assert_eq(left.size(), 1, "Only the 3-pearl card remains")
	assert_eq((left[0] as CardData).value, 3)

func test_settle_smart_skips_zero_value_cards() -> void:
	# A 0-value card in a realm shouldn't get shipped as a courtesy giveaway
	# when the debt can be satisfied without it.
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	var conch := _realm("conch", "Sunken Temple", 0)
	var pearl := _realm("gem", "Sunken Temple", 3)
	for c in [conch, pearl]:
		payer.hand.append(c)
		payer.play_realm(c, "Sunken Temple")
	var moved := PaymentResolver.settle_smart(payer, receiver, 2)
	assert_eq(moved, 3, "Pays with the 3-value card, overpaying by 1")
	var left: Array = payer.realms["Sunken Temple"]
	assert_eq(left.size(), 1)
	assert_eq((left[0] as CardData).id, "conch", "Zero-value card stays put")

func test_settle_smart_prefers_lower_progress_realm() -> void:
	# Two realms both able to cover a 2 P debt:
	#   - Sunken Temple (3-size): 1 card at 3 P → 1/3 progress
	#   - Kelp Forest (2-size): 1 card at 3 P → 1/2 progress
	# Sunken Temple has lower progress → its pool is drained first, so it
	# loses the card. Kelp Forest is preserved.
	var payer := PlayerState.new(0)
	var receiver := PlayerState.new(1)
	var temple := _realm("t1", "Sunken Temple", 3)
	var kelp := _realm("k1", "Kelp Forest", 3)
	for c in [temple, kelp]:
		payer.hand.append(c)
	payer.play_realm(temple, "Sunken Temple")
	payer.play_realm(kelp, "Kelp Forest")
	PaymentResolver.settle_smart(payer, receiver, 2)
	assert_eq((payer.realms["Sunken Temple"] as Array).size(), 0)
	assert_eq((payer.realms["Kelp Forest"] as Array).size(), 1, "Nearer-complete realm untouched")

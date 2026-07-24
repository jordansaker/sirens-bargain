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
	assert_eq(payer.bank.size(), 1, "Greedy took smallest coins first")

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

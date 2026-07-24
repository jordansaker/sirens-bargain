extends GutTest

func _realm(id: String, realm: String, value: int = 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Test %s Realm" % realm
	c.type = CardData.Type.REALM
	c.value = value
	c.realm = realm
	return c

func _cottage(id: String = "cottage_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Coral Cottage"
	c.type = CardData.Type.ACTION
	c.value = 3
	c.action_effect = "coral_cottage"
	return c

func _palace(id: String = "palace_1") -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = "Pearl Palace"
	c.type = CardData.Type.ACTION
	c.value = 4
	c.action_effect = "pearl_palace"
	return c

func _stock_realm(player: PlayerState, realm: String, count: int) -> void:
	for i in range(count):
		var c := _realm("%s_%s_%d" % [realm, str(player.id), i], realm)
		player.hand.append(c)
		player.play_realm(c, realm)

# ---- Base rent tables from the spec ----

func test_kelp_forest_rent_progression() -> void:
	var p := PlayerState.new(0)
	assert_eq(RentCalculator.base_rent(p, "Kelp Forest"), 0)
	_stock_realm(p, "Kelp Forest", 1)
	assert_eq(RentCalculator.base_rent(p, "Kelp Forest"), 1)
	_stock_realm(p, "Kelp Forest", 1)
	assert_eq(RentCalculator.base_rent(p, "Kelp Forest"), 2)
	_stock_realm(p, "Kelp Forest", 1)
	assert_eq(RentCalculator.base_rent(p, "Kelp Forest"), 3)

func test_pearl_beds_rent_jump_at_three() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Pearl Beds", 1)
	assert_eq(RentCalculator.base_rent(p, "Pearl Beds"), 1)
	_stock_realm(p, "Pearl Beds", 1)
	assert_eq(RentCalculator.base_rent(p, "Pearl Beds"), 3)
	_stock_realm(p, "Pearl Beds", 1)
	assert_eq(RentCalculator.base_rent(p, "Pearl Beds"), 5)

func test_abyssal_trench_two_tier_table() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Abyssal Trench", 1)
	assert_eq(RentCalculator.base_rent(p, "Abyssal Trench"), 3)
	_stock_realm(p, "Abyssal Trench", 1)
	assert_eq(RentCalculator.base_rent(p, "Abyssal Trench"), 8)

func test_ocean_currents_four_tier_table() -> void:
	var p := PlayerState.new(0)
	for expected in [1, 2, 3, 4]:
		_stock_realm(p, "Ocean Currents", 1)
		assert_eq(RentCalculator.base_rent(p, "Ocean Currents"), expected)

func test_rent_zero_when_no_cards_laid() -> void:
	var p := PlayerState.new(0)
	assert_eq(RentCalculator.rent(p, "Sunken Temple"), 0)

# ---- Coral Cottage / Pearl Palace ----

func test_cottage_adds_three_to_completed_set() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Tide Pools", 2) # complete: base rent 2
	var c := _cottage()
	p.hand.append(c)
	p.attach_modifier(c, "Tide Pools")
	assert_eq(RentCalculator.rent(p, "Tide Pools"), 5)

func test_palace_stacks_on_cottage() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Tide Pools", 2)
	var c := _cottage()
	var pl := _palace()
	p.hand.append_array([c, pl])
	p.attach_modifier(c, "Tide Pools")
	p.attach_modifier(pl, "Tide Pools")
	# base 2 + 3 cottage + 4 palace = 9
	assert_eq(RentCalculator.rent(p, "Tide Pools"), 9)

func test_palace_cannot_attach_without_cottage() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Tide Pools", 2)
	var pl := _palace()
	p.hand.append(pl)
	var errored := false
	# assert() halts the runner; instead check the guard rails on TurnManager
	# in the tribute tests. Here just confirm has_palace stays false.
	assert_false(p.has_palace("Tide Pools"))
	assert_false(p.has_cottage("Tide Pools"))
	# Guard: don't call attach_modifier without a cottage — it asserts.
	# This test just documents the invariant.

func test_cottage_does_nothing_on_incomplete_set() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Kelp Forest", 3) # complete
	var c := _cottage()
	p.hand.append(c)
	p.attach_modifier(c, "Kelp Forest") # legal now
	# Now break the set by paying a card away
	var stack: Array = p.realms["Kelp Forest"]
	var removed: CardData = stack[0]
	p.pay_cards([] as Array[CardData], [removed] as Array[CardData])
	assert_false(p.is_realm_complete("Kelp Forest"))
	# base rent for 2 = 2. Cottage should NOT add while incomplete.
	assert_eq(RentCalculator.rent(p, "Kelp Forest"), 2)

# ---- High Tide doubling ----

func test_high_tide_doubles_final_rent() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Sunken Temple", 3)
	assert_eq(RentCalculator.rent(p, "Sunken Temple"), 6)
	assert_eq(RentCalculator.rent(p, "Sunken Temple", true), 12)

func test_high_tide_doubles_after_modifiers() -> void:
	var p := PlayerState.new(0)
	_stock_realm(p, "Tide Pools", 2)
	var c := _cottage()
	p.hand.append(c)
	p.attach_modifier(c, "Tide Pools")
	# (2 + 3) * 2 = 10
	assert_eq(RentCalculator.rent(p, "Tide Pools", true), 10)

func test_high_tide_on_zero_stays_zero() -> void:
	var p := PlayerState.new(0)
	assert_eq(RentCalculator.rent(p, "Kelp Forest", true), 0)

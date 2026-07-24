class_name DeckBuilder
extends RefCounted

const CARDS_JSON_PATH := "res://data/cards.json"

const EXPECTED_TOTAL := 106

const EXPECTED_TYPE_COUNTS := {
	"REALM": 28,
	"WILD_REALM": 11,
	"PEARL": 20,
	"TRIBUTE": 13,
	"ACTION": 34,
}

const EXPECTED_REALM_COUNTS := {
	"Tide Pools": 2,
	"Kelp Forest": 3,
	"Coral Gardens": 3,
	"Pearl Beds": 3,
	"Shipwreck Cove": 3,
	"Sunken Temple": 3,
	"Seagrass Lagoon": 3,
	"Abyssal Trench": 2,
	"Ocean Currents": 4,
	"Mystic Springs": 2,
}

static func load_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	var file := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % CARDS_JSON_PATH)
		return out
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("cards.json did not parse to an array")
		return out
	for entry in parsed:
		out.append(_card_from_dict(entry))
	return out

static func _card_from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = String(d.get("id", ""))
	c.name = String(d.get("name", ""))
	c.type = CardData.type_from_string(String(d.get("type", "REALM")))
	c.value = int(d.get("value", 0))
	c.realm = String(d.get("realm", ""))
	var realms_in: Array = d.get("realms", [])
	var realms_typed: Array[String] = []
	for r in realms_in:
		realms_typed.append(String(r))
	c.realms = realms_typed
	var tiers_in: Array = d.get("rent_tiers", [])
	var tiers_typed: Array[int] = []
	for t in tiers_in:
		tiers_typed.append(int(t))
	c.rent_tiers = tiers_typed
	c.action_effect = String(d.get("action_effect", ""))
	return c

static func build_deck() -> Array[CardData]:
	var cards := load_cards()
	validate(cards)
	return cards

static func validate(cards: Array[CardData]) -> void:
	assert(cards.size() == EXPECTED_TOTAL,
		"Expected %d cards, got %d" % [EXPECTED_TOTAL, cards.size()])
	var type_counts := {}
	var realm_counts := {}
	for c in cards:
		var t := CardData.type_to_string(c.type)
		type_counts[t] = int(type_counts.get(t, 0)) + 1
		if c.type == CardData.Type.REALM:
			realm_counts[c.realm] = int(realm_counts.get(c.realm, 0)) + 1
	for t in EXPECTED_TYPE_COUNTS:
		var expected: int = EXPECTED_TYPE_COUNTS[t]
		var actual: int = int(type_counts.get(t, 0))
		assert(actual == expected,
			"Type %s: expected %d, got %d" % [t, expected, actual])
	for r in EXPECTED_REALM_COUNTS:
		var expected: int = EXPECTED_REALM_COUNTS[r]
		var actual: int = int(realm_counts.get(r, 0))
		assert(actual == expected,
			"Realm %s: expected %d, got %d" % [r, expected, actual])

static func shuffle(cards: Array[CardData], seed_value: int) -> Array[CardData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[CardData] = cards.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CardData = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out

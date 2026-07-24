class_name Realms
extends RefCounted

const SET_SIZE := {
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

const RENT_TIERS := {
	"Tide Pools": [1, 2],
	"Kelp Forest": [1, 2, 3],
	"Coral Gardens": [1, 2, 4],
	"Pearl Beds": [1, 3, 5],
	"Shipwreck Cove": [2, 3, 6],
	"Sunken Temple": [2, 4, 6],
	"Seagrass Lagoon": [2, 4, 7],
	"Abyssal Trench": [3, 8],
	"Ocean Currents": [1, 2, 3, 4],
	"Mystic Springs": [1, 2],
}

const CORAL_COTTAGE_BONUS := 3
const PEARL_PALACE_BONUS := 4

static func size_of(realm: String) -> int:
	assert(SET_SIZE.has(realm), "Unknown realm: %s" % realm)
	return int(SET_SIZE[realm])

static func rent_for(realm: String, card_count: int) -> int:
	assert(RENT_TIERS.has(realm), "Unknown realm: %s" % realm)
	if card_count <= 0:
		return 0
	var tiers: Array = RENT_TIERS[realm]
	var idx: int = min(card_count, tiers.size()) - 1
	return int(tiers[idx])

static func all_realms() -> Array[String]:
	var out: Array[String] = []
	for k in SET_SIZE.keys():
		out.append(String(k))
	return out

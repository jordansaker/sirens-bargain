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

static func size_of(realm: String) -> int:
	assert(SET_SIZE.has(realm), "Unknown realm: %s" % realm)
	return int(SET_SIZE[realm])

static func all_realms() -> Array[String]:
	var out: Array[String] = []
	for k in SET_SIZE.keys():
		out.append(String(k))
	return out

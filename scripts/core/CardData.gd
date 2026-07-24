class_name CardData
extends Resource

enum Type {
	REALM,
	WILD_REALM,
	PEARL,
	TRIBUTE,
	ACTION,
}

@export var id: String = ""
@export var name: String = ""
@export var type: Type = Type.REALM
@export var value: int = 0
@export var realm: String = ""
@export var realms: Array[String] = []
@export var rent_tiers: Array[int] = []
@export var action_effect: String = ""

static func type_to_string(t: int) -> String:
	match t:
		Type.REALM: return "REALM"
		Type.WILD_REALM: return "WILD_REALM"
		Type.PEARL: return "PEARL"
		Type.TRIBUTE: return "TRIBUTE"
		Type.ACTION: return "ACTION"
	return ""

static func type_from_string(s: String) -> int:
	match s:
		"REALM": return Type.REALM
		"WILD_REALM": return Type.WILD_REALM
		"PEARL": return Type.PEARL
		"TRIBUTE": return Type.TRIBUTE
		"ACTION": return Type.ACTION
	push_error("Unknown card type: " + s)
	return Type.REALM

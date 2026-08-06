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
# Optional res:// path to the card's full-face art. Empty falls back to the
# placeholder banner-and-label rendering in CardView.
@export var art_path: String = ""

func is_rainbow_conch() -> bool:
	return id.begins_with("wild_rainbow_conch")

func can_bank() -> bool:
	# Realm and wild-realm cards can NEVER be banked. Their pearl value only
	# exists to price them when they're paid to satisfy a debt — the bank
	# holds pearls, tributes, and actions.
	if type == Type.REALM or type == Type.WILD_REALM:
		return false
	return true

func can_be_assigned_to(target_realm: String) -> bool:
	match type:
		Type.REALM:
			return realm == target_realm
		Type.WILD_REALM:
			return realms.has(target_realm)
		_:
			return false

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

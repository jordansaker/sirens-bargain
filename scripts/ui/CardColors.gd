class_name CardColors
extends RefCounted

# Palette lifted from docs/sirens-bargain-screen-mockup.html so the built UI
# matches the reviewed design. Realm colours are the softer phone-friendly
# versions from the mockup's example chips; chrome colours name the ink,
# gold, pearl, etc. used across the screen.

# --- Screen chrome ---
const INK := Color("0b1d33")          # panel / card background
const INK_DEEP := Color("0a1626")     # screen background
const GOLD := Color("c9a227")         # completed border, draw pile border
const PANEL := Color("14304f")        # divider hairlines
const PANEL_EDGE := Color("22496f")   # chip / card borders
const FOAM := Color("f2f6f5")         # primary text
const MIST := Color("c4d6e2")         # secondary text (button label, chip count)
const HAZE := Color("9db6c4")         # tertiary text (tag, "discard" label)
const PEARL := Color("ede6d4")        # pearl icon, primary strong text
const CLIFF := Color("1f4370")        # accent
const STEEL := Color("2c5a8f")        # primary button
const SELECT := Color("a79ee8")       # selected card border / hint text

# --- Realm bar colours ---
const REALM: Dictionary = {
	"Tide Pools": Color("e0c18a"),
	"Kelp Forest": Color("7fc9b4"),
	"Coral Gardens": Color("f09cba"),
	"Pearl Beds": Color("f4a87a"),
	"Shipwreck Cove": Color("e08585"),
	"Sunken Temple": Color("efc55e"),
	"Seagrass Lagoon": Color("9ad16c"),
	"Abyssal Trench": Color("7fa8e8"),
	"Ocean Currents": Color("bcc9d2"),
	"Mystic Springs": Color("7fdce8"),
}

# --- Non-realm card banners ---
const PEARL_BANNER := Color("ede6d4")     # pearl-cream banner for Pearls
const TRIBUTE_BANNER := Color("efc55e")   # gold banner for Tributes
const ACTION_BANNER := Color("a79ee8")    # purple banner for Actions
const WILD_MULTI := Color("f4d35e")       # Rainbow Conch / multi-realm wild
const UNKNOWN := Color("2c2c2a")

static func for_card(card: CardData) -> Color:
	if card == null:
		return UNKNOWN
	match card.type:
		CardData.Type.REALM:
			return REALM.get(card.realm, UNKNOWN)
		CardData.Type.WILD_REALM:
			if card.is_rainbow_conch():
				return WILD_MULTI
			# Two-realm wild → mean of its two realm colours so it reads as both.
			if card.realms.size() >= 2:
				var a: Color = REALM.get(card.realms[0], UNKNOWN)
				var b: Color = REALM.get(card.realms[1], UNKNOWN)
				return a.lerp(b, 0.5)
			return WILD_MULTI
		CardData.Type.PEARL:
			return PEARL_BANNER
		CardData.Type.TRIBUTE:
			return TRIBUTE_BANNER
		CardData.Type.ACTION:
			return ACTION_BANNER
	return UNKNOWN

static func text_on(bg: Color) -> Color:
	# Pick readable label colour based on background luminance.
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return INK_DEEP if lum > 0.6 else FOAM

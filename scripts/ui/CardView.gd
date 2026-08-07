class_name CardView
extends PanelContainer

# Compact hand-card visual matching the phone mockup (see
# docs/sirens-bargain-screen-mockup.html):
#   [colour banner strip]   ← keyed to CardColors.for_card
#   [name label]
#   [value / hint]
#
# `selected = true` lifts the card up by `LIFT_PX` and swaps the border to
# purple — the row in the hand bottom-aligns cards, so a taller card sticks
# out of the top of the row without needing a separate modal.

signal selected(card: CardData)

const WIDTH := 180
const HEIGHT := 252
const LIFT_PX := 24

const BANNER_HEIGHT := 32

var card: CardData:
	set(value):
		if card == value:
			return
		card = value
		# Drop the previous art before loading the next so its texture can be
		# reclaimed immediately instead of hanging around until _refresh's
		# assignment overwrites it.
		if _art != null:
			_art.texture = null
		_refresh()

var selected_state: bool = false:
	set(value):
		if value == selected_state:
			return
		selected_state = value
		_refresh_style()

var _banner: ColorRect
var _title_label: Label
var _value_label: Label
var _hint_label: Label
var _placeholder_col: VBoxContainer
var _art: TextureRect

func _ready() -> void:
	# Only apply the default floor if the caller didn't set their own — some
	# containers want smaller cards.
	if custom_minimum_size == Vector2.ZERO:
		_refresh_size()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build_children()
	_refresh_style()
	_refresh()

func _exit_tree() -> void:
	# Explicitly release the art texture so its RAM comes back without waiting
	# for the whole CardView to be garbage-collected — matters on the web
	# build where memory ceiling is tight.
	if _art != null:
		_art.texture = null

func _build_children() -> void:
	_placeholder_col = VBoxContainer.new()
	_placeholder_col.add_theme_constant_override("separation", 0)
	add_child(_placeholder_col)

	_banner = ColorRect.new()
	_banner.custom_minimum_size = Vector2(0, BANNER_HEIGHT)
	_placeholder_col.add_child(_banner)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder_col.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	margin.add_child(body)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_title_label)

	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 15)
	body.add_child(_value_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.visible = false
	body.add_child(_hint_label)

	# Art overlay — added AFTER the placeholder column so it renders on top
	# when a card provides its own art. Ignores mouse so taps still fire the
	# CardView's own gui_input.
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.visible = false
	add_child(_art)

func set_highlighted(on: bool) -> void:
	# Legacy shim — old code called this for discard-selection highlighting.
	# Now the discard highlight rides on the same "selected" lift.
	selected_state = on

func _refresh_size() -> void:
	# Base card box only. Callers that need to lift a selected card should
	# animate `position.y` externally — this used to bump min height by
	# LIFT_PX, which conflicted with the manually positioned hand fan.
	custom_minimum_size = Vector2(WIDTH, HEIGHT)

func _refresh() -> void:
	if _title_label == null:
		return
	if card == null:
		_title_label.text = ""
		_value_label.text = ""
		_hint_label.text = ""
		_hint_label.visible = false
		_banner.color = CardColors.INK
		if _art != null:
			_art.texture = null
			_art.visible = false
		return
	# Prefer the per-card art if the file loads; otherwise fall back to the
	# placeholder banner-and-label layout so cards without art still read.
	var tex := _load_card_art(card.art_path)
	if tex != null:
		_art.texture = tex
		_art.visible = true
		_placeholder_col.visible = false
	else:
		_art.texture = null
		_art.visible = false
		_placeholder_col.visible = true
	_banner.color = CardColors.for_card(card)
	_title_label.text = _short_name_for(card)
	_value_label.text = "%d P" % card.value if card.value > 0 else ""
	_hint_label.visible = selected_state and _art != null and not _art.visible
	_hint_label.text = "tap Play / Bank"

static func _load_card_art(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	# CACHE_MODE_IGNORE bypasses Godot's global resource cache so each
	# CardView holds its own texture instance. When the CardView is freed
	# (or its `card` is swapped) the texture drops its last reference and
	# gets released — otherwise every unique card ever shown accumulates in
	# the cache, which pushes the web build past its wasm heap budget.
	var res := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	if res is Texture2D:
		return res
	return null

# Truncate long card names so they don't wrap past two lines on a 62-wide card.
func _short_name_for(c: CardData) -> String:
	match c.type:
		CardData.Type.REALM:
			return c.realm
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				return "Rainbow"
			return "Wild"
		CardData.Type.PEARL:
			return "Pearls"
		CardData.Type.TRIBUTE:
			if c.realms.is_empty():
				return "Siren's Toll"
			return "Tribute"
		CardData.Type.ACTION:
			# The full names are ~13-18 chars — the label wraps to 2 lines.
			# Short form is nicer on a 62-wide card.
			return _short_action_name(c.action_effect)
	return c.name

static func _short_action_name(effect: String) -> String:
	match effect:
		"ride_the_current": return "Ride"
		"mermaids_feast": return "Feast"
		"toll_of_the_tides": return "Toll"
		"slippery_eel": return "Eel"
		"trade_winds": return "Trade"
		"krakens_grasp": return "Kraken"
		"sirens_refusal": return "Refusal"
		"high_tide": return "High Tide"
		"coral_cottage": return "Cottage"
		"pearl_palace": return "Palace"
	return effect

func _refresh_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardColors.INK
	sb.corner_radius_top_left = 7
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 7
	sb.corner_radius_bottom_right = 7
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = CardColors.SELECT if selected_state else CardColors.GOLD
	add_theme_stylebox_override("panel", sb)
	if _title_label != null:
		_title_label.add_theme_color_override("font_color", CardColors.MIST if not selected_state else CardColors.PEARL)
	if _value_label != null:
		_value_label.add_theme_color_override("font_color", CardColors.HAZE)
	if _hint_label != null:
		_hint_label.add_theme_color_override("font_color", CardColors.SELECT)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(card)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			selected.emit(card)

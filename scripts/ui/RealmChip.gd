class_name RealmChip
extends Button

# Slim realm chip: coloured header with the realm name + progress count below.
# Gold border when the set is complete, dashed border when empty. Exposed as
# a Button so pressed() works out-of-the-box for target picking.

signal chip_pressed(realm_name: String)

enum Mode { NORMAL, COMPLETE, EMPTY }

# Wide enough for "Seagrass Lagoon" at 9pt on the colour bar without
# breaking the game's vertical budget.
const HEIGHT := 48
const MIN_WIDTH := 88
const BANNER_HEIGHT := 20

var realm_name: String = ""
var current: int = 0
var target: int = 0
var mode: int = Mode.NORMAL
var has_cottage: bool = false
var has_palace: bool = false
var has_conch: bool = false

var _bar: Panel        # coloured header with the realm name overlaid
var _bar_label: Label
var _count: Label
var _col: VBoxContainer
var _modifier_row: HBoxContainer
var _cottage_icon: TextureRect
var _palace_icon: TextureRect
var _conch_icon: TextureRect
var _pop_tween: Tween = null
var _popped: bool = false

const POP_OFFSET := -14.0

func _init() -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): chip_pressed.emit(realm_name))

func _ready() -> void:
	# VBox: coloured header (with name) on top, count centred below.
	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_col.add_theme_constant_override("separation", 0)
	add_child(_col)

	_bar = Panel.new()
	_bar.custom_minimum_size = Vector2(0, BANNER_HEIGHT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_bar)

	_bar_label = Label.new()
	_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar_label.clip_text = true
	_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_label.add_theme_font_size_override("font_size", 9)
	_bar.add_child(_bar_label)

	# Modifier badges — two small SVG icons anchored to the right edge of
	# the coloured header. The Unicode glyph substitutes (⌂ / ♛) didn't
	# ship in Godot's bundled Noto Sans and drew as tofu, so we render
	# real assets/icons/cottage.svg + palace.svg via TextureRect. Visibility
	# is toggled from _paint_bar based on has_cottage / has_palace.
	_modifier_row = HBoxContainer.new()
	_modifier_row.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_modifier_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modifier_row.add_theme_constant_override("separation", 2)
	_modifier_row.offset_left = -32
	_modifier_row.offset_right = -3
	_modifier_row.alignment = BoxContainer.ALIGNMENT_END
	_bar.add_child(_modifier_row)
	_cottage_icon = TextureRect.new()
	_cottage_icon.custom_minimum_size = Vector2(14, 14)
	_cottage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cottage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cottage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cottage_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cottage_icon.texture = load("res://assets/icons/cottage.svg")
	_cottage_icon.visible = false
	_modifier_row.add_child(_cottage_icon)
	_palace_icon = TextureRect.new()
	_palace_icon.custom_minimum_size = Vector2(14, 14)
	_palace_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_palace_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_palace_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palace_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_palace_icon.texture = load("res://assets/icons/palace.svg")
	_palace_icon.visible = false
	_modifier_row.add_child(_palace_icon)

	# Count row: rainbow-conch marker sits inline next to the "N/M" progress
	# label so a Rainbow Conch is legible without stealing space from the
	# coloured header (where cottage/palace already live). Multi-colour SVG,
	# so no modulate override; visibility flipped in _paint_bar.
	var count_row := HBoxContainer.new()
	count_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 3)
	count_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(count_row)

	_conch_icon = TextureRect.new()
	_conch_icon.custom_minimum_size = Vector2(14, 14)
	_conch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_conch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_conch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conch_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_conch_icon.texture = load("res://assets/icons/rainbow-conch.svg")
	_conch_icon.visible = false
	count_row.add_child(_conch_icon)

	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 12)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_row.add_child(_count)

	_refresh()

func configure(name_: String, current_: int, target_: int, complete: bool, has_cottage_: bool = false, has_palace_: bool = false, has_conch_: bool = false) -> void:
	realm_name = name_
	current = current_
	target = target_
	has_cottage = has_cottage_
	has_palace = has_palace_
	has_conch = has_conch_
	mode = Mode.COMPLETE if complete else Mode.NORMAL
	_refresh()

func configure_empty() -> void:
	realm_name = ""
	current = 0
	target = 0
	mode = Mode.EMPTY
	_refresh()

func set_popped(on: bool) -> void:
	if _col == null:
		return
	if _popped == on and _pop_tween == null:
		return
	_popped = on
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	var target_y := POP_OFFSET if on else 0.0
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_property(_col, "offset_top", target_y, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_col, "offset_bottom", target_y, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh() -> void:
	if _bar == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardColors.INK
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	match mode:
		Mode.COMPLETE:
			sb.border_color = CardColors.GOLD
			_paint_bar(realm_name, true)
			_count.text = "%d/%d" % [current, target]
			_count.add_theme_color_override("font_color", CardColors.PEARL)
		Mode.EMPTY:
			sb.border_color = CardColors.PANEL_EDGE
			_bar.visible = false
			_bar_label.text = ""
			_count.text = "+"
			_count.add_theme_color_override("font_color", Color("4e7fa8"))
		_:
			sb.border_color = CardColors.PANEL_EDGE
			_paint_bar(realm_name, false)
			_count.text = "%d/%d" % [current, target]
			_count.add_theme_color_override("font_color", CardColors.MIST)
	# Apply to all four Button states so it looks the same idle/hover/pressed.
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
	add_theme_stylebox_override("disabled", sb)

# Style the header bar with the realm colour and pick a contrasting text
# colour so the realm name is legible on top.
func _paint_bar(name_: String, complete: bool) -> void:
	_bar.visible = true
	var bg: Color = CardColors.REALM.get(name_, CardColors.PANEL_EDGE)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = bg
	# Round only the top corners so the bar hugs the chip's inner rounded edge.
	bar_sb.corner_radius_top_left = 5
	bar_sb.corner_radius_top_right = 5
	bar_sb.corner_radius_bottom_left = 0
	bar_sb.corner_radius_bottom_right = 0
	_bar.add_theme_stylebox_override("panel", bar_sb)
	_bar_label.text = name_
	_bar_label.add_theme_color_override("font_color", CardColors.text_on(bg))
	# Modifier icons: real SVG cottage / palace glyphs from assets/icons.
	# Visibility flipped per has_cottage / has_palace on this refresh.
	if _cottage_icon != null:
		_cottage_icon.visible = has_cottage
	if _palace_icon != null:
		_palace_icon.visible = has_palace
	if _conch_icon != null:
		_conch_icon.visible = has_conch
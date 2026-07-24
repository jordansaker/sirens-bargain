class_name RealmChip
extends Button

# Slim realm chip per the mockup: coloured bar on top + progress count below,
# gold border when the set is complete, dashed border when empty.
# Exposed as a Button so pressed() works out-of-the-box for target picking.

signal chip_pressed(realm_name: String)

enum Mode { NORMAL, COMPLETE, EMPTY }

const HEIGHT := 44
const MIN_WIDTH := 46

var realm_name: String = ""
var current: int = 0
var target: int = 0
var mode: int = Mode.NORMAL

var _bar: ColorRect
var _count: Label

func _init() -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): chip_pressed.emit(realm_name))

func _ready() -> void:
	# Custom paint: use a VBox with a ColorRect bar and a count label.
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, 5)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_bar)

	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 11)
	_count.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_count)

	_refresh()

func configure(name_: String, current_: int, target_: int, complete: bool) -> void:
	realm_name = name_
	current = current_
	target = target_
	mode = Mode.COMPLETE if complete else Mode.NORMAL
	_refresh()

func configure_empty() -> void:
	realm_name = ""
	current = 0
	target = 0
	mode = Mode.EMPTY
	_refresh()

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
			_bar.visible = true
			_bar.color = CardColors.REALM.get(realm_name, CardColors.PANEL_EDGE)
			_count.text = "%d/%d" % [current, target]
			_count.add_theme_color_override("font_color", CardColors.PEARL)
		Mode.EMPTY:
			sb.border_color = CardColors.PANEL_EDGE
			_bar.visible = false
			_count.text = "+"
			_count.add_theme_color_override("font_color", Color("4e7fa8"))
		_:
			sb.border_color = CardColors.PANEL_EDGE
			_bar.visible = true
			_bar.color = CardColors.REALM.get(realm_name, CardColors.PANEL_EDGE)
			_count.text = "%d/%d" % [current, target]
			_count.add_theme_color_override("font_color", CardColors.MIST)
	# Apply to all four Button states so it looks the same idle/hover/pressed.
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
	add_theme_stylebox_override("disabled", sb)

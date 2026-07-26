class_name PlayerBoardView
extends VBoxContainer

# Slim per-player strip per the mockup: a header bar (avatar + name + bank
# amount) and a row of realm chips. No full-card art on this strip — that's
# reserved for the hand. Purpose is to answer "how close is each of us to
# winning?" in about half a second.

signal realm_chip_pressed(player_id: int, realm_name: String)

const CHIP_ROW_HEIGHT := 40
const CHIP_ROW_MAX := 5   # shown side-by-side; more scroll horizontally

var player: PlayerState
var display_name: String = "Player"
var tag: String = ""                # small caption after name (e.g. "AI")
var avatar_letter: String = "?"
var avatar_color: Color = CardColors.STEEL
var show_bank_pearls: bool = true   # false hides the pearl total (opponent)

var _header: HBoxContainer
var _avatar_lbl: Label
var _name_lbl: Label
var _tag_lbl: Label
var _bank_pearl_dot: Panel
var _bank_lbl: Label
var _chip_scroll: ScrollContainer
var _chip_row: HBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_header()
	_build_chip_row()
	refresh()

func _build_header() -> void:
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 8)
	add_child(_header)

	_avatar_lbl = Label.new()
	_avatar_lbl.custom_minimum_size = Vector2(26, 26)
	_avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_lbl.add_theme_font_size_override("font_size", 12)
	_apply_avatar_style()
	_header.add_child(_avatar_lbl)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 13)
	_name_lbl.add_theme_color_override("font_color", CardColors.FOAM)
	_header.add_child(_name_lbl)

	_tag_lbl = Label.new()
	_tag_lbl.add_theme_font_size_override("font_size", 11)
	_tag_lbl.add_theme_color_override("font_color", CardColors.HAZE)
	_header.add_child(_tag_lbl)

	# Push bank to the right.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(spacer)

	_bank_pearl_dot = Panel.new()
	_bank_pearl_dot.custom_minimum_size = Vector2(11, 11)
	var dot_sb := StyleBoxFlat.new()
	dot_sb.bg_color = CardColors.PEARL
	dot_sb.corner_radius_top_left = 6
	dot_sb.corner_radius_top_right = 6
	dot_sb.corner_radius_bottom_left = 6
	dot_sb.corner_radius_bottom_right = 6
	_bank_pearl_dot.add_theme_stylebox_override("panel", dot_sb)
	_header.add_child(_bank_pearl_dot)

	_bank_lbl = Label.new()
	_bank_lbl.add_theme_font_size_override("font_size", 13)
	_bank_lbl.add_theme_color_override("font_color", CardColors.PEARL)
	_header.add_child(_bank_lbl)

func _build_chip_row() -> void:
	_chip_scroll = ScrollContainer.new()
	_chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chip_scroll.custom_minimum_size = Vector2(0, CHIP_ROW_HEIGHT + 8)
	_chip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_chip_scroll)

	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 4)
	_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chip_scroll.add_child(_chip_row)

func configure(name_: String, tag_: String, letter: String, color: Color, show_pearls: bool) -> void:
	display_name = name_
	tag = tag_
	avatar_letter = letter
	avatar_color = color
	show_bank_pearls = show_pearls
	if _avatar_lbl != null:
		_apply_avatar_style()
		refresh()

func _apply_avatar_style() -> void:
	if _avatar_lbl == null:
		return
	# StyleBoxFlat with rounded corners fakes the circular avatar cheaply.
	var sb := StyleBoxFlat.new()
	sb.bg_color = avatar_color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	_avatar_lbl.add_theme_stylebox_override("normal", sb)
	_avatar_lbl.add_theme_color_override("font_color", CardColors.PEARL)

func refresh() -> void:
	if _header == null:
		return
	_avatar_lbl.text = avatar_letter
	_name_lbl.text = display_name
	_tag_lbl.text = tag
	if player == null:
		_bank_lbl.text = "0"
		_bank_pearl_dot.visible = show_bank_pearls
		return

	if show_bank_pearls:
		_bank_lbl.text = "%d" % player.total_bank_value()
		_bank_pearl_dot.visible = true
	else:
		# Hide the pearl icon so it doesn't imply a pearl total; just show
		# how many cards they've banked so you know the pile isn't empty.
		_bank_lbl.text = "%d in bank" % player.bank.size()
		_bank_pearl_dot.visible = false

	_populate_chips()

func _populate_chips() -> void:
	for child in _chip_row.get_children():
		child.queue_free()
	# Only chips for realms the player has laid at least one card in — empty
	# realms don't answer "how close to winning" so they'd be noise.
	var in_play: Array[String] = []
	for r in Realms.all_realms():
		var stack: Array = player.realms.get(r, [])
		if stack.is_empty():
			continue
		in_play.append(r)
	for r in in_play:
		var stack: Array = player.realms[r]
		var chip := RealmChip.new()
		chip.chip_pressed.connect(func(name_): realm_chip_pressed.emit(player.id, name_))
		_chip_row.add_child(chip)
		chip.configure(r, stack.size(), Realms.size_of(r), player.is_realm_complete(r))
	# Trailing "+" placeholder — a hint that new realms can still be started.
	# Tappable on your own strip: the GameScreen uses it as a "start a new
	# realm" shortcut when a wild card is selected in hand. It still emits
	# with an empty realm name, so state that doesn't handle it just ignores.
	if in_play.size() < CHIP_ROW_MAX:
		var placeholder := RealmChip.new()
		placeholder.chip_pressed.connect(func(name_): realm_chip_pressed.emit(player.id, name_))
		_chip_row.add_child(placeholder)
		placeholder.configure_empty()

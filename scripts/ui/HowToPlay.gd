class_name HowToPlay
extends Control

# Rules screen — matches docs/sirens-bargain-how-to-play.html.
# Sticky top bar with back button, three tabs (Basics / Cards / Actions),
# scrollable pane of styled cards below. Layout built in code to keep the
# per-card chrome (numbered circle, gold border, backdrop-blur panels)
# reusable without a .tscn per variant.

const MAIN_MENU_PATH := "res://scenes/MainMenu.tscn"

# Palette lifted from the mockup CSS.
const NAVY := Color("0B1D33")
const NAVY_DEEP := Color("06111F")
const NAVY_MID := Color("17395F")
const GOLD := Color("C9A227")
const GOLD_LT := Color("E4C25A")
const GOLD_D := Color("A5811C")
const PEARL := Color("EDE6D4")
const HAZE := Color("9DB6C4")
const MIST := Color("C4D6E2")
const PANEL_BG := Color(0.043, 0.114, 0.2, 0.72)
const CONTENT_MAX_WIDTH := 460

# Realm swatch colours for the chip row on the Cards tab.
const REALM_CHIPS := [
	{"name": "Tide Pools", "color": Color("E0C18A")},
	{"name": "Kelp Forest", "color": Color("7FC9B4")},
	{"name": "Coral Gardens", "color": Color("F09CBA")},
	{"name": "Abyssal Trench", "color": Color("7FA8E8")},
	{"name": "Ocean Currents", "color": Color("BCC9D2")},
]

var _tab_buttons: Dictionary = {}   # tab id -> Button
var _tab_panes: Dictionary = {}     # tab id -> VBoxContainer
var _current_tab: String = "basics"

func _ready() -> void:
	_add_background()
	_add_rays()
	_add_topbar()
	_add_tabs()
	_add_content()
	_show_tab("basics")

# --- Background ----------------------------------------------------------

func _add_background() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.color = NAVY_DEEP
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

	var glow := TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([NAVY_MID, NAVY, NAVY_DEEP])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, -0.1)
	gt.fill_to = Vector2(1.1, 1.0)
	gt.width = 1024
	gt.height = 1024
	glow.texture = gt
	add_child(glow)

func _add_rays() -> void:
	var rays_root := Control.new()
	rays_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rays_root)
	# Only two rays here (r1 + r3) — the mockup omits the middle one on this
	# screen so the content column stays legible.
	var specs := [
		{"x_frac": 0.06, "width_frac": 0.34, "rot_deg": 9.0},
		{"x_frac": 0.72, "width_frac": 0.24, "rot_deg": 12.0},
	]
	for spec in specs:
		var ray := TextureRect.new()
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ray.stretch_mode = TextureRect.STRETCH_SCALE
		ray.modulate = Color(1, 1, 1, 0.55)
		ray.texture = _ray_texture()
		ray.rotation_degrees = float(spec["rot_deg"])
		var x_frac: float = spec["x_frac"]
		var w_frac: float = spec["width_frac"]
		ray.set_anchors_preset(Control.PRESET_TOP_WIDE)
		ray.anchor_left = x_frac
		ray.anchor_right = x_frac + w_frac
		ray.anchor_top = -0.2
		ray.anchor_bottom = 1.5
		ray.offset_left = 0
		ray.offset_right = 0
		ray.offset_top = 0
		ray.offset_bottom = 0
		rays_root.add_child(ray)

func _ray_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.788, 0.635, 0.153, 0.07), Color(0.788, 0.635, 0.153, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 256
	return gt

# --- Top bar (sticky look; centred column mirrors the mockup) -----------

func _add_topbar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 0
	bar.offset_bottom = 66
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.067, 0.122, 0.92)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(row)

	var back := Button.new()
	back.custom_minimum_size = Vector2(40, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_ghost_button_style(back)
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	# Real SVG chevron instead of the U+2039 glyph (renders inconsistently
	# in Godot's bundled Noto Sans on some platforms).
	var back_glyph := TextureRect.new()
	back_glyph.texture = load("res://assets/icons/chevron-left.svg")
	back_glyph.custom_minimum_size = Vector2(18, 18)
	back_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(back_glyph)

	var title := Label.new()
	title.text = "How to Play"
	title.add_theme_font_override("font", _title_font())
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", PEARL)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

# --- Tab strip ------------------------------------------------------------

func _add_tabs() -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrap.offset_top = 70
	wrap.offset_bottom = 118
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(min(460, get_viewport().get_visible_rect().size.x - 36), 0)
	row.add_theme_constant_override("separation", 6)
	wrap.add_child(row)

	for spec in [
		{"id": "basics", "label": "Basics"},
		{"id": "cards", "label": "Cards"},
		{"id": "actions", "label": "Actions"},
	]:
		var b := Button.new()
		b.text = spec["label"]
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 13)
		var id_: String = spec["id"]
		b.pressed.connect(func(): _show_tab(id_))
		row.add_child(b)
		_tab_buttons[id_] = b

# --- Content scroll -------------------------------------------------------

func _add_content() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 122
	scroll.offset_left = 0
	scroll.offset_right = 0
	scroll.offset_bottom = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(min(CONTENT_MAX_WIDTH, get_viewport().get_visible_rect().size.x - 36), 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	# Bottom padding so the last card isn't flush against the viewport edge.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_bottom", 40)
	col.add_child(pad)

	var stacked := VBoxContainer.new()
	stacked.add_theme_constant_override("separation", 14)
	pad.add_child(stacked)

	_tab_panes["basics"] = _build_basics_pane()
	_tab_panes["cards"] = _build_cards_pane()
	_tab_panes["actions"] = _build_actions_pane()
	for id_ in ["basics", "cards", "actions"]:
		stacked.add_child(_tab_panes[id_])

func _build_basics_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.add_theme_constant_override("separation", 14)
	# The Goal — 2P vs 3+P win condition explicit per user request.
	pane.add_child(_build_rules_card("res://assets/icons/anchor.svg", "The Goal",
		"Be the first to lay down [b]three complete realm sets[/b] (or [b]four[/b] in a two-player match). Each realm needs a set number of cards — small ones like Tide Pools need 2, bigger ones like Ocean Currents need 4."))
	pane.add_child(_build_rules_card("1", "Your Turn",
		"Draw [b]2 cards[/b] to start (draw 5 if your hand is empty). Then play [b]up to 3 cards[/b]: bank Pearls, lay down realms, or play action cards. End with [b]7 or fewer[/b] cards in hand."))
	pane.add_child(_build_rules_card("res://assets/icons/crown.svg", "Winning",
		"The moment your final realm is complete, you win — even mid-turn. Opponents will try to steal your sets with actions, so a realm isn't safe until the game ends."))
	return pane

func _build_cards_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.add_theme_constant_override("separation", 14)
	pane.add_child(_build_rules_card_with_chips("Realm cards",
		"The properties you collect. Complete a set to make it count toward winning and to charge higher rent.",
		REALM_CHIPS))
	pane.add_child(_build_rules_card("", "Wild & Pearls",
		"[b]Wild realms[/b] stand in for either of two realms to finish a set. [b]Rainbow Conch[/b] counts as any realm. [b]Pearls[/b] are money — bank them to pay rent and actions."))
	pane.add_child(_build_rules_card("", "Tributes",
		"Charge other players rent on a realm you own. [b]Siren's Toll[/b] hits one chosen player on any realm."))
	return pane

func _build_actions_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.add_theme_constant_override("separation", 14)
	pane.add_child(_build_rules_card("", "Take & steal",
		"[b]Kraken's Grasp[/b] steals a whole finished set. [b]Slippery Eel[/b] takes one loose card. [b]Trade Winds[/b] swaps a card with an opponent."))
	pane.add_child(_build_rules_card("", "Charge & defend",
		"[b]Toll of the Tides[/b] and [b]Mermaid's Feast[/b] make others pay you. [b]Siren's Refusal[/b] cancels an action played against you — and can itself be cancelled."))
	pane.add_child(_build_rules_card("", "Build & boost",
		"[b]Coral Cottage[/b] and [b]Pearl Palace[/b] raise a finished realm's rent. [b]High Tide[/b] doubles your next Tribute. [b]Ride the Current[/b] draws 2 extra cards."))
	return pane

# --- Rules card factory --------------------------------------------------

func _build_rules_card(badge_ref: String, title_text: String, body_bbcode: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	col.add_child(_build_card_title(badge_ref, title_text))
	col.add_child(_build_body_text(body_bbcode))
	return panel

func _build_rules_card_with_chips(title_text: String, body_bbcode: String, chips: Array) -> PanelContainer:
	var panel := _build_rules_card("", title_text, body_bbcode)
	var col: VBoxContainer = panel.get_child(0).get_child(0)
	col.add_child(_build_chip_row(chips))
	return panel

func _build_card_title(badge_ref: String, title_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	# `badge_ref` is either a res:// path to an SVG icon or a short glyph/number
	# to render as a text pill. Icons render as a TextureRect so we don't rely
	# on platform Unicode glyph support (the crown/anchor Unicode chars fell
	# back to tofu on the web export).
	if badge_ref.begins_with("res://"):
		var icon := TextureRect.new()
		icon.texture = load(badge_ref)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	elif not badge_ref.is_empty():
		var badge := Label.new()
		badge.text = badge_ref
		badge.custom_minimum_size = Vector2(26, 26)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", GOLD_LT)
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.15)
		pill.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
		pill.border_width_left = 1
		pill.border_width_right = 1
		pill.border_width_top = 1
		pill.border_width_bottom = 1
		pill.corner_radius_top_left = 13
		pill.corner_radius_top_right = 13
		pill.corner_radius_bottom_left = 13
		pill.corner_radius_bottom_right = 13
		badge.add_theme_stylebox_override("normal", pill)
		row.add_child(badge)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", _title_font())
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", GOLD_LT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	return row

func _build_body_text(bbcode: String) -> RichTextLabel:
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = "[color=#c4d6e2]%s[/color]" % bbcode.replace("[b]", "[color=#EDE6D4][b]").replace("[/b]", "[/b][/color]")
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", MIST)
	return body

func _build_chip_row(chips: Array) -> HFlowContainer:
	# HFlowContainer wraps chips onto a new row when the parent runs out of
	# horizontal room — matches the mockup's `flex-wrap: wrap` behaviour.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for c in chips:
		flow.add_child(_build_chip(String(c["name"]), c["color"]))
	return flow

func _build_chip(text: String, swatch: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	chip.add_child(row)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(11, 11)
	dot.color = swatch
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MIST)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return chip

# --- Styling helpers -----------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.2)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	return sb

func _apply_ghost_button_style(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	var hover := sb.duplicate()
	hover.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.14)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", sb)

func _apply_tab_style(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	if active:
		sb.bg_color = GOLD
		sb.border_color = Color(0, 0, 0, 0)
		btn.add_theme_color_override("font_color", Color("2A1F07"))
		btn.add_theme_color_override("font_hover_color", Color("2A1F07"))
	else:
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.3)
		btn.add_theme_color_override("font_color", HAZE)
		btn.add_theme_color_override("font_hover_color", PEARL)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)

func _show_tab(id: String) -> void:
	_current_tab = id
	for tab_id in _tab_buttons.keys():
		_apply_tab_style(_tab_buttons[tab_id], tab_id == id)
	for pane_id in _tab_panes.keys():
		_tab_panes[pane_id].visible = pane_id == id

# --- Nav ------------------------------------------------------------------

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _title_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

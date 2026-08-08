class_name MainMenu
extends Control

# Main menu — matches docs/sirens-bargain-main-menu.html.
# Layout is built in code so the styled buttons (gold gradient primary, gold
# outlined strong, ghost) don't need one .tscn per variant. Icons and the
# emblem are SVGs embedded as strings and rasterised at runtime via
# `Image.load_svg_from_string`, so no extra art files are needed.

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"
const HOW_TO_PLAY_PATH := "res://scenes/HowToPlay.tscn"
const LOBBY_PATH := "res://scenes/LobbyScreen.tscn"

# Palette lifted from the mockup CSS.
const NAVY := Color("0B1D33")
const NAVY_DEEP := Color("06111F")
const NAVY_MID := Color("17395F")
const GOLD := Color("C9A227")
const GOLD_LT := Color("E4C25A")
const GOLD_D := Color("A5811C")
const PEARL := Color("EDE6D4")
const PEARL_LT := Color("FBF7EC")
const HAZE := Color("9DB6C4")

# Menu icon paths — each shipped as a real SVG asset in assets/icons/ so
# Godot's SVG importer handles them rather than the runtime rasterizer
# that swallowed some paths on the web build. Strokes are white so the
# TextureRect's `modulate` colour tints them per button variant.
const ICON_HVH := "res://assets/icons/menu-hvh.svg"
const ICON_AI := "res://assets/icons/menu-ai.svg"
const ICON_RULES := "res://assets/icons/menu-rules.svg"
const ICON_SETTINGS := "res://assets/icons/menu-leaderboard.svg"
const ICON_SOUND_ON := "res://assets/icons/menu-sound-on.svg"
const ICON_SOUND_OFF := "res://assets/icons/menu-sound-off.svg"

var _sound_on: bool = true
var _sound_btn: Button = null
var _sound_icon: TextureRect = null

func _ready() -> void:
	_reset_net_session()
	_build_ui()

func _build_ui() -> void:
	_add_background()
	_add_rays()
	_add_bubbles()

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	stack.custom_minimum_size = Vector2(360, 0)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)

	# Emblem — loaded from an imported SVG file. Godot's SVG importer handles
	# the linear/radial gradient references reliably; `load_svg_from_string`
	# on the same content was rasterising to an empty texture.
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/icons/emblem.svg")
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(emblem)

	var title := Label.new()
	title.text = "Siren's Bargain"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _title_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", PEARL)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	stack.add_child(title)

	var tagline := Label.new()
	tagline.text = "TIDES · TREASURE · TREACHERY"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 12)
	tagline.add_theme_color_override("font_color", HAZE)
	stack.add_child(tagline)

	# Decorative divider — thin gold line, star glyph, mirrored line.
	var divider_pad := Control.new()
	divider_pad.custom_minimum_size = Vector2(0, 14)
	stack.add_child(divider_pad)
	stack.add_child(_build_divider())
	var divider_pad2 := Control.new()
	divider_pad2.custom_minimum_size = Vector2(0, 8)
	stack.add_child(divider_pad2)

	# Buttons column.
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(330, 0)
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(buttons)

	buttons.add_child(_make_menu_button(
		"Human vs Human", "Play online",
		ICON_HVH, "primary", _on_hvh_pressed))
	buttons.add_child(_make_menu_button(
		"Play vs AI", "Single player",
		ICON_AI, "strong", _on_ai_pressed))
	buttons.add_child(_make_menu_button(
		"How to Play", "",
		ICON_RULES, "ghost", _on_rules_pressed))
	buttons.add_child(_make_menu_button(
		"Leaderboard", "",
		ICON_SETTINGS, "ghost", _on_leaderboard_pressed))

	_add_sound_button()
	_add_footer()

# --- Background ----------------------------------------------------------

func _add_background() -> void:
	# Flat navy floor.
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.color = NAVY_DEEP
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	# Radial glow from top-centre — simulates the CSS radial gradient.
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

# --- Caustic rays (soft gold beams that sway) ---------------------------

func _add_rays() -> void:
	# 3 rotated, blurred gold gradient strips. Blur isn't native on Control
	# nodes, so we approximate softness by keeping alpha low and letting the
	# vertical gradient fall off. Fine for atmosphere; not aiming at a pixel
	# match with the CSS.
	var rays_root := Control.new()
	rays_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rays_root)
	var specs := [
		{"x_frac": 0.08, "width_frac": 0.38, "rot_deg": 9.0, "delay": 0.0},
		{"x_frac": 0.40, "width_frac": 0.30, "rot_deg": -6.0, "delay": -3.0},
		{"x_frac": 0.70, "width_frac": 0.26, "rot_deg": 12.0, "delay": -6.0},
	]
	var reduced := _reduced_motion()
	for spec in specs:
		var ray := TextureRect.new()
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ray.stretch_mode = TextureRect.STRETCH_SCALE
		ray.modulate = Color(1, 1, 1, 0.55)
		ray.texture = _ray_texture()
		ray.pivot_offset = Vector2(0, 0)
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
		if not reduced:
			_animate_ray(ray, float(spec["delay"]))

func _ray_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.788, 0.635, 0.153, 0.14), Color(0.788, 0.635, 0.153, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 256
	return gt

func _animate_ray(ray: TextureRect, delay: float) -> void:
	var tween := create_tween().set_loops()
	tween.tween_interval(max(0.0, delay))
	tween.tween_property(ray, "modulate:a", 0.85, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ray, "modulate:a", 0.45, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- Rising bubbles -------------------------------------------------------

func _add_bubbles() -> void:
	if _reduced_motion():
		return
	var particles := CPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 9.0
	particles.preprocess = 6.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(600, 20)
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.4
	particles.color = Color(0.984, 0.968, 0.925, 0.55)
	particles.texture = _bubble_texture()
	particles.z_index = 0
	# CPUParticles2D is a Node2D (no anchors) — reposition it manually as the
	# viewport resizes so bubbles keep rising from just below the bottom edge.
	var reposition := func():
		var vp := get_viewport().get_visible_rect().size
		particles.position = Vector2(vp.x / 2.0, vp.y + 40.0)
		particles.emission_rect_extents = Vector2(vp.x / 2.0, 20)
	reposition.call()
	get_viewport().size_changed.connect(reposition)
	add_child(particles)

func _bubble_texture() -> Texture2D:
	# Round soft-edged bubble. Fill from the exact centre (0.5, 0.5) to
	# an edge at distance 0.5 so the corners of the square texture fall
	# fully outside the gradient's max radius and rasterise transparent —
	# no more squared-off edges. Larger source (128px) plus a fine-grained
	# gradient with a low-alpha shoulder gives a smooth anti-aliased rim
	# once the particle scales up to card-sized bubbles.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 0.95, 1.0])
	g.colors = PackedColorArray([
		Color(0.984, 0.968, 0.925, 0.95),
		Color(0.929, 0.902, 0.831, 0.45),
		Color(0.929, 0.902, 0.831, 0.12),
		Color(0.929, 0.902, 0.831, 0.02),
		Color(0.929, 0.902, 0.831, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt

# --- Divider --------------------------------------------------------------

func _build_divider() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := ColorRect.new()
	left.custom_minimum_size = Vector2(56, 1)
	left.color = Color(GOLD_D.r, GOLD_D.g, GOLD_D.b, 0.75)
	row.add_child(left)
	# Diamond glyph — used to have "✦" (U+2726) but the default Godot font
	# lacks that glyph and drew tofu. Switched to an imported SVG asset so
	# the shape renders reliably on every platform.
	var star := TextureRect.new()
	star.custom_minimum_size = Vector2(12, 12)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.texture = load("res://assets/icons/divider-star.svg")
	row.add_child(star)
	var right := ColorRect.new()
	right.custom_minimum_size = Vector2(56, 1)
	right.color = Color(GOLD_D.r, GOLD_D.g, GOLD_D.b, 0.75)
	row.add_child(right)
	return row

# --- Menu button factory --------------------------------------------------

func _make_menu_button(title_text: String, subtitle_text: String, icon_svg: String, kind: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62)
	# Do NOT set `flat = true` here — flat forces the normal stylebox to
	# empty, which fights our theme_stylebox_override and leaves the primary
	# gold button transparent (dark ink text on navy bg = unreadable).
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_menu_button_style(btn, kind)
	btn.pressed.connect(cb)

	# Layout inside the button: [icon] [title + subtitle]
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	pad.add_child(row)

	var text_color := _button_text_color(kind)
	var subtitle_color := _button_subtitle_color(kind)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# icon_svg is a res:// path to a white-stroked SVG asset — set modulate
	# so the button-variant text colour tints the strokes.
	icon.texture = load(icon_svg)
	icon.modulate = text_color
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", text_color)
	# Labels default to MOUSE_FILTER_STOP, which swallows the click before it
	# reaches the parent Button — so tapping the visible text on any menu
	# button did nothing. Ignoring the mouse on child chrome lets the Button
	# own the whole hit-target.
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(title)

	if not subtitle_text.is_empty():
		var sub := Label.new()
		sub.text = subtitle_text
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", subtitle_color)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(sub)

	return btn

func _apply_menu_button_style(btn: Button, kind: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	match kind:
		"primary":
			# Godot's StyleBoxFlat has no gradient — pick the mid gold tone so
			# the button still reads as the CTA. Hover swaps to lighter gold.
			sb.bg_color = GOLD
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.border_width_top = 0
			sb.border_width_bottom = 0
			sb.shadow_color = Color(0.788, 0.635, 0.153, 0.35)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 4)
			var hover := sb.duplicate()
			hover.bg_color = GOLD_LT
			hover.shadow_color = Color(0.788, 0.635, 0.153, 0.5)
			hover.shadow_size = 8
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
		"strong":
			sb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.10)
			sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			var hover := sb.duplicate()
			hover.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.18)
			hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
		_:  # ghost
			sb.bg_color = Color(1, 1, 1, 0.04)
			sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			var hover := sb.duplicate()
			hover.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.12)
			hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.6)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("disabled", sb)

static func _button_text_color(kind: String) -> Color:
	match kind:
		"primary":
			return Color("2A1F07")  # dark ink on gold
		_:
			return PEARL

static func _button_subtitle_color(kind: String) -> Color:
	match kind:
		"primary":
			return Color(0.165, 0.122, 0.027, 0.75)
		_:
			return Color(PEARL.r, PEARL.g, PEARL.b, 0.72)

# --- Sound + footer ------------------------------------------------------

func _add_sound_button() -> void:
	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(40, 40)
	_sound_btn.flat = true
	_sound_btn.focus_mode = Control.FOCUS_NONE
	_sound_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sound_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_sound_btn.offset_left = -58
	_sound_btn.offset_right = -18
	_sound_btn.offset_top = 18
	_sound_btn.offset_bottom = 58
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
	_sound_btn.add_theme_stylebox_override("normal", sb)
	_sound_btn.add_theme_stylebox_override("hover", hover)
	_sound_btn.add_theme_stylebox_override("pressed", hover)
	_sound_btn.add_theme_stylebox_override("focus", sb)
	_sound_btn.pressed.connect(_on_sound_toggled)
	add_child(_sound_btn)

	_sound_icon = TextureRect.new()
	_sound_icon.set_anchors_preset(Control.PRESET_CENTER)
	_sound_icon.custom_minimum_size = Vector2(22, 22)
	_sound_icon.size = Vector2(22, 22)
	_sound_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sound_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sound_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sound_icon.offset_left = -11
	_sound_icon.offset_right = 11
	_sound_icon.offset_top = -11
	_sound_icon.offset_bottom = 11
	_sound_btn.add_child(_sound_icon)
	_refresh_sound_icon()

func _refresh_sound_icon() -> void:
	if _sound_icon == null:
		return
	var svg := ICON_SOUND_ON if _sound_on else ICON_SOUND_OFF
	_sound_icon.texture = load(svg)
	_sound_icon.modulate = PEARL

func _on_sound_toggled() -> void:
	_sound_on = not _sound_on
	_refresh_sound_icon()
	_sound_btn.modulate.a = 1.0 if _sound_on else 0.45
	# Wire to a real mixer bus if/when we add one; toggle is UI-only for now.

func _add_footer() -> void:
	var footer := Label.new()
	footer.text = "v0.1 · ONLINE + VS AI"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(HAZE.r, HAZE.g, HAZE.b, 0.6))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -34
	footer.offset_bottom = -18
	add_child(footer)

# --- Actions --------------------------------------------------------------

func _on_hvh_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_PATH)

func _on_ai_pressed() -> void:
	_reset_net_session()
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

func _on_rules_pressed() -> void:
	get_tree().change_scene_to_file(HOW_TO_PLAY_PATH)

func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LeaderboardScreen.tscn")

func _on_settings_pressed() -> void:
	# No settings screen yet — flash a subtle notice above the footer so the
	# button doesn't feel dead.
	print("Settings not implemented yet")

# --- Helpers --------------------------------------------------------------

func _title_font() -> Font:
	# SystemFont falls through the family list until it finds one installed on
	# the OS. Cinzel first (matches mockup), then serif fallbacks — mirrors
	# the CSS `font-family:'Cinzel', Georgia, serif`.
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

# Autoload access via node path — the autoload identifier isn't resolved when
# scenes are loaded via `godot -s` (verify_scenes.gd path).
func _reset_net_session() -> void:
	var ns := get_tree().root.get_node_or_null("NetSession")
	if ns != null and ns.has_method("reset"):
		ns.reset()

static func _reduced_motion() -> bool:
	# Best-effort — Godot has no cross-platform prefers-reduced-motion API.
	# On Web, JS could set a global; for now we only honour an explicit env
	# hint so tests / CI can force calm mode.
	return OS.get_environment("SIRENS_REDUCED_MOTION") == "1"

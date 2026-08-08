class_name LeaderboardScreen
extends Control

# 2-player head-to-head leaderboard. Currently renders a hardcoded fixture
# (Mia vs Finn) so the layout can be reviewed end-to-end; real match data
# will slot into MATCHES once we wire persistence.

const MAIN_MENU_PATH := "res://scenes/MainMenu.tscn"
const CONTENT_MAX_WIDTH := 460

# Palette pulled from docs/sirens-bargain-leaderboard-2p.html.
const LB_NAVY := Color("0B1D33")
const LB_NAVY_DEEP := Color("06111F")
const LB_NAVY_MID := Color("17395F")
const LB_GOLD := Color("C9A227")
const LB_GOLD_LT := Color("E4C25A")
const LB_GOLD_D := Color("A5811C")
const LB_PEARL := Color("EDE6D4")
const LB_HAZE := Color("9DB6C4")
const LB_MIST := Color("C4D6E2")
const LB_PANEL_BG := Color(0.043, 0.114, 0.2, 0.72)

# Hardcoded fixture — swap for a real persistence layer later.
const PLAYERS := [
	{"name": "Mia", "color": Color("6E5AA8")},
	{"name": "Finn", "color": Color("7FA8E8")},
]
const MATCHES := [
	{"ended_at": "2026-08-06", "turns": 24, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 2, "tributes": 5},
	           "Finn": {"realms": 1, "steals": 1, "tributes": 3}}},
	{"ended_at": "2026-08-05", "turns": 31, "winner": "Finn",
	 "stats": {"Mia": {"realms": 2, "steals": 1, "tributes": 2},
	           "Finn": {"realms": 3, "steals": 2, "tributes": 4}}},
	{"ended_at": "2026-08-05", "turns": 19, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 3, "tributes": 3},
	           "Finn": {"realms": 1, "steals": 0, "tributes": 2}}},
	{"ended_at": "2026-08-03", "turns": 22, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 1, "tributes": 4},
	           "Finn": {"realms": 2, "steals": 2, "tributes": 3}}},
	{"ended_at": "2026-08-02", "turns": 28, "winner": "Finn",
	 "stats": {"Mia": {"realms": 1, "steals": 1, "tributes": 3},
	           "Finn": {"realms": 3, "steals": 1, "tributes": 5}}},
	{"ended_at": "2026-08-01", "turns": 20, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 2, "tributes": 2},
	           "Finn": {"realms": 0, "steals": 1, "tributes": 2}}},
	{"ended_at": "2026-07-30", "turns": 26, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 2, "tributes": 4},
	           "Finn": {"realms": 2, "steals": 2, "tributes": 3}}},
	{"ended_at": "2026-07-28", "turns": 18, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 1, "tributes": 3},
	           "Finn": {"realms": 1, "steals": 1, "tributes": 2}}},
	{"ended_at": "2026-07-27", "turns": 30, "winner": "Finn",
	 "stats": {"Mia": {"realms": 1, "steals": 0, "tributes": 2},
	           "Finn": {"realms": 3, "steals": 2, "tributes": 4}}},
	{"ended_at": "2026-07-25", "turns": 23, "winner": "Mia",
	 "stats": {"Mia": {"realms": 3, "steals": 1, "tributes": 3},
	           "Finn": {"realms": 2, "steals": 0, "tributes": 2}}},
]

func _ready() -> void:
	_add_background()
	_add_rays()
	_add_topbar()
	_add_content()

# --- Background --------------------------------------------------------

func _add_background() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.color = LB_NAVY_DEEP
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	var glow := TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([LB_NAVY_MID, LB_NAVY, LB_NAVY_DEEP])
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
	var rays := Control.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rays)
	for spec in [
		{"x_frac": 0.06, "width_frac": 0.34, "rot_deg": 9.0},
		{"x_frac": 0.72, "width_frac": 0.24, "rot_deg": 12.0},
	]:
		var ray := TextureRect.new()
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ray.stretch_mode = TextureRect.STRETCH_SCALE
		ray.modulate = Color(1, 1, 1, 0.55)
		var rg := Gradient.new()
		rg.offsets = PackedFloat32Array([0.0, 1.0])
		rg.colors = PackedColorArray([Color(0.788, 0.635, 0.153, 0.07), Color(0.788, 0.635, 0.153, 0.0)])
		var rgt := GradientTexture2D.new()
		rgt.gradient = rg
		rgt.fill = GradientTexture2D.FILL_LINEAR
		rgt.fill_from = Vector2(0.5, 0.0)
		rgt.fill_to = Vector2(0.5, 1.0)
		rgt.width = 64
		rgt.height = 256
		ray.texture = rgt
		ray.rotation_degrees = float(spec["rot_deg"])
		var x_frac: float = spec["x_frac"]
		var w_frac: float = spec["width_frac"]
		ray.set_anchors_preset(Control.PRESET_TOP_WIDE)
		ray.anchor_left = x_frac
		ray.anchor_right = x_frac + w_frac
		ray.anchor_top = -0.2
		ray.anchor_bottom = 1.5
		rays.add_child(ray)

# --- Top bar -----------------------------------------------------------

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
	bar.add_child(row)

	var back := Button.new()
	back.custom_minimum_size = Vector2(40, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_ghost_style(back)
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	var glyph := Label.new()
	glyph.text = "‹"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 26)
	glyph.add_theme_color_override("font_color", LB_PEARL)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(glyph)

	var title := Label.new()
	title.text = "Head to Head"
	title.add_theme_font_override("font", _serif_font())
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", LB_PEARL)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

# --- Content -----------------------------------------------------------

func _add_content() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 70
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(min(CONTENT_MAX_WIDTH, get_viewport().get_visible_rect().size.x - 36), 0)
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_bottom", 40)
	col.add_child(pad)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	pad.add_child(body)

	var totals := _compute_totals()
	body.add_child(_build_versus_header(totals))
	body.add_child(_build_compare_panel(totals))
	body.add_child(_build_section_label("Recent matches"))
	body.add_child(_build_recent_matches(totals["recent"]))

	var foot := Label.new()
	foot.text = "Tallied from %d stored matches" % int(totals["games"])
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 11)
	foot.add_theme_color_override("font_color", Color(LB_HAZE.r, LB_HAZE.g, LB_HAZE.b, 0.6))
	body.add_child(foot)

# --- Totals ------------------------------------------------------------

func _compute_totals() -> Dictionary:
	var names: Array[String] = []
	for p in PLAYERS:
		names.append(String(p["name"]))
	var per: Dictionary = {}
	for n in names:
		per[n] = {"wins": 0, "realms": 0, "steals": 0, "tributes": 0, "win_rate": 0, "best_streak": 0}
	var games := 0
	for m in MATCHES:
		games += 1
		var w := String(m["winner"])
		per[w]["wins"] += 1
		var per_stats: Dictionary = m["stats"]
		for n in names:
			var s: Dictionary = per_stats.get(n, {})
			per[n]["realms"] += int(s.get("realms", 0))
			per[n]["steals"] += int(s.get("steals", 0))
			per[n]["tributes"] += int(s.get("tributes", 0))
	for n in names:
		per[n]["win_rate"] = int(round(float(per[n]["wins"]) / float(games) * 100.0)) if games > 0 else 0
	# Best streak per player from chronological match list.
	var asc := MATCHES.duplicate()
	asc.sort_custom(func(a, b): return String(a["ended_at"]) < String(b["ended_at"]))
	for n in names:
		var best := 0
		var run := 0
		for m in asc:
			if String(m["winner"]) == n:
				run += 1
				best = max(best, run)
			else:
				run = 0
		per[n]["best_streak"] = best
	var recent := MATCHES.duplicate()
	recent.sort_custom(func(a, b): return String(a["ended_at"]) > String(b["ended_at"]))
	if recent.size() > 4:
		recent.resize(4)
	return {"games": games, "per": per, "recent": recent}

# --- Versus header + stats panel + matches list -------------------------

func _build_versus_header(totals: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var a_name := String(PLAYERS[0]["name"])
	var b_name := String(PLAYERS[1]["name"])
	var per: Dictionary = totals["per"]
	var a_wins := int(per[a_name]["wins"])
	var b_wins := int(per[b_name]["wins"])
	var leader := a_name if a_wins >= b_wins else b_name

	row.add_child(_build_vp(PLAYERS[0], leader == a_name))
	row.add_child(_build_score_block(a_wins, b_wins, int(totals["games"])))
	row.add_child(_build_vp(PLAYERS[1], leader == b_name))
	return row

func _build_vp(player: Dictionary, is_leader: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var crown := Label.new()
	crown.text = "♛ leading" if is_leader else ""
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown.add_theme_font_size_override("font_size", 12)
	crown.add_theme_color_override("font_color", LB_GOLD_LT)
	crown.custom_minimum_size = Vector2(0, 16)
	col.add_child(crown)

	var avatar := Label.new()
	avatar.text = String(player["name"]).substr(0, 1).to_upper()
	avatar.custom_minimum_size = Vector2(60, 60)
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_theme_font_size_override("font_size", 24)
	avatar.add_theme_color_override("font_color", Color("0B1D33"))
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var av_sb := StyleBoxFlat.new()
	av_sb.bg_color = player["color"]
	av_sb.corner_radius_top_left = 30
	av_sb.corner_radius_top_right = 30
	av_sb.corner_radius_bottom_left = 30
	av_sb.corner_radius_bottom_right = 30
	if is_leader:
		av_sb.border_color = LB_GOLD_LT
		av_sb.border_width_left = 3
		av_sb.border_width_right = 3
		av_sb.border_width_top = 3
		av_sb.border_width_bottom = 3
		av_sb.shadow_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.4)
		av_sb.shadow_size = 6
	avatar.add_theme_stylebox_override("normal", av_sb)
	col.add_child(avatar)

	var name_lbl := Label.new()
	name_lbl.text = String(player["name"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", LB_PEARL)
	col.add_child(name_lbl)

	return col

func _build_score_block(a_wins: int, b_wins: int, games: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Push down slightly so it aligns with the avatar row.
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 16)
	col.add_child(top_pad)

	var score := Label.new()
	score.text = "%d – %d" % [a_wins, b_wins]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_override("font", _serif_font())
	score.add_theme_font_size_override("font_size", 40)
	score.add_theme_color_override("font_color", LB_PEARL)
	col.add_child(score)

	var meta := Label.new()
	meta.text = "%d games played" % games
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", LB_GOLD_LT)
	col.add_child(meta)

	return col

func _build_compare_panel(totals: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	var a_name := String(PLAYERS[0]["name"])
	var b_name := String(PLAYERS[1]["name"])
	var per: Dictionary = totals["per"]
	var rows := [
		["WINS", "wins", ""],
		["WIN RATE", "win_rate", "%"],
		["REALMS", "realms", ""],
		["STEALS", "steals", ""],
		["TRIBUTES", "tributes", ""],
		["BEST STREAK", "best_streak", ""],
	]
	for i in range(rows.size()):
		var spec: Array = rows[i]
		var lab: String = spec[0]
		var key: String = spec[1]
		var suffix: String = spec[2]
		var a := int(per[a_name][key])
		var b := int(per[b_name][key])
		col.add_child(_build_compare_row(lab, "%s%s" % [str(a), suffix], "%s%s" % [str(b), suffix], a >= b, b >= a))
		if i < rows.size() - 1:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(0, 1)
			sep.color = Color(1, 1, 1, 0.06)
			col.add_child(sep)
	return panel

func _build_compare_row(label: String, left_val: String, right_val: String, left_win: bool, right_win: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	pad.add_child(inner)

	var l := Label.new()
	l.text = left_val
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", _serif_font())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", LB_GOLD_LT if left_win else LB_HAZE)
	inner.add_child(l)

	var mid := Label.new()
	mid.text = label
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.custom_minimum_size = Vector2(90, 0)
	mid.add_theme_font_size_override("font_size", 10)
	mid.add_theme_color_override("font_color", LB_HAZE)
	inner.add_child(mid)

	var r := Label.new()
	r.text = right_val
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("font", _serif_font())
	r.add_theme_font_size_override("font_size", 18)
	r.add_theme_color_override("font_color", LB_GOLD_LT if right_win else LB_HAZE)
	inner.add_child(r)

	return row

func _build_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", LB_HAZE)
	return l

func _build_recent_matches(matches: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		var winner_name := String(m["winner"])
		var color := _color_for(winner_name)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 16)
		pad.add_theme_constant_override("margin_right", 16)
		pad.add_theme_constant_override("margin_top", 12)
		pad.add_theme_constant_override("margin_bottom", 12)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(pad)
		pad.add_child(row)

		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		var dot_sb := StyleBoxFlat.new()
		dot_sb.bg_color = color
		dot_sb.corner_radius_top_left = 4
		dot_sb.corner_radius_top_right = 4
		dot_sb.corner_radius_bottom_left = 4
		dot_sb.corner_radius_bottom_right = 4
		dot.add_theme_stylebox_override("panel", dot_sb)
		row.add_child(dot)

		var winner_lbl := RichTextLabel.new()
		winner_lbl.bbcode_enabled = true
		winner_lbl.fit_content = true
		winner_lbl.scroll_active = false
		winner_lbl.text = "[color=#EDE6D4][b]%s[/b][/color] won" % winner_name
		winner_lbl.add_theme_font_size_override("normal_font_size", 14)
		winner_lbl.add_theme_color_override("default_color", LB_MIST)
		winner_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(winner_lbl)

		var meta := Label.new()
		meta.text = "%d turns · %s" % [int(m["turns"]), String(m["ended_at"])]
		meta.add_theme_font_size_override("font_size", 12)
		meta.add_theme_color_override("font_color", LB_HAZE)
		row.add_child(meta)

		if i < matches.size() - 1:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(0, 1)
			sep.color = Color(1, 1, 1, 0.06)
			col.add_child(sep)
	return panel

func _color_for(player_name: String) -> Color:
	for p in PLAYERS:
		if String(p["name"]) == player_name:
			return p["color"]
	return LB_HAZE

# --- Styling helpers ---------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = LB_PANEL_BG
	sb.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.2)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	return sb

func _apply_ghost_style(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.35)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	var hover := sb.duplicate()
	hover.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.14)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", sb)

func _serif_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

# --- Nav ----------------------------------------------------------------

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

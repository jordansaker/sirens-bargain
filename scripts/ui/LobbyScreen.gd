class_name LobbyScreen
extends Control

# Two-column lobby: Host (create a room, share the code) or Join (paste the
# code, connect). Both peers exchange a small profile (name + age) as soon
# as they're paired; once both are known, we jump to GameScreen. The
# youngest player starts (tie → host).

@onready var _status: Label = %StatusLabel
@onready var _code_label: Label = %CodeLabel
@onready var _name_field: LineEdit = %NameField
@onready var _age_field: LineEdit = %AgeField
@onready var _host_button: Button = %HostButton
@onready var _join_code_field: LineEdit = %JoinCodeField
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton

# Palette mirrors docs/sirens-bargain-play-online.html so the lobby matches
# the rest of the reskinned chrome (menu / how-to-play / gameplay).
const LB_NAVY := Color("0B1D33")
const LB_NAVY_DEEP := Color("06111F")
const LB_NAVY_MID := Color("17395F")
const LB_GOLD := Color("C9A227")
const LB_GOLD_LT := Color("E4C25A")
const LB_GOLD_D := Color("A5811C")
const LB_PEARL := Color("EDE6D4")
const LB_HAZE := Color("9DB6C4")
const LB_MIST := Color("C4D6E2")
const LB_INK_ON_GOLD := Color("2A1F07")

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"
const MAIN_MENU_PATH := "res://scenes/MainMenu.tscn"

var _client: NetworkClient = null
var _is_host: bool = false
var _my_profile_sent: bool = false
var _opp_profile: Dictionary = {}

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_join_code_field.text_changed.connect(func(_t): _refresh_button_enabled())
	_name_field.text_changed.connect(func(_t): _refresh_button_enabled())
	_age_field.text_changed.connect(func(_t): _refresh_button_enabled())
	# Force room codes to uppercase as the user types so ABCDE-style codes
	# look like codes, not ordinary text.
	_join_code_field.text_changed.connect(_on_join_code_changed)
	_refresh_button_enabled()
	_status.text = ""
	_code_label.text = ""
	_net_session().reset()
	_apply_mockup_styling()

func _on_join_code_changed(new_text: String) -> void:
	var upper := new_text.to_upper()
	if upper == new_text:
		return
	var caret := _join_code_field.caret_column
	_join_code_field.text = upper
	_join_code_field.caret_column = caret

func _profile_valid() -> bool:
	return _name_field.text.strip_edges().length() >= 1 \
		and int(_age_field.text.strip_edges()) > 0

func _refresh_button_enabled() -> void:
	var profile_ok := _profile_valid()
	_host_button.disabled = not profile_ok
	_join_button.disabled = not (profile_ok and _join_code_field.text.strip_edges().length() == 5)

# --- Host flow ------------------------------------------------------------

func _on_host_pressed() -> void:
	_status.text = "Creating room…"
	_host_button.disabled = true
	_join_button.disabled = true
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_room_created.bind(http))
	var err := http.request(NetConfig.http_base() + "/rooms", [], HTTPClient.METHOD_POST, "")
	if err != OK:
		_status.text = "Couldn't reach relay (err %d)" % err
		_refresh_button_enabled()
		http.queue_free()

func _on_room_created(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_status.text = "Relay error (HTTP %d)" % response_code
		_refresh_button_enabled()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not parsed.has("code"):
		_status.text = "Bad relay response"
		_refresh_button_enabled()
		return
	var code := String(parsed["code"])
	_code_label.text = "Room code: %s" % code
	_status.text = "Waiting for opponent to join…"
	_is_host = true
	_connect_socket(code)

# --- Join flow ------------------------------------------------------------

func _on_join_pressed() -> void:
	var code := _join_code_field.text.strip_edges().to_upper()
	if code.length() != 5:
		return
	_status.text = "Joining %s…" % code
	_host_button.disabled = true
	_join_button.disabled = true
	_code_label.text = "Room code: %s" % code
	_is_host = false
	_connect_socket(code)

# --- Shared: WebSocket handshake + profile exchange ---------------------

func _connect_socket(code: String) -> void:
	_client = NetworkClient.new()
	add_child(_client)
	_client.joined.connect(_on_joined)
	_client.opponent_arrived.connect(_on_opponent_arrived)
	_client.opponent_left.connect(_on_opponent_left)
	_client.error_occurred.connect(_on_net_error)
	_client.disconnected.connect(_on_disconnected)
	_client.event_received.connect(_on_event_received)
	_client.connect_to(NetConfig.ws_url(), code)

func _on_joined(peer_id: int) -> void:
	_status.text = ("Room ready, waiting for opponent…" if peer_id == 0
		else "Connected, waiting for handshake…")

func _on_opponent_arrived() -> void:
	# As soon as both peers are in the room, publish our profile.
	_send_profile()
	_status.text = "Exchanging profiles…"

func _send_profile() -> void:
	if _client == null or _my_profile_sent:
		return
	_client.send({
		"kind": "profile",
		"name": _name_field.text.strip_edges(),
		"age": int(_age_field.text.strip_edges()),
	})
	_my_profile_sent = true
	_maybe_start()

func _on_event_received(payload: Dictionary) -> void:
	if String(payload.get("kind", "")) != "profile":
		return
	_opp_profile = payload
	_maybe_start()

func _maybe_start() -> void:
	if not _my_profile_sent or _opp_profile.is_empty():
		return
	# Both peers have exchanged profiles; hand off to the game.
	var ns := _net_session()
	ns.local_name = _name_field.text.strip_edges()
	ns.local_age = int(_age_field.text.strip_edges())
	ns.opponent_name = String(_opp_profile.get("name", "Opponent"))
	ns.opponent_age = int(_opp_profile.get("age", 0))
	ns.client = _client
	ns.local_player_id = _client.local_peer_id
	# Detach the lobby's connections + reparent the client under the singleton.
	if _client.event_received.is_connected(_on_event_received):
		_client.event_received.disconnect(_on_event_received)
	remove_child(_client)
	ns.add_child(_client)
	_client = null
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

# --- Failure paths -------------------------------------------------------

func _on_opponent_left() -> void:
	_status.text = "Opponent left."
	_reset_local_client()

func _on_net_error(reason: String) -> void:
	_status.text = "Error: %s" % reason
	_reset_local_client()

func _on_disconnected() -> void:
	_status.text = "Disconnected from relay."
	_reset_local_client()

func _reset_local_client() -> void:
	_my_profile_sent = false
	_opp_profile = {}
	_refresh_button_enabled()
	if _client != null:
		_client.close()
		_client.queue_free()
		_client = null

func _on_back_pressed() -> void:
	_reset_local_client()
	_net_session().reset()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _net_session() -> Node:
	return get_tree().root.get_node_or_null("NetSession")

# --- Mockup-styled chrome ------------------------------------------------
#
# Applies the styling from docs/sirens-bargain-play-online.html on top of the
# tscn structure: radial navy bg, subtle caustic rays, Cinzel titles, panel
# treatment on the profile row, gold-hairline inputs, three button variants
# (prim/strong/ghost). Called from _ready.

func _apply_mockup_styling() -> void:
	_style_background()
	_style_rays()
	_style_title_and_labels()
	_wrap_profile_in_panel()
	_style_inputs()
	_style_code_field()
	_style_lobby_button(_host_button, "prim")
	_style_lobby_button(_join_button, "strong")
	_style_lobby_button(_back_button, "ghost")

func _style_background() -> void:
	var bg := get_node_or_null("Background")
	if bg is ColorRect:
		(bg as ColorRect).color = LB_NAVY_DEEP
	if has_node("BackgroundGlow"):
		return
	var glow := TextureRect.new()
	glow.name = "BackgroundGlow"
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
	move_child(glow, 1)

func _style_rays() -> void:
	if has_node("Rays"):
		return
	var rays := Control.new()
	rays.name = "Rays"
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rays)
	move_child(rays, 2)
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
		ray.texture = _lb_ray_texture()
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
		rays.add_child(ray)

func _lb_ray_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.788, 0.635, 0.153, 0.08), Color(0.788, 0.635, 0.153, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 256
	return gt

func _style_title_and_labels() -> void:
	var title := get_node_or_null("Content/Title") as Label
	if title != null:
		title.text = "Play online"
		title.add_theme_font_override("font", _lb_serif_font())
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", LB_PEARL)
		title.add_theme_constant_override("shadow_offset_y", 2)
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	var profile_lbl := get_node_or_null("Content/ProfileSection/ProfileLabel") as Label
	if profile_lbl != null:
		profile_lbl.add_theme_font_size_override("font_size", 13)
		profile_lbl.add_theme_color_override("font_color", LB_HAZE)
	# Section headers ("Host a match", "Join with a code") in Cinzel gold-lt.
	var host_lbl := get_node_or_null("Content/HostSection/HostLabel") as Label
	if host_lbl != null:
		host_lbl.add_theme_font_override("font", _lb_serif_font())
		host_lbl.add_theme_font_size_override("font_size", 16)
		host_lbl.add_theme_color_override("font_color", LB_GOLD_LT)
	var join_lbl := get_node_or_null("Content/JoinSection/JoinLabel") as Label
	if join_lbl != null:
		join_lbl.add_theme_font_override("font", _lb_serif_font())
		join_lbl.add_theme_font_size_override("font_size", 16)
		join_lbl.add_theme_color_override("font_color", LB_GOLD_LT)
	if _status != null:
		_status.add_theme_font_size_override("font_size", 13)
		_status.add_theme_color_override("font_color", LB_HAZE)
	if _code_label != null:
		_code_label.add_theme_font_override("font", _lb_serif_font())
		_code_label.add_theme_font_size_override("font_size", 22)
		_code_label.add_theme_color_override("font_color", LB_PEARL)

func _wrap_profile_in_panel() -> void:
	# Move the ProfileRow into a PanelContainer so it picks up the gold-
	# hairline "panel" treatment from the mockup. Idempotent — bail if we've
	# already reparented.
	var section := get_node_or_null("Content/ProfileSection")
	if section == null:
		return
	if section.has_node("ProfilePanel"):
		return
	var row := section.get_node_or_null("ProfileRow")
	if row == null:
		return
	var panel := PanelContainer.new()
	panel.name = "ProfilePanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.114, 0.2, 0.72)
	sb.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.22)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	# Reparent: remove row from section, add to panel, then add panel to
	# section at row's old index.
	var idx := row.get_index()
	section.remove_child(row)
	panel.add_child(row)
	section.add_child(panel)
	section.move_child(panel, idx)

func _style_inputs() -> void:
	for field in [_name_field, _age_field, _join_code_field]:
		if field == null:
			continue
		_apply_input_style(field)

func _apply_input_style(field: LineEdit) -> void:
	field.add_theme_font_size_override("font_size", 15)
	field.add_theme_color_override("font_color", LB_PEARL)
	field.add_theme_color_override("font_placeholder_color", Color(LB_HAZE.r, LB_HAZE.g, LB_HAZE.b, 0.8))
	field.add_theme_color_override("caret_color", LB_GOLD_LT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.05)
	normal.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.25)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 15
	normal.content_margin_right = 15
	normal.content_margin_top = 13
	normal.content_margin_bottom = 13
	var focus := normal.duplicate()
	focus.bg_color = Color(1, 1, 1, 0.08)
	focus.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.6)
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("focus", focus)
	field.add_theme_stylebox_override("read_only", normal.duplicate())

func _style_code_field() -> void:
	if _join_code_field == null:
		return
	# Bigger, centred, weightier — reads as a code rather than freeform text.
	_join_code_field.add_theme_font_size_override("font_size", 20)
	_join_code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_code_field.placeholder_text = "ABCDE"

func _style_lobby_button(btn: Button, kind: String) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 15
	sb.content_margin_bottom = 15
	match kind:
		"prim":
			sb.bg_color = LB_GOLD
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.border_width_top = 0
			sb.border_width_bottom = 0
			sb.shadow_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.35)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 5)
			btn.add_theme_color_override("font_color", LB_INK_ON_GOLD)
			btn.add_theme_color_override("font_hover_color", LB_INK_ON_GOLD)
			btn.add_theme_color_override("font_pressed_color", LB_INK_ON_GOLD)
			btn.add_theme_color_override("font_disabled_color", Color(LB_INK_ON_GOLD.r, LB_INK_ON_GOLD.g, LB_INK_ON_GOLD.b, 0.45))
			var hover := sb.duplicate()
			hover.bg_color = LB_GOLD_LT
			hover.shadow_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.5)
			hover.shadow_size = 8
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			var disabled := sb.duplicate()
			disabled.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.35)
			disabled.shadow_size = 0
			btn.add_theme_stylebox_override("disabled", disabled)
		"strong":
			sb.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.10)
			sb.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.55)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			btn.add_theme_color_override("font_color", LB_PEARL)
			btn.add_theme_color_override("font_hover_color", LB_PEARL)
			btn.add_theme_color_override("font_pressed_color", LB_PEARL)
			btn.add_theme_color_override("font_disabled_color", Color(LB_PEARL.r, LB_PEARL.g, LB_PEARL.b, 0.35))
			var hover := sb.duplicate()
			hover.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.18)
			hover.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.8)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			var disabled := sb.duplicate()
			disabled.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.04)
			disabled.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.2)
			btn.add_theme_stylebox_override("disabled", disabled)
		_:  # ghost
			sb.bg_color = Color(1, 1, 1, 0.04)
			sb.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.3)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			btn.add_theme_color_override("font_color", LB_MIST)
			btn.add_theme_color_override("font_hover_color", LB_PEARL)
			btn.add_theme_color_override("font_pressed_color", LB_PEARL)
			btn.add_theme_color_override("font_disabled_color", Color(LB_MIST.r, LB_MIST.g, LB_MIST.b, 0.35))
			var hover := sb.duplicate()
			hover.bg_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.1)
			hover.border_color = Color(LB_GOLD.r, LB_GOLD.g, LB_GOLD.b, 0.55)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			btn.add_theme_stylebox_override("disabled", sb.duplicate())
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_font_size_override("font_size", 16)

func _lb_serif_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

class_name LobbyScreen
extends Control

# Two-column lobby: Host (create a room, share the code) or Join (paste the
# code, connect). Once both peers are in the room, we jump to GameScreen.
#
# NetworkClient lives on the NetSession autoload so it survives the scene
# swap. If NetSession.has_active_client() is true when GameScreen loads,
# it renders as an online match — otherwise it falls back to vs-AI.

@onready var _status: Label = %StatusLabel
@onready var _code_label: Label = %CodeLabel
@onready var _host_button: Button = %HostButton
@onready var _join_code_field: LineEdit = %JoinCodeField
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton

const GAME_SCREEN_PATH := "res://scenes/GameScreen.tscn"
const MAIN_MENU_PATH := "res://scenes/MainMenu.tscn"

var _client: NetworkClient = null
var _is_host: bool = false

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_join_code_field.text_changed.connect(_refresh_join_enabled)
	_refresh_join_enabled(_join_code_field.text)
	_status.text = ""
	_code_label.text = ""
	# Clear any prior net session so a fresh visit doesn't inherit stale state.
	_net_session().reset()

func _refresh_join_enabled(t: String) -> void:
	_join_button.disabled = t.strip_edges().length() != 5

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
		_host_button.disabled = false
		http.queue_free()

func _on_room_created(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_status.text = "Relay error (HTTP %d)" % response_code
		_host_button.disabled = false
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not parsed.has("code"):
		_status.text = "Bad relay response"
		_host_button.disabled = false
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

# --- Shared: WebSocket handshake -----------------------------------------

func _connect_socket(code: String) -> void:
	_client = NetworkClient.new()
	add_child(_client)
	_client.joined.connect(_on_joined)
	_client.opponent_arrived.connect(_on_opponent_arrived)
	_client.opponent_left.connect(_on_opponent_left)
	_client.error_occurred.connect(_on_net_error)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_to(NetConfig.ws_url(), code)

func _on_joined(peer_id: int) -> void:
	_status.text = ("Room ready, waiting for opponent…" if peer_id == 0
		else "Connected, starting match…")

func _on_opponent_arrived() -> void:
	_status.text = "Opponent connected — starting…"
	# Hand off the live socket to the singleton, then swap scene.
	var ns := _net_session()
	ns.client = _client
	ns.local_player_id = _client.local_peer_id
	# Detach from this scene so the autoload owns it going forward.
	remove_child(_client)
	ns.add_child(_client)
	_client = null
	get_tree().change_scene_to_file(GAME_SCREEN_PATH)

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
	_host_button.disabled = false
	_refresh_join_enabled(_join_code_field.text)
	if _client != null:
		_client.close()
		_client.queue_free()
		_client = null

func _on_back_pressed() -> void:
	_reset_local_client()
	_net_session().reset()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

# Autoload access via node path (see MainMenu for rationale).
func _net_session() -> Node:
	return get_tree().root.get_node_or_null("NetSession")

class_name NetworkClient
extends Node

# Thin WebSocket wrapper around the two-peer relay in server/server.js.
#
# Lifecycle:
#   c = NetworkClient.new()
#   add_child(c)
#   c.connect_to("ws://host:port", "ROOMCODE")
#   await c.joined                     # → local_peer_id set to 0 or 1
#   await c.opponent_arrived           # → both peers are in the room
#   c.send({"kind": "bank_card", ...})
#   c.event_received.connect(...)      # incoming from the other peer
#
# The `event_received` payload is whatever dict the caller sent — this layer
# is transport only, no game semantics.

signal joined(local_peer_id: int)
signal opponent_arrived
signal opponent_left
signal event_received(payload: Dictionary)
signal error_occurred(reason: String)
signal disconnected

var local_peer_id: int = -1
var connected_to: String = ""
var room_code: String = ""

var _socket: WebSocketPeer
var _last_state: int = WebSocketPeer.STATE_CLOSED
var _sent_hello: bool = false

func _ready() -> void:
	set_process(false)

# `ws_url` should be the WebSocket base like ws://host:8788/ws. `room` is the
# 5-char code from `POST /rooms`.
func connect_to(ws_url: String, room: String) -> void:
	connected_to = ws_url
	room_code = room.to_upper()
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(ws_url)
	if err != OK:
		error_occurred.emit("connect_failed: %d" % err)
		return
	_sent_hello = false
	set_process(true)

func close() -> void:
	set_process(false)
	if _socket != null:
		_socket.close()
	_socket = null

func send(payload: Dictionary) -> void:
	if _socket == null:
		return
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var env := { "op": "message", "payload": payload }
	_socket.send_text(JSON.stringify(env))

func _process(_dt: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _sent_hello:
		_sent_hello = true
		var hello := { "op": "hello", "room": room_code }
		_socket.send_text(JSON.stringify(hello))

	while state == WebSocketPeer.STATE_OPEN and _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		_handle_packet(packet.get_string_from_utf8())

	if state != _last_state:
		_last_state = state
		if state == WebSocketPeer.STATE_CLOSED:
			set_process(false)
			disconnected.emit()

func _handle_packet(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var op: String = String(msg.get("op", ""))
	match op:
		"joined":
			local_peer_id = int(msg.get("peer_id", -1))
			joined.emit(local_peer_id)
			# If a second peer was already in the room when we joined, treat
			# ourselves as already-paired (we're the second peer).
			if int(msg.get("peers", 1)) >= 2:
				opponent_arrived.emit()
		"peer_joined":
			opponent_arrived.emit()
		"peer_left":
			opponent_left.emit()
		"message":
			var payload_var: Variant = msg.get("payload")
			if payload_var is Dictionary:
				event_received.emit(payload_var)
		"error":
			error_occurred.emit(String(msg.get("reason", "unknown")))

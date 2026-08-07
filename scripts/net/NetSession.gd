extends Node

# Autoloaded singleton — carries the NetworkClient across a scene switch so
# LobbyScreen can hand it to GameScreen without re-connecting.
#
# `local_player_id` mirrors the peer_id assigned by the relay (0 = host,
# 1 = guest). GameScreen uses it in place of the old HUMAN_ID constant.
# When both are null / -1 we're in offline (vs-AI) mode.

var client: NetworkClient = null
var local_player_id: int = -1
# Player profiles exchanged in the lobby before the match starts. Used for
# on-board name display and for the "youngest starts first" tie-break.
var local_name: String = ""
var local_age: int = 0
var opponent_name: String = ""
var opponent_age: int = 0

func has_active_client() -> bool:
	return client != null and local_player_id >= 0

# Which peer_id starts the match. Younger player first; on a tie, the host
# (peer 0) goes. Called on both peers — both agree on the answer because
# they've both exchanged profiles.
func starting_player_id() -> int:
	if opponent_age <= 0:
		return 0  # No profile yet — host default.
	if local_age < opponent_age:
		return local_player_id
	if local_age > opponent_age:
		return 1 - local_player_id
	return 0

func reset() -> void:
	if client != null:
		client.close()
		client.queue_free()
	client = null
	local_player_id = -1
	local_name = ""
	local_age = 0
	opponent_name = ""
	opponent_age = 0

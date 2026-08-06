extends Node

# Autoloaded singleton — carries the NetworkClient across a scene switch so
# LobbyScreen can hand it to GameScreen without re-connecting.
#
# `local_player_id` mirrors the peer_id assigned by the relay (0 = host,
# 1 = guest). GameScreen uses it in place of the old HUMAN_ID constant.
# When both are null / -1 we're in offline (vs-AI) mode.

var client: NetworkClient = null
var local_player_id: int = -1

func has_active_client() -> bool:
	return client != null and local_player_id >= 0

func reset() -> void:
	if client != null:
		client.close()
		client.queue_free()
	client = null
	local_player_id = -1

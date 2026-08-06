class_name NetConfig
extends RefCounted

# Relay server endpoints. Override for a deployed relay by editing these two
# constants. The web export can also override via a `?server=host:port`
# query string (see LobbyScreen).

const DEFAULT_HTTP_BASE := "http://localhost:8788"
const DEFAULT_WS_URL := "ws://localhost:8788/ws"

static func http_base() -> String:
	# TODO: swap for a project setting or env var when we ship a hosted relay.
	return DEFAULT_HTTP_BASE

static func ws_url() -> String:
	return DEFAULT_WS_URL

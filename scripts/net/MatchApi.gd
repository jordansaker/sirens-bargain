class_name MatchApi
extends RefCounted

# Thin async wrapper around the match-history HTTP API. POST after a match
# completes; GET when the leaderboard opens.
#
# API expects and returns the same JSON shape per match:
#   { "endedAt":    ISO-8601 UTC string,
#     "turns":      int,
#     "winner":     <name in players[]>,
#     "players":    [ { "name": str, "realms": int, "steals": int,
#                       "tributes": int, "highestRent": int } ] }
#   `highestRent` is the single largest rent payment that player received
#   during the match (max of a single settlement total, not the sum).
#   The GET returns the same schema per match; the leaderboard aggregates
#   `highestRent` as a MAX across matches (biggest-ever rent per player).

const BASE_URL := "https://hq.jordansakerdev.com/api/sirens-bargain"
# Shared key — this ships in the web build, so it's not a secret in the
# security sense, just a coarse gate so random scans don't spam the server.
const SECRET := "2dd527d8e29ecf9deeace5dead9397f1e8920d2e209888b0899e94fcc5bdcf79"

static func _base_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Api-Key: %s" % SECRET,
		"Authorization: Bearer %s" % SECRET,
	])

# Fire-and-forget POST of a completed match. Cleans its own HTTPRequest up
# on completion so callers don't have to manage the node's lifecycle.
static func post_match(host: Node, payload: Dictionary) -> void:
	if host == null or not host.is_inside_tree():
		return
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		if code < 200 or code >= 300:
			push_warning("MatchApi POST HTTP %d: %s" % [code, body.get_string_from_utf8()])
		http.queue_free()
	)
	var body := JSON.stringify(payload)
	var err := http.request(BASE_URL, _base_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("MatchApi POST couldn't start: err %d" % err)
		http.queue_free()

# Async GET — invokes `on_done` with the parsed match array (or an empty
# array on any failure, so callers don't need to distinguish error paths).
static func fetch_matches(host: Node, on_done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		on_done.call([])
		return
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		var matches: Array = []
		if code >= 200 and code < 300:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				matches = parsed as Array
			elif parsed is Dictionary and (parsed as Dictionary).has("matches"):
				var m: Variant = (parsed as Dictionary)["matches"]
				if m is Array:
					matches = m
		else:
			push_warning("MatchApi GET HTTP %d: %s" % [code, body.get_string_from_utf8()])
		http.queue_free()
		on_done.call(matches)
	)
	var err := http.request(BASE_URL, _base_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		push_warning("MatchApi GET couldn't start: err %d" % err)
		http.queue_free()
		on_done.call([])

# UTC ISO-8601 stamp of the current moment ("2026-08-08T22:40:11Z").
static func iso_utc_now() -> String:
	var dt := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(dt.year), int(dt.month), int(dt.day),
		int(dt.hour), int(dt.minute), int(dt.second),
	]

class_name MatchApi
extends RefCounted

# Thin async wrapper around the match-history HTTP API.
#   POST /matches      after a match completes.
#     Required headers: x-sirens-timestamp (unix seconds) and
#     x-sirens-signature (hex HMAC-SHA256 of "<timestamp>.<raw body>" with
#     SECRET as the key).
#   GET  /leaderboard  when the leaderboard screen opens.
#
# API expects and returns the same JSON shape per match:
#   { "endedAt":    ISO-8601 UTC string,
#     "turns":      int,
#     "winner":     <name in players[]>,
#     "players":    [ { "name": str, "realms": int, "steals": int,
#                       "tributes": int, "highestRent": int,
#                       "leastAmountMoves": int } ] }
#   `highestRent` is the single largest rent payment that player received
#   during the match (max of a single settlement total, not the sum).
#   `leastAmountMoves` is that player's total moves this match (banks, lays,
#   attaches, action plays, Ride the Current draws). Leaderboard aggregates
#   as a MIN across matches — the player's fewest-moves game.
#   The GET returns the same schema per match; the leaderboard aggregates
#   `highestRent` as a MAX across matches (biggest-ever rent per player).

const BASE_URL := "https://hq.jordansakerdev.com/api/sirens-bargain"
const POST_URL := BASE_URL + "/matches"
const GET_URL := BASE_URL + "/leaderboard"
# Shared key — this ships in the web build, so it's not a secret in the
# security sense, just a coarse gate so random scans don't spam the server.
# Doubles as the HMAC key for POST body signatures.
const SECRET := "2dd527d8e29ecf9deeace5dead9397f1e8920d2e209888b0899e94fcc5bdcf79"

static func _get_headers() -> PackedStringArray:
	# /leaderboard is public; keep the request "CORS simple" (only safelisted
	# headers) so the browser skips the preflight. Adding X-Api-Key/Authorization
	# forces a preflight the server's Access-Control-Allow-Headers doesn't
	# whitelist, and the web build's fetch fails silently.
	return PackedStringArray([
		"Accept: application/json",
	])

# POST /matches requires an HMAC signature over "<unix_seconds>.<raw_body>"
# with SECRET as the key. Server rejects the request without both the
# timestamp and matching signature headers.
static func _post_headers(timestamp: int, body: String) -> PackedStringArray:
	var sig := _hmac_sha256_hex(SECRET, "%d.%s" % [timestamp, body])
	return PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"x-sirens-timestamp: %d" % timestamp,
		"x-sirens-signature: %s" % sig,
	])

# HMAC-SHA256(key, msg) → lowercase hex string. Uses Godot's built-in
# HMACContext so no third-party crypto is needed for the web build.
static func _hmac_sha256_hex(key: String, msg: String) -> String:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, key.to_utf8_buffer())
	ctx.update(msg.to_utf8_buffer())
	var raw: PackedByteArray = ctx.finish()
	var out := ""
	for b in raw:
		out += "%02x" % b
	return out

# Fire-and-forget POST of a completed match. Cleans its own HTTPRequest up
# on completion so callers don't have to manage the node's lifecycle.
static func post_match(host: Node, payload: Dictionary) -> void:
	if host == null or not host.is_inside_tree():
		return
	var http := HTTPRequest.new()
	host.add_child(http)
	# print + push_warning both — print surfaces to the browser console on the
	# web build (push_warning only shows in the Godot editor).
	http.request_completed.connect(func(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		var body_text := body.get_string_from_utf8()
		if code < 200 or code >= 300:
			print("[MatchApi] POST failed HTTP %d: %s" % [code, body_text])
			push_warning("MatchApi POST HTTP %d: %s" % [code, body_text])
		else:
			print("[MatchApi] POST ok HTTP %d" % code)
		http.queue_free()
	)
	var body := JSON.stringify(payload)
	var timestamp := int(Time.get_unix_time_from_system())
	print("[MatchApi] POST %s body=%s" % [POST_URL, body])
	var err := http.request(POST_URL, _post_headers(timestamp, body), HTTPClient.METHOD_POST, body)
	if err != OK:
		print("[MatchApi] POST couldn't start: err %d" % err)
		push_warning("MatchApi POST couldn't start: err %d" % err)
		http.queue_free()

# Async GET /leaderboard — invokes `on_done` with the parsed `entries` array
# from the leaderboard response (or an empty array on any failure so callers
# don't need to distinguish error paths). Each entry is a per-player
# aggregate: {name, wins, losses, matches, winRate, totalRealms, totalSteals,
# totalTributes, highestRent, lastMatchAt}. See LeaderboardResponse in the
# server for the full TypeScript definition.
static func fetch_leaderboard(host: Node, on_done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		on_done.call([])
		return
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		var body_text := body.get_string_from_utf8()
		var entries: Array = []
		if code >= 200 and code < 300:
			print("[MatchApi] GET ok HTTP %d" % code)
			var parsed: Variant = JSON.parse_string(body_text)
			# Response envelope: {ok: true, entries: [...]} on success.
			# {ok: false, error: "..."} on server-side rejection (still 200).
			if parsed is Dictionary:
				var d: Dictionary = parsed
				if bool(d.get("ok", false)):
					var e: Variant = d.get("entries", [])
					if e is Array:
						entries = e
				else:
					print("[MatchApi] GET server-error: %s" % String(d.get("error", "?")))
		else:
			print("[MatchApi] GET failed HTTP %d: %s" % [code, body_text])
			push_warning("MatchApi GET HTTP %d: %s" % [code, body_text])
		http.queue_free()
		on_done.call(entries)
	)
	print("[MatchApi] GET %s" % GET_URL)
	var err := http.request(GET_URL, _get_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		print("[MatchApi] GET couldn't start: err %d" % err)
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

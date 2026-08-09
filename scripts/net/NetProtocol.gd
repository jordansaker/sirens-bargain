class_name NetProtocol
extends RefCounted

# Event catalog for online-PvP wire messages. Each event mirrors one
# state-mutating TurnManager call (or a bookkeeping tick like deck_init and
# turn_ended). Both peers apply identical event streams; card lookups go by
# `id` (unique per copy in the deck).
#
# Event dictionaries always carry a "kind" key. Payload shapes:
#
#   deck_init         {seed, current_player, hands: {id: [card_id...]},
#                      draw_order: [card_id...]}
#   bank              {actor, card_id}
#   play_realm        {actor, card_id, realm}
#   play_ride         {actor, card_id}
#   play_cottage      {actor, card_id, realm}
#   play_palace       {actor, card_id, realm}
#   reassign_wild     {actor, card_id, from, to}
#   initiate_eel      {actor, card_id, target, stolen_id, dest}
#   initiate_trade    {actor, card_id, target, own_id, their_dest,
#                      their_id, own_dest}
#   initiate_kraken   {actor, card_id, target, realm}
#   initiate_toll     {actor, card_id, target}
#   initiate_feast    {actor, card_id}
#   initiate_tribute  {actor, card_id, charger_realm, target, ht_id}
#   refuse            {target, refuser, card_id}
#   resolve           {}      # triggers resolve_pending + payer-side settle
#   end_turn          {actor, discard_ids: [card_id...]}

const KIND_DECK_INIT := "deck_init"
const KIND_BANK := "bank"
const KIND_PLAY_REALM := "play_realm"
const KIND_PLAY_RIDE := "play_ride"
const KIND_PLAY_COTTAGE := "play_cottage"
const KIND_PLAY_PALACE := "play_palace"
const KIND_REASSIGN_WILD := "reassign_wild"
const KIND_MOVE_MODIFIER := "move_modifier"
const KIND_INIT_EEL := "initiate_eel"
const KIND_INIT_TRADE := "initiate_trade"
const KIND_INIT_KRAKEN := "initiate_kraken"
const KIND_INIT_TOLL := "initiate_toll"
const KIND_INIT_FEAST := "initiate_feast"
const KIND_INIT_TRIBUTE := "initiate_tribute"
const KIND_REFUSE := "refuse"
const KIND_RESOLVE := "resolve"
const KIND_SETTLE_PAYMENT := "settle_payment"
const KIND_NUDGE := "nudge"
# Splash is the visual sibling to Nudge — spawns the ripple SplashEffect on
# the remote peer's screen. Same "ping the other player" idea, different vibe.
const KIND_SPLASH := "splash"
const KIND_END_TURN := "end_turn"
# Guest→Host: "please (re-)send me the deck_init payload." Sent when the
# guest's GameScreen finishes wiring up and is waiting on the initial deal.
# Idempotent — the host just re-serialises current game_state.
const KIND_REQUEST_DECK := "request_deck"

# Serialise a GameState + starting hands into a deck_init payload. Called
# once by the host at match start; the guest applies via `apply_deck_init`.
static func build_deck_init(gs: GameState, seed_value: int) -> Dictionary:
	var hands: Dictionary = {}
	for p in gs.players:
		var ids: Array = []
		for c in p.hand:
			ids.append(c.id)
		hands[p.id] = ids
	var draw_order: Array = []
	for c in gs.draw_pile:
		draw_order.append(c.id)
	return {
		"kind": KIND_DECK_INIT,
		"seed": seed_value,
		"current_player": gs.current_player_index,
		"hands": hands,
		"draw_order": draw_order,
	}

# Recreates a GameState from a deck_init payload. All cards are freshly
# instantiated via DeckBuilder, then bucketed into hands / draw pile.
static func apply_deck_init(payload: Dictionary) -> GameState:
	var deck := DeckBuilder.build_deck()
	var by_id: Dictionary = {}
	for c in deck:
		by_id[c.id] = c

	var seed_value := int(payload.get("seed", 0))
	var num_players := int((payload.get("hands", {}) as Dictionary).size())
	# Empty deck to start — we'll refill via draw_order below.
	var gs := GameState.new(num_players, [] as Array[CardData], seed_value)
	gs.current_player_index = int(payload.get("current_player", 0))

	var hands: Dictionary = payload.get("hands", {})
	for k in hands.keys():
		var pid: int = int(k)
		var player := gs.players[pid]
		for card_id in hands[k]:
			var card: CardData = by_id.get(card_id)
			if card != null:
				player.hand.append(card)

	var draw_order: Array = payload.get("draw_order", [])
	for card_id in draw_order:
		var card: CardData = by_id.get(card_id)
		if card != null:
			gs.draw_pile.append(card)
	return gs

# --- Helpers for lookup by ID -------------------------------------------

static func find_in(cards: Array, card_id: String) -> CardData:
	for c in cards:
		if c is CardData and (c as CardData).id == card_id:
			return c
	return null

static func find_in_hand(player: PlayerState, card_id: String) -> CardData:
	return find_in(player.hand, card_id)

# Find a card sitting in any of a player's realm stacks. Returns null if not
# found (e.g. the card is already gone by the time we apply an event).
static func find_in_realms(player: PlayerState, card_id: String) -> CardData:
	for r in player.realms.keys():
		var stack: Array = player.realms[r]
		var c := find_in(stack, card_id)
		if c != null:
			return c
	return null

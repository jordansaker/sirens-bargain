class_name GameScreen
extends Control

# Play surface built to match docs/sirens-bargain-screen-mockup.html. The
# layout goes: opponent strip (name/bank + realm chips), mid table
# (draw/turn/discard), player strip, hand row, three action buttons
# (Bank it | Play card | End turn).
#
# Interaction model:
#   * Tap a card in your hand → it lifts out of the row (that's the selection
#     signal, not a modal).
#   * Bank it → banks the selected card.
#   * Play card → plays the selected card. Targeting choices open a small
#     ActionMenu overlay for realm / opponent / opponent-card picks.
#   * End turn → ends the turn; if over hand-limit, first prompts for discards.
#
# The "plays left" counter is centred in the mid table on purpose — the 3-play
# limit is the core constraint of the game and needs to be impossible to miss.
#
# Phase 7 limitation: the human can't defend an AI-initiated action with
# Siren's Refusal — the AI resolves refusable actions inline. Left as a
# Phase 8 polish item.

enum InteractionState {
	IDLE,
	SELECT_OWN_REALM,
	SELECT_OWN_COMPLETED_REALM,
	SELECT_OWN_REALM_FOR_CHARGE,
	SELECT_OPP_PLAYER,
	SELECT_OPP_REALM,
	SELECT_OPP_CARD,
	SELECT_OWN_CARD_FOR_TRADE,
	SELECT_OWN_DEST_FOR_STOLEN,
	SELECT_MODIFIER_DEST,
	DISCARD,
	AI_TURN,
	GAME_OVER,
}

# These are locked constants in vs-AI mode. In online play HUMAN_ID becomes
# the local peer id (0 for host, 1 for guest) and OPPONENT_NAME becomes the
# other peer's label — kept as vars so every existing reference just works.
const HUMAN_NAME := "You"
var HUMAN_ID: int = 0
var OPPONENT_NAME: String = "Coral"

# Palette lifted from docs/sirens-bargain-gameplay-styled.html so chrome
# (buttons, draw pile, turn block, bottom bar) matches the mockup.
const CH_NAVY := Color("0B1D33")
const CH_NAVY_DEEP := Color("06111F")
const CH_NAVY_MID := Color("102b49")
const CH_GOLD := Color("C9A227")
const CH_GOLD_LT := Color("E4C25A")
const CH_GOLD_D := Color("A5811C")
const CH_PEARL := Color("EDE6D4")
const CH_HAZE := Color("9DB6C4")
const CH_MIST := Color("C4D6E2")
const CH_INK_ON_GOLD := Color("2A1F07")

@onready var _turn_label: Label = %TurnLabel
@onready var _plays_label: Label = %PlaysLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _discard_top_banner: ColorRect = %DiscardTopBanner
@onready var _discard_top_label: Label = %DiscardTopLabel
@onready var _discard_art: TextureRect = %DiscardArt
@onready var _draw_label: Label = %DrawLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _log_scroll: ScrollContainer = %LogScroll
@onready var _log_list: VBoxContainer = %LogList
@onready var _turn_banner: Label = %TurnBanner
@onready var _to_menu_button: Button = %ToMenuButton
@onready var _game_over_scrim: ColorRect = %GameOverScrim
@onready var _game_over_panel: Panel = %GameOverPanel
@onready var _game_over_title: Label = %GameOverTitle
@onready var _game_over_subtitle: Label = %GameOverSubtitle
@onready var _game_over_stats: VBoxContainer = %GameOverStats
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _refusal_scrim: ColorRect = %RefusalScrim
@onready var _refusal_panel: Panel = %RefusalPanel
@onready var _refusal_title: Label = %RefusalTitle
@onready var _refusal_body: Label = %RefusalBody
# Lazy-built row for card-art previews of the card/set being stolen — sits
# between the title and the body text so the player can see EXACTLY what's
# on the line before deciding to burn a Siren's Refusal.
var _refusal_cards_row: HBoxContainer = null
@onready var _refuse_button: Button = %RefuseButton
@onready var _accept_button: Button = %AcceptButton

signal _refusal_answered(refuse: bool)
# Emitted by the payment picker (confirm → cards, close → null → auto-fallback).
signal _payment_answered(picks: Variant)
# Wired by the online refusable-action protocol so `_run_online_refusable_flow`
# can wait for the opponent's decision (a REFUSE or RESOLVE arriving over the
# wire). Emitted with "refused" or "resolved".
signal _remote_refusal_decision(kind: String)
# Emitted after a SETTLE_PAYMENT event has been applied — used to gate the
# receiver's `_settle_online` loop.
signal _remote_payment_decided
@onready var _opponent_board: PlayerBoardView = %OpponentBoard
@onready var _player_board: PlayerBoardView = %PlayerBoard
@onready var _hand_row: Control = %HandRow
@onready var _bank_button: Button = %BankButton
@onready var _play_button: Button = %PlayButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _fan_button: Button = %FanButton
@onready var _zoom_button: Button = %ZoomButton
@onready var _nudge_button: Button = %NudgeButton
@onready var _menu_root: Panel = %ActionMenu
@onready var _menu_title: Label = %MenuTitle
@onready var _menu_scroll: ScrollContainer = %MenuScroll
@onready var _menu_buttons: VBoxContainer = %MenuButtons
@onready var _menu_cancel: Button = %MenuCancel
@onready var _peek_root: Panel = %RealmPeek
@onready var _peek_title: Label = %PeekTitle
@onready var _peek_subtitle: Label = %PeekSubtitle
@onready var _peek_row: HBoxContainer = %PeekRow
@onready var _peek_close: Button = %PeekClose
@onready var _peek_confirm: Button = %PeekConfirm
@onready var _peek_prev: Button = %PeekPrev
@onready var _peek_next: Button = %PeekNext
@onready var _card_peek_scrim: ColorRect = %CardPeekScrim
@onready var _card_peek: Panel = %CardPeek
@onready var _card_peek_banner: Panel = %CardPeekBanner
@onready var _card_peek_title: Label = %CardPeekTitle
@onready var _card_peek_body: Panel = %CardPeekBody
@onready var _card_peek_subtype: Label = %CardPeekSubtype
@onready var _card_peek_description: Label = %CardPeekDescription
@onready var _card_peek_info: Panel = %CardPeekInfo
@onready var _card_peek_info_text: Label = %CardPeekInfoText
@onready var _card_peek_bank: Button = %CardPeekBank
@onready var _card_peek_play: Button = %CardPeekPlay
@onready var _card_peek_close: Button = %CardPeekClose
@onready var _card_peek_prev: Button = %CardPeekPrev
@onready var _card_peek_next: Button = %CardPeekNext

var _card_peek_card: CardData = null
var _card_peek_art: TextureRect = null

var _gs: GameState
var _tm: TurnManager
var _ais: Dictionary = {}     # id -> AIOpponent (opponents only; empty when online)
var _sfx: SoundEffects = null

# Online-play plumbing. Null in vs-AI mode.
var _net_client: NetworkClient = null
var _is_online: bool = false
var _waiting_for_deck_init: bool = false

var _state: int = InteractionState.IDLE
var _selected_card: CardData = null
var _ctx: Dictionary = {}      # scratchpad for multi-step target picks
var _pending_discards: Array[CardData] = []
var _hand_fanned: bool = false
var _fan_timer: SceneTreeTimer = null
# Double-tap Fan → locked-open: no auto-collapse until the user single-taps
# to unfan. Time-based double-tap detection since `toggled` doesn't hand us
# the raw event with its `double_click` bit.
var _fan_locked: bool = false
var _fan_last_toggle_msec: int = 0
var _zoom_enabled: bool = false
# Persisted so the host can re-serialise the deck_init payload when the guest
# asks (rematch race: host builds the deck before the guest's new scene has
# wired up, guest requests once ready). Kept alongside the built _gs so the
# hands + draw_order in the resend match what the host started with.
var _deck_init_seed: int = 0
# Hand drag-to-reorder scratchpad. Populated by _on_hand_drag_started, updated
# by _on_hand_drag_moved as the pointer crosses card slots, and consumed by
# _on_hand_drag_ended when the pointer releases. Cosmetic only — never
# broadcast; the underlying hand array reorder is local to this peer.
var _drag_card: CardData = null
var _drag_view: CardView = null
var _drag_from_index: int = -1
var _drag_current_index: int = -1
var _drag_grab_offset: Vector2 = Vector2.ZERO
# 3 dots below the plays counter — filled = plays remaining, dim = spent.
var _plays_dots: HBoxContainer = null
# Match timer + stats — populated at setup, updated live via TurnManager
# signals, snapshotted onto the game-over card list.
var _match_start_msec: int = 0
var _match_stats: Dictionary = {} # player_id -> {"pearls":int,"steals":int,"tributes":int}
var _turns_played: int = 0

# True on the attacker's peer between "action resolved with an owed dict"
# and "opponent broadcast their SETTLE_PAYMENT". End Turn stays disabled
# during that window so we can't jump to the next turn mid-settlement.
var _awaiting_payment: bool = false
# Divider + row for cottage / palace modifiers rendered below the realm
# cards in the realm-peek modal. Only shown when the peeked realm has
# modifiers attached; tapping a modifier opens the move flow.
var _peek_divider: ColorRect = null
var _peek_modifiers_row: HBoxContainer = null
# Captures whatever _tm.resolve_pending() returned on the most recent apply,
# so `_run_online_refusable_flow` can return the outcome even when RESOLVE
# was triggered by the opponent's broadcast (i.e. `_apply_resolve` ran the
# resolve before the local await got the signal).
var _last_resolve_result: Variant = null
# Wall-clock the attacker's peer holds so it can pad every resolve with a
# minimum visible mask duration. Without this, the time between "played
# Kraken" and "effect fires" leaks whether the defender was actually
# holding a Refusal card (auto-pass = instant, thinking = 2-3s pause).
const _REFUSABLE_MASK_MSEC: int = 1500
var _pending_action_initiated_msec: int = 0

func _ready() -> void:
	# Grab the online session first so _setup_game can branch on host/guest.
	var ns := get_tree().root.get_node_or_null("NetSession")
	if ns != null and ns.has_method("has_active_client") and ns.has_active_client():
		_is_online = true
		_net_client = ns.client
		HUMAN_ID = ns.local_player_id
		OPPONENT_NAME = ns.opponent_name if ns.opponent_name != "" else "Opponent"
	_setup_game()
	_configure_boards()
	_setup_sound()
	_wire_signals()
	_apply_mockup_styling()
	_style_card_peek()
	_hide_menu()
	_hide_peek()
	_hide_card_peek()
	_hide_game_over()
	_hide_refusal_modal()
	if _waiting_for_deck_init:
		_prompt("Waiting for host to deal…")
		_kick_off_deck_request()
	elif _is_online and _gs.current_player_index != HUMAN_ID:
		# Host built the deck but the guest is younger and starts first —
		# hand the local peer directly into the waiting state.
		_await_opponent_turn()
	else:
		_start_human_turn()

func _setup_sound() -> void:
	_sfx = SoundEffects.new()
	add_child(_sfx)

# --- Game setup ----------------------------------------------------------

func _setup_game() -> void:
	# Host (or offline) creates and deals the deck locally.
	# Guest opens an empty state and waits for a deck_init event before dealing.
	if _is_online and HUMAN_ID != 0:
		_gs = GameState.new(2, [] as Array[CardData], 0)
		_tm = TurnManager.new(_gs)
		_waiting_for_deck_init = true
		return

	var deck := DeckBuilder.build_deck()
	var seed_value: int = Time.get_ticks_usec()
	_deck_init_seed = seed_value
	_gs = GameState.new(2, deck, seed_value)
	_tm = TurnManager.new(_gs)
	_shuffle_draw_pile()
	for p in _gs.players:
		for i in range(5):
			var c := _gs.draw_card()
			if c != null:
				p.hand.append(c)
	if _is_online:
		# Host: youngest-goes-first tie-break lives on NetSession and is
		# computed identically on both peers. Set it before the guest asks
		# so the resend picks up the right current_player.
		var ns := get_tree().root.get_node_or_null("NetSession")
		if ns != null and ns.has_method("starting_player_id"):
			_gs.current_player_index = ns.starting_player_id()
		# NOTE: we no longer eagerly send deck_init here. On rematch the guest's
		# new scene isn't wired to receive it yet, so the eager send raced past
		# them and left them stuck on "Waiting for host to deal…". The guest
		# now requests it (KIND_REQUEST_DECK) once ready and we respond then.
	else:
		# Vs-AI mode: the opponent seat is an AIOpponent.
		_ais[1] = AIOpponent.new(1)
	_init_match_stats()

func _init_match_stats() -> void:
	_match_start_msec = Time.get_ticks_msec()
	_match_stats.clear()
	if _gs == null:
		return
	for p in _gs.players:
		_match_stats[p.id] = {"pearls": 0, "steals": 0, "tributes": 0, "highest_rent": 0}

func _track_play_for_stats(actor_id: int, text: String) -> void:
	if not _match_stats.has(actor_id):
		_match_stats[actor_id] = {"pearls": 0, "steals": 0, "tributes": 0, "highest_rent": 0}
	# Outcome-phase resolves: "took X from PY (Slippery Eel)" /
	# "(Kraken's Grasp)" — count as one steal for the actor.
	if text.find("(Slippery Eel)") != -1 or text.find("(Kraken's Grasp)") != -1:
		_match_stats[actor_id]["steals"] += 1
	# Resolved tribute-family debts: only fire once per action so we don't
	# double-count on both initiate + resolve.
	if text.begins_with("Tribute on ") or text.begins_with("Toll of the Tides") \
			or text.begins_with("Mermaid's Feast") or text.begins_with("Siren's Toll"):
		_match_stats[actor_id]["tributes"] += 1

func _track_payment_for_stats(_payer_id: int, receiver_id: int, total: int, _card_count: int) -> void:
	if not _match_stats.has(receiver_id):
		_match_stats[receiver_id] = {"pearls": 0, "steals": 0, "tributes": 0, "highest_rent": 0}
	_match_stats[receiver_id]["pearls"] += total
	# Track the single biggest rent collected — one payment total, not the
	# running sum. Used both in the game-over card and in the API payload.
	if total > int(_match_stats[receiver_id].get("highest_rent", 0)):
		_match_stats[receiver_id]["highest_rent"] = total

func _shuffle_draw_pile() -> void:
	# Uses a scratch RNG so _gs.rng stays untouched. This matters for HvH
	# sync: the host runs this at setup while the guest doesn't — if the
	# shuffle mutated _gs.rng, the two peers would enter the game with
	# different RNG state and any in-game reshuffle (draw pile → discard
	# recycled) would produce a DIFFERENT order on each side → desync. With
	# a scratch RNG, both peers' _gs.rng starts at seed_value untouched, so
	# GameState._reshuffle_discard_into_draw produces identical outputs.
	var rng := RandomNumberGenerator.new()
	rng.seed = _deck_init_seed
	var arr: Array[CardData] = _gs.draw_pile
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _configure_boards() -> void:
	# In vs-AI mode player 0 is human, player 1 is AI. In online mode both
	# are human — HUMAN_ID could be either 0 or 1.
	var opp_id: int = 1 - HUMAN_ID if _is_online else 1
	_opponent_board.player = _gs.players[opp_id]
	var opp_tag := "" if _is_online else "AI"
	var opp_letter := OPPONENT_NAME.substr(0, 1) if OPPONENT_NAME != "" else "?"
	_opponent_board.configure(OPPONENT_NAME, opp_tag, opp_letter, CardColors.STEEL, false)
	_player_board.player = _gs.players[HUMAN_ID]
	# Local player initial: from their own name in online mode, "M" in vs-AI.
	var my_letter := "M"
	if _is_online:
		var ns := get_tree().root.get_node_or_null("NetSession")
		if ns != null and String(ns.local_name).length() >= 1:
			my_letter = String(ns.local_name).substr(0, 1)
	_player_board.configure(HUMAN_NAME, "", my_letter, Color("6e5aa8"), true)

func _wire_signals() -> void:
	_bank_button.pressed.connect(_on_bank_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_menu_cancel.pressed.connect(_on_menu_cancel_pressed)
	_peek_close.pressed.connect(_on_peek_close_pressed)
	_to_menu_button.pressed.connect(_on_to_menu_pressed)
	_fan_button.toggled.connect(_on_fan_toggled)
	_zoom_button.toggled.connect(_on_zoom_toggled)
	_nudge_button.pressed.connect(_on_nudge_pressed)
	var discard_box := get_node_or_null("Root/GameCol/MidTable/DiscardPileBox")
	if discard_box is Control:
		(discard_box as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		(discard_box as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		(discard_box as Control).gui_input.connect(_on_discard_pile_input)
	# Double-tap on the background scrim = cancel any targeting flow.
	var bg := get_node_or_null("Background")
	if bg is Control:
		(bg as Control).gui_input.connect(_on_background_gui_input)
	if _net_client != null:
		_net_client.event_received.connect(_on_net_event)
		_net_client.opponent_left.connect(_on_opponent_left)
		_net_client.disconnected.connect(_on_opponent_left)
	_card_peek_bank.pressed.connect(_on_card_peek_bank_pressed)
	_card_peek_play.pressed.connect(_on_card_peek_play_pressed)
	_card_peek_close.pressed.connect(_hide_card_peek)
	_card_peek_prev.pressed.connect(func(): _cycle_card_peek(-1))
	_card_peek_next.pressed.connect(func(): _cycle_card_peek(1))
	# Real SVG chevrons instead of the U+2039/203A single guillemets that
	# Godot's Noto Sans renders inconsistently.
	_card_peek_prev.icon = load("res://assets/icons/chevron-left.svg")
	_card_peek_next.icon = load("res://assets/icons/chevron-right.svg")
	_card_peek_scrim.gui_input.connect(_on_card_peek_scrim_input)
	_opponent_board.realm_chip_pressed.connect(_on_opp_chip_pressed)
	_player_board.realm_chip_pressed.connect(_on_own_chip_pressed)
	_opponent_board.bank_pressed.connect(_on_bank_view_requested)
	_player_board.bank_pressed.connect(_on_bank_view_requested)
	# Play-by-play log fed by TurnManager. Fires for both human and AI plays.
	_tm.play_logged.connect(_on_play_logged)
	_tm.payment_applied.connect(_on_payment_applied)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_refuse_button.pressed.connect(func(): _refusal_answered.emit(true))
	_accept_button.pressed.connect(func(): _refusal_answered.emit(false))
	# Give the AI a coroutine to await when it initiates something at the
	# human — modal → user picks Refuse / Accept → resolve.
	for id in _ais.keys():
		var ai: AIOpponent = _ais[id]
		ai.human_refusal_hook = _prompt_human_refusal
		ai.human_payment_hook = _prompt_human_payment
	_peek_confirm.pressed.connect(_on_peek_confirm_pressed)
	# Realm-peek cycle arrows: browse the peeked player's realms without
	# reopening from a chip tap each time. Only visible in realm-peek mode
	# (hidden by _show_bank_peek / _show_discard_peek / _open_pay_picker).
	_peek_prev.icon = load("res://assets/icons/chevron-left.svg")
	_peek_next.icon = load("res://assets/icons/chevron-right.svg")
	_peek_prev.pressed.connect(func(): _cycle_realm_peek(-1))
	_peek_next.pressed.connect(func(): _cycle_realm_peek(1))

# --- Turn loop -----------------------------------------------------------

func _start_human_turn() -> void:
	_state = InteractionState.IDLE
	_selected_card = null
	# Preserve pay_pending across the ctx wipe. In HvH the attacker can end
	# their turn while we're still in the picker; without this, our own
	# turn-start would clear the picker's state mid-selection and taps stop
	# doing anything.
	var pay_pending: Variant = _ctx.get("pay_pending")
	_ctx.clear()
	if pay_pending != null:
		_ctx["pay_pending"] = pay_pending
	_tm.start_turn()
	_refresh_all()
	_flash_turn_banner("YOUR TURN")
	_prompt("Tap a card in your hand.")

func _end_human_turn() -> void:
	var human := _gs.players[HUMAN_ID]
	var over := human.hand.size() - TurnManager.HAND_LIMIT
	if over > 0:
		_begin_discard(over)
		return
	_do_end_turn([] as Array[CardData])

func _begin_discard(count: int) -> void:
	_state = InteractionState.DISCARD
	_pending_discards.clear()
	_ctx["discard_needed"] = count
	_prompt("Tap %d card(s) to discard." % count)
	_refresh_all()

func _finish_discard() -> void:
	_do_end_turn(_pending_discards)
	_pending_discards.clear()

# Shared "end my turn" — mutates local state, and in online mode broadcasts
# the discards so the opponent's GameState stays in sync.
func _do_end_turn(discards: Array[CardData]) -> void:
	if _is_online:
		var ids: Array = []
		for c in discards:
			ids.append(c.id)
		_net_client.send({
			"kind": NetProtocol.KIND_END_TURN,
			"actor": HUMAN_ID,
			"discard_ids": ids,
		})
	_tm.end_turn(discards)
	_turns_played += 1
	if _is_online:
		_after_turn_transition()
	else:
		_run_ai_turns()

# After a turn ends (local or remote), hand off to whoever is now current.
func _after_turn_transition() -> void:
	if _gs.is_game_over():
		_show_game_over()
		return
	if _gs.current_player_index == HUMAN_ID:
		_start_human_turn()
	else:
		_await_opponent_turn()

func _await_opponent_turn() -> void:
	_state = InteractionState.AI_TURN
	_selected_card = null
	# In HvH the local mirror still needs to advance turn state for the
	# remote player — draw their 2 cards so this peer's copy of their hand
	# matches theirs. Without this, subsequent KIND_PLAY_REALM / KIND_BANK
	# events reference card ids that aren't in the local mirror and
	# NetProtocol.find_in_hand returns null, silently dropping the play.
	# Offline mode skips this because AIOpponent.take_turn calls start_turn
	# itself as part of its own flow.
	if _is_online:
		_tm.start_turn()
	_refresh_all()
	_flash_turn_banner(("%s's turn" % OPPONENT_NAME).to_upper())
	_prompt("Waiting for %s…" % OPPONENT_NAME)

# --- Networked play sync ------------------------------------------------

# Toggle the hand's spread. Auto-collapses after a few seconds so the row
# doesn't stay wide while you're playing.
func _on_fan_toggled(pressed: bool) -> void:
	var now := Time.get_ticks_msec()
	var elapsed := now - _fan_last_toggle_msec
	_fan_last_toggle_msec = now
	# Double-tap window (~400 ms). Two rapid toggles = lock the fan open;
	# force the button visually pressed regardless of what its toggle_mode
	# just did to it.
	if elapsed > 0 and elapsed < 400:
		_fan_locked = true
		_hand_fanned = true
		_fan_button.set_pressed_no_signal(true)
		_fan_timer = null
		_fan_button.text = "Stack"
		_refresh_hand()
		return
	# Single tap → normal toggle, 5-second auto-collapse when fanning open.
	_fan_locked = false
	_hand_fanned = pressed
	_fan_timer = null
	_fan_button.text = "Stack" if pressed else "Fan"
	_refresh_hand()
	if pressed:
		var t := get_tree().create_timer(5.0)
		_fan_timer = t
		_collapse_fan_after(t)

func _collapse_fan_after(t: SceneTreeTimer) -> void:
	await t.timeout
	# Only collapse if this timer is still the active one, the user hasn't
	# manually toggled off, AND they haven't locked the fan via double-tap.
	if _fan_timer != t or not _hand_fanned or _fan_locked:
		return
	_hand_fanned = false
	_fan_button.set_pressed_no_signal(false)
	_fan_button.text = "Fan"
	_fan_timer = null
	_refresh_hand()

func _on_zoom_toggled(pressed: bool) -> void:
	_zoom_enabled = pressed
	_zoom_button.text = "Zoom: on" if pressed else "Zoom: off"
	if not pressed and _card_peek.visible:
		_hide_card_peek()

# Nudge: shake the screen locally + tell the opponent's peer to do the same
# ("hurry up!" ping without hijacking their turn). Rate-limited to one nudge
# per 3 seconds so the button can't be spammed.
var _nudge_last_msec: int = 0

func _on_nudge_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _nudge_last_msec < 3000:
		return
	_nudge_last_msec = now
	_do_shake_effect()
	if _is_online:
		_broadcast({"kind": NetProtocol.KIND_NUDGE, "actor": HUMAN_ID})

func _apply_nudge(_payload: Dictionary) -> void:
	# Received a nudge from the opponent — shake our screen.
	_do_shake_effect()

# Underwater-earthquake feel: tween Root's position in decreasing random
# offsets so the whole play area jitters, then settles. Cheap and works on
# every platform (no shader required).
func _do_shake_effect() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	var origin := root.position
	if _sfx != null:
		_sfx.play("action")
	var tw := create_tween()
	var amplitude := 14.0
	for i in range(9):
		var jitter := Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude),
		)
		tw.tween_property(root, "position", origin + jitter, 0.035) \
			.set_trans(Tween.TRANS_SINE)
		amplitude *= 0.75
	tw.tween_property(root, "position", origin, 0.12) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_background_gui_input(event: InputEvent) -> void:
	# Double-tap the empty background = cancel a targeting flow. Ignored when
	# no flow is active so it doesn't disrupt idle turns.
	if not _is_targeting_state():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_menu_cancel_pressed()

func _on_to_menu_pressed() -> void:
	# Bail to the main menu mid-match. Online sessions get torn down so the
	# other peer sees a proper disconnect.
	var ns := get_tree().root.get_node_or_null("NetSession")
	if ns != null and ns.has_method("reset"):
		ns.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_opponent_left() -> void:
	_prompt("Opponent disconnected — heading back to the menu.")
	_state = InteractionState.GAME_OVER
	_refresh_all()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_net_event(payload: Dictionary) -> void:
	var kind: String = String(payload.get("kind", ""))
	match kind:
		NetProtocol.KIND_DECK_INIT:
			_apply_deck_init(payload)
		NetProtocol.KIND_END_TURN:
			_apply_end_turn(payload)
		NetProtocol.KIND_BANK:
			_apply_bank(payload)
		NetProtocol.KIND_PLAY_REALM:
			_apply_play_realm(payload)
		NetProtocol.KIND_PLAY_RIDE:
			_apply_play_ride(payload)
		NetProtocol.KIND_PLAY_COTTAGE:
			_apply_attach_modifier(payload, true)
		NetProtocol.KIND_PLAY_PALACE:
			_apply_attach_modifier(payload, false)
		NetProtocol.KIND_REASSIGN_WILD:
			_apply_reassign_wild(payload)
		NetProtocol.KIND_MOVE_MODIFIER:
			_apply_move_modifier(payload)
		NetProtocol.KIND_INIT_KRAKEN:
			_apply_initiate_kraken(payload)
		NetProtocol.KIND_INIT_EEL:
			_apply_initiate_eel(payload)
		NetProtocol.KIND_INIT_TRADE:
			_apply_initiate_trade(payload)
		NetProtocol.KIND_INIT_TOLL:
			_apply_initiate_toll(payload)
		NetProtocol.KIND_INIT_FEAST:
			_apply_initiate_feast(payload)
		NetProtocol.KIND_INIT_TRIBUTE:
			_apply_initiate_tribute(payload)
		NetProtocol.KIND_REFUSE:
			_apply_refuse(payload)
		NetProtocol.KIND_RESOLVE:
			_apply_resolve(payload)
		NetProtocol.KIND_SETTLE_PAYMENT:
			_apply_settle_payment(payload)
		NetProtocol.KIND_NUDGE:
			_apply_nudge(payload)
		NetProtocol.KIND_REQUEST_DECK:
			_on_deck_requested()
		_:
			# Unknown event — log for debugging.
			_append_log("[color=#e88][unknown event %s][/color]" % kind)

# Host: guest just asked for the initial deal. Re-serialise _gs into a fresh
# deck_init payload and send it. Idempotent — the guest may retry several
# times before we hear it (e.g. if our _ready hadn't wired up in time).
func _on_deck_requested() -> void:
	if not _is_online or HUMAN_ID != 0:
		return
	if _gs == null or _net_client == null:
		return
	_net_client.send(NetProtocol.build_deck_init(_gs, _deck_init_seed))

# Guest: send a deck_init request now and re-send every ~700ms until we get
# a deck_init back. Handles the rematch race where the host's new scene
# hasn't wired its event_received listener yet when the first request lands.
func _kick_off_deck_request() -> void:
	if _net_client == null:
		return
	_send_deck_request_once()
	var timer := Timer.new()
	timer.name = "DeckRequestRetry"
	timer.wait_time = 0.7
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(_on_deck_request_retry)
	add_child(timer)

func _send_deck_request_once() -> void:
	if _net_client == null or not _waiting_for_deck_init:
		return
	_net_client.send({"kind": NetProtocol.KIND_REQUEST_DECK})

func _on_deck_request_retry() -> void:
	# Deck arrived while the timer was running — tear ourselves down.
	if not _waiting_for_deck_init:
		var t := get_node_or_null("DeckRequestRetry") as Timer
		if t != null:
			t.queue_free()
		return
	_send_deck_request_once()

# Guest applies the host's initial deal, then hooks into the turn loop.
func _apply_deck_init(payload: Dictionary) -> void:
	_gs = NetProtocol.apply_deck_init(payload)
	_tm = TurnManager.new(_gs)
	_waiting_for_deck_init = false
	# Re-connect play_logged since the TurnManager instance changed.
	_tm.play_logged.connect(_on_play_logged)
	_tm.payment_applied.connect(_on_payment_applied)
	_configure_boards()
	_refresh_all()
	if _gs.current_player_index == HUMAN_ID:
		_start_human_turn()
	else:
		_await_opponent_turn()

func _apply_end_turn(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	if actor < 0:
		return
	var player := _gs.players[actor]
	var discard_ids: Array = payload.get("discard_ids", [])
	var discards: Array[CardData] = []
	for id in discard_ids:
		var c := NetProtocol.find_in_hand(player, String(id))
		if c != null:
			discards.append(c)
	_tm.end_turn(discards)
	_turns_played += 1
	_after_turn_transition()

func _apply_bank(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	var card := NetProtocol.find_in_hand(_gs.players[actor], String(payload.get("card_id", "")))
	if card == null:
		return
	_tm.bank_card(card)
	_refresh_all()

func _apply_play_realm(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	var card := NetProtocol.find_in_hand(_gs.players[actor], String(payload.get("card_id", "")))
	if card == null:
		return
	_tm.play_realm(card, String(payload.get("realm", "")))
	_refresh_all()

func _apply_play_ride(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	var card := NetProtocol.find_in_hand(_gs.players[actor], String(payload.get("card_id", "")))
	if card == null:
		return
	_tm.play_ride_the_current(card)
	_refresh_all()

func _apply_attach_modifier(payload: Dictionary, is_cottage: bool) -> void:
	var actor: int = int(payload.get("actor", -1))
	var card := NetProtocol.find_in_hand(_gs.players[actor], String(payload.get("card_id", "")))
	if card == null:
		return
	var realm := String(payload.get("realm", ""))
	if is_cottage:
		_tm.play_coral_cottage(card, realm)
	else:
		_tm.play_pearl_palace(card, realm)
	_refresh_all()

func _apply_reassign_wild(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	var card := NetProtocol.find_in_realms(_gs.players[actor], String(payload.get("card_id", "")))
	if card == null:
		return
	_gs.players[actor].reassign_wild(card, String(payload.get("from", "")), String(payload.get("to", "")))
	_refresh_all()

# Cottage / palace move — the modifier lives on the source realm's
# modifier stack, look it up there and apply the move on the mirror.
func _apply_move_modifier(payload: Dictionary) -> void:
	var actor: int = int(payload.get("actor", -1))
	if actor < 0:
		return
	var player: PlayerState = _gs.players[actor]
	var from_realm := String(payload.get("from", ""))
	var to_realm := String(payload.get("to", ""))
	var card_id := String(payload.get("card_id", ""))
	var card: CardData = null
	for m in player.modifiers_on(from_realm):
		if m.id == card_id:
			card = m
			break
	if card == null:
		return
	player.move_modifier(card, from_realm, to_realm)
	_refresh_all()

# Broadcast a local action to the opponent (no-op in vs-AI mode).
func _broadcast(payload: Dictionary) -> void:
	if _net_client != null:
		_net_client.send(payload)

const AI_PLAY_DELAY := 0.7  # seconds between AI plays so the player can follow

func _run_ai_turns() -> void:
	_state = InteractionState.AI_TURN
	_selected_card = null
	_refresh_all()
	while _gs.current_player_index != HUMAN_ID and not _gs.is_game_over():
		var ai_var: Variant = _ais.get(_gs.current_player_index)
		if ai_var == null:
			break
		var ai: AIOpponent = ai_var
		_flash_turn_banner(("%s's turn" % OPPONENT_NAME).to_upper())
		_prompt("%s is thinking…" % OPPONENT_NAME)
		# Drive the AI one play at a time so the player sees each move and
		# each log entry lands as it happens — rather than watching the
		# whole turn resolve as a silent state change.
		ai.begin_turn(_tm)
		_refresh_all()
		await get_tree().create_timer(AI_PLAY_DELAY * 0.5).timeout
		while _tm.can_play() and not _gs.is_game_over():
			# try_one_play is a coroutine — a refusable action may await the
			# human refusal modal. We must await so the AI doesn't race ahead.
			var made: bool = await ai.try_one_play(_tm, _ais)
			_refresh_all()
			if not made:
				break
			if _gs.is_game_over():
				break
			await get_tree().create_timer(AI_PLAY_DELAY).timeout
		ai.finish_turn(_tm)
		_refresh_all()
		await get_tree().create_timer(AI_PLAY_DELAY * 0.5).timeout
	if _gs.is_game_over():
		_show_game_over()
		return
	_start_human_turn()

func _show_game_over() -> void:
	_state = InteractionState.GAME_OVER
	# POST to the match-history API before we rebuild the summary UI so
	# stats reflect the moment the winning play landed.
	_post_match_summary()
	# Widen + tall enough for two player cards + button rows. Uses fixed
	# offset (anchored centre) so it works on any viewport size.
	_game_over_panel.offset_left = -230
	_game_over_panel.offset_right = 230
	_game_over_panel.offset_top = -320
	_game_over_panel.offset_bottom = 320
	# Rebuild the panel's content column each time so a rematch (via
	# reload) picks up fresh state, not stale rows from the previous match.
	var vbox := _game_over_panel.get_node_or_null("GameOverMargin/GameOverVBox") as VBoxContainer
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()
	vbox.add_theme_constant_override("separation", 10)
	_build_game_over_content(vbox)
	_game_over_scrim.visible = true
	_game_over_panel.visible = true
	_prompt("Game over.")
	_refresh_all()
	if _sfx != null:
		_sfx.play("game_over")

func _build_game_over_content(vbox: VBoxContainer) -> void:
	var winner_id := _gs.winner()

	# Victory emblem + labels
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/icons/emblem.svg")
	emblem.custom_minimum_size = Vector2(78, 78)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(emblem)

	var vlabel := Label.new()
	vlabel.text = "VICTORY"
	vlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vlabel.add_theme_font_override("font", _chrome_serif_font())
	vlabel.add_theme_font_size_override("font_size", 13)
	vlabel.add_theme_color_override("font_color", CardColors.GOLD)
	vbox.add_child(vlabel)

	var winner_name := _display_name_for(winner_id)
	var vwinner := Label.new()
	vwinner.text = "%s WINS!" % winner_name.to_upper()
	vwinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vwinner.add_theme_font_override("font", _chrome_serif_font())
	vwinner.add_theme_font_size_override("font_size", 32)
	vwinner.add_theme_color_override("font_color", CardColors.PEARL)
	vwinner.add_theme_constant_override("shadow_offset_y", 2)
	vwinner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	vbox.add_child(vwinner)

	var vmeta := Label.new()
	vmeta.text = "%d realms · %d turns · %s" % [
		_gs.players[winner_id].completed_realm_count(),
		_turns_played,
		_format_match_time(),
	]
	vmeta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vmeta.add_theme_font_size_override("font_size", 12)
	vmeta.add_theme_color_override("font_color", CardColors.HAZE)
	vbox.add_child(vmeta)

	# Player cards.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(gap)
	for p in _gs.players:
		vbox.add_child(_build_player_card(p, p.id == winner_id))

	# Buttons.
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(gap2)
	var rematch := Button.new()
	rematch.text = "Rematch"
	rematch.custom_minimum_size = Vector2(0, 48)
	rematch.add_theme_font_size_override("font_size", 15)
	_style_button_as(rematch, "prim")
	rematch.pressed.connect(_on_play_again_pressed)
	vbox.add_child(rematch)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var lb_btn := Button.new()
	lb_btn.text = "Leaderboard"
	lb_btn.custom_minimum_size = Vector2(0, 44)
	lb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_btn.add_theme_font_size_override("font_size", 14)
	_style_button_as(lb_btn, "ghost")
	lb_btn.pressed.connect(_on_leaderboard_pressed)
	row.add_child(lb_btn)

	var mm_btn := Button.new()
	mm_btn.text = "Main menu"
	mm_btn.custom_minimum_size = Vector2(0, 44)
	mm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mm_btn.add_theme_font_size_override("font_size", 14)
	_style_button_as(mm_btn, "ghost")
	mm_btn.pressed.connect(_on_main_menu_pressed)
	row.add_child(mm_btn)

func _build_player_card(player: PlayerState, is_winner: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.114, 0.2, 0.72)
	sb.border_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.6 if is_winner else 0.2)
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
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	if is_winner:
		sb.shadow_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.25)
		sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	# Header: avatar + name + WINNER pill.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	var name_text := _display_name_for(player.id)
	var avatar := Label.new()
	avatar.text = name_text.substr(0, 1).to_upper()
	avatar.custom_minimum_size = Vector2(34, 34)
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_theme_font_size_override("font_size", 14)
	avatar.add_theme_color_override("font_color", Color("0B1D33"))
	var av_sb := StyleBoxFlat.new()
	av_sb.bg_color = Color("6E5AA8") if player.id == HUMAN_ID else Color("7FA8E8")
	av_sb.corner_radius_top_left = 17
	av_sb.corner_radius_top_right = 17
	av_sb.corner_radius_bottom_left = 17
	av_sb.corner_radius_bottom_right = 17
	avatar.add_theme_stylebox_override("normal", av_sb)
	head.add_child(avatar)

	var name_lbl := Label.new()
	name_lbl.text = name_text
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", CardColors.PEARL)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_lbl)

	if is_winner:
		var pill := Label.new()
		pill.text = "WINNER"
		pill.add_theme_font_size_override("font_size", 10)
		pill.add_theme_color_override("font_color", Color("2A1F07"))
		var pill_sb := StyleBoxFlat.new()
		pill_sb.bg_color = CH_GOLD
		pill_sb.corner_radius_top_left = 6
		pill_sb.corner_radius_top_right = 6
		pill_sb.corner_radius_bottom_left = 6
		pill_sb.corner_radius_bottom_right = 6
		pill_sb.content_margin_left = 7
		pill_sb.content_margin_right = 7
		pill_sb.content_margin_top = 3
		pill_sb.content_margin_bottom = 3
		pill.add_theme_stylebox_override("normal", pill_sb)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(pill)

	# 5-stat grid: REALMS, PEARLS, STEALS, TRIBUTES, HIGH RENT.
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	col.add_child(stats)
	var pstats: Dictionary = _match_stats.get(player.id, {"pearls": 0, "steals": 0, "tributes": 0, "highest_rent": 0})
	for spec in [
		{"v": player.completed_realm_count(), "l": "REALMS"},
		{"v": int(pstats.get("pearls", 0)), "l": "PEARLS"},
		{"v": int(pstats.get("steals", 0)), "l": "STEALS"},
		{"v": int(pstats.get("tributes", 0)), "l": "TRIBUTES"},
		{"v": int(pstats.get("highest_rent", 0)), "l": "HIGH RENT"},
	]:
		stats.add_child(_build_stat_cell(spec["v"], spec["l"]))
	return card

func _build_stat_cell(value: int, label: String) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	cell.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	cell.add_child(col)
	var v := Label.new()
	v.text = str(value)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", _chrome_serif_font())
	v.add_theme_font_size_override("font_size", 18)
	v.add_theme_color_override("font_color", CardColors.PEARL)
	col.add_child(v)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", CardColors.HAZE)
	col.add_child(l)
	return cell

func _format_match_time() -> String:
	var elapsed_ms: int = Time.get_ticks_msec() - _match_start_msec
	if _match_start_msec == 0:
		elapsed_ms = 0
	var total_s: int = elapsed_ms / 1000
	var mins: int = total_s / 60
	var secs: int = total_s % 60
	return "%d:%02d" % [mins, secs]

func _on_leaderboard_pressed() -> void:
	_reset_net_session()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScreen.tscn")

# Returns the display name we want to record for a player id. In HvH, the
# local human is the profile name entered in the lobby (NetSession stores
# it); the opponent is OPPONENT_NAME (also from NetSession). In vs-AI mode
# HUMAN falls back to "You" and OPPONENT_NAME defaults to "Coral".
func _display_name_for(player_id: int) -> String:
	if player_id == HUMAN_ID:
		var ns := get_tree().root.get_node_or_null("NetSession")
		if ns != null and "local_name" in ns:
			var nm := String(ns.local_name)
			if not nm.strip_edges().is_empty():
				return nm
		return HUMAN_NAME
	return OPPONENT_NAME

func _post_match_summary() -> void:
	if _gs == null:
		return
	var winner_id := _gs.winner()
	if winner_id < 0:
		return
	# Only real HvH matches with named humans get recorded — vs-AI would
	# pollute the API with "You" vs "Coral" rows the leaderboard filters
	# out anyway. And in HvH, only the host (peer 0) posts so we don't
	# get a duplicate row from the guest applying the same game-over.
	if not _is_online:
		return
	if HUMAN_ID != 0:
		return
	var players_payload: Array = []
	for p in _gs.players:
		var stats: Dictionary = _match_stats.get(p.id, {})
		players_payload.append({
			"name": _display_name_for(p.id),
			"realms": p.completed_realm_count(),
			"steals": int(stats.get("steals", 0)),
			"tributes": int(stats.get("tributes", 0)),
			"highestRent": int(stats.get("highest_rent", 0)),
		})
	var payload := {
		"endedAt": MatchApi.iso_utc_now(),
		"turns": _turns_played,
		"winner": _display_name_for(winner_id),
		"players": players_payload,
	}
	MatchApi.post_match(self, payload)

func _reset_net_session() -> void:
	var ns := get_tree().root.get_node_or_null("NetSession")
	if ns != null and ns.has_method("reset"):
		ns.reset()

func _hide_game_over() -> void:
	if _game_over_panel != null:
		_game_over_panel.visible = false
	if _game_over_scrim != null:
		_game_over_scrim.visible = false

func _on_play_again_pressed() -> void:
	# Reload the GameScreen scene — cleanest way to reset all state including
	# the RNG-driven initial deal.
	get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# --- Human refusal window (hooked by AIOpponent) -------------------------

# Refusal window opened by GameScreen when the HUMAN initiates a refusable
# action. Asks each target (AI or human) whether to refuse; consumes their
# Siren's Refusal card if they do. Mirrors AIOpponent._run_refusal_window so
# defenders get the same fair shot regardless of who attacked.
func _open_refusal_window() -> void:
	var pending: PendingAction = _gs.pending_action
	if pending == null:
		return
	for target_id in pending.targets.duplicate():
		var target: PlayerState = _gs.players[target_id]
		var refusal: CardData = null
		for c in target.hand:
			if c.action_effect == "sirens_refusal":
				refusal = c
				break
		if refusal == null:
			continue
		var wants_refuse := false
		if _ais.has(target_id):
			var ai: AIOpponent = _ais[target_id]
			wants_refuse = ai._wants_to_refuse(_gs, pending, target_id)
		else:
			# Human target (HvH mode, once we get there).
			wants_refuse = await _prompt_human_refusal(target_id, pending)
		if wants_refuse:
			_tm.refuse(target_id, target_id, refusal)

func _prompt_human_refusal(target_id: int, pending: PendingAction) -> bool:
	# Only prompt when the human is the target and actually holds a refusal.
	if target_id != HUMAN_ID:
		return false
	var human: PlayerState = _gs.players[HUMAN_ID]
	var refusal: CardData = null
	for c in human.hand:
		if c.action_effect == "sirens_refusal":
			refusal = c
			break
	if refusal == null:
		return false
	_show_refusal_modal(pending)
	var choice: bool = await _refusal_answered
	_hide_refusal_modal()
	if choice:
		_append_log("[b]You[/b] refused with Siren's Refusal")
	return choice

func _show_refusal_modal(pending: PendingAction) -> void:
	_refusal_title.text = "%s is playing an action on you" % OPPONENT_NAME
	_refusal_body.text = _describe_pending_for_refusal(pending)
	_populate_refusal_cards_row(pending)
	_refusal_scrim.visible = true
	_refusal_panel.visible = true

func _hide_refusal_modal() -> void:
	if _refusal_panel != null:
		_refusal_panel.visible = false
	if _refusal_scrim != null:
		_refusal_scrim.visible = false
	# Free the CardView previews so their textures release — the modal
	# doesn't need to keep them around while it's hidden.
	if _refusal_cards_row != null:
		for child in _refusal_cards_row.get_children():
			child.queue_free()
		_refusal_cards_row.visible = false

# Build the card-art preview row on first use. Sits just below the title.
func _ensure_refusal_cards_row() -> void:
	if _refusal_cards_row != null:
		return
	if _refusal_panel == null:
		return
	var vbox := _refusal_panel.get_node_or_null("RefusalMargin/RefusalVBox") as VBoxContainer
	if vbox == null:
		return
	_refusal_cards_row = HBoxContainer.new()
	_refusal_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_refusal_cards_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_refusal_cards_row)
	var title := vbox.get_node_or_null("RefusalTitle")
	if title != null:
		vbox.move_child(_refusal_cards_row, title.get_index() + 1)

# Populate the preview row with mini CardViews of the exact card(s) or set
# being targeted. Empty for tribute-family actions (no specific card art to
# show — the body text already spells out the amount owed).
func _populate_refusal_cards_row(pending: PendingAction) -> void:
	_ensure_refusal_cards_row()
	if _refusal_cards_row == null:
		return
	for child in _refusal_cards_row.get_children():
		child.queue_free()
	var cards := _refusal_preview_cards(pending)
	_refusal_cards_row.visible = not cards.is_empty()
	if cards.is_empty():
		return
	# Scale each card down to fit inside the modal — CardView.WIDTH/HEIGHT
	# (180×252) is way too big for a dialog. Preserve aspect ratio.
	var mini_w := 96
	var mini_h := int(round(float(mini_w) * float(CardView.HEIGHT) / float(CardView.WIDTH)))
	for c in cards:
		var view := CardView.new()
		view.custom_minimum_size = Vector2(mini_w, mini_h)
		view.card = c
		_refusal_cards_row.add_child(view)

func _refusal_preview_cards(pending: PendingAction) -> Array:
	var out: Array = []
	if pending == null:
		return out
	match pending.kind:
		"krakens_grasp":
			var realm: String = String(pending.payload.get("realm_name", ""))
			var target_id: int = pending.targets[0] if not pending.targets.is_empty() else -1
			if target_id >= 0 and not realm.is_empty():
				var victim: PlayerState = _gs.players[target_id]
				var stack: Array = victim.realms.get(realm, [])
				for c in stack:
					if c is CardData:
						out.append(c)
		"slippery_eel":
			var c: Variant = pending.payload.get("stolen_card")
			if c is CardData:
				out.append(c)
		"trade_winds":
			# their_card = the victim's card being taken; own_card = the
			# attacker's card being handed over. Show victim's card first so
			# the modal reads "losing THIS in exchange for THAT".
			var yours: Variant = pending.payload.get("their_card")
			var theirs: Variant = pending.payload.get("own_card")
			if yours is CardData:
				out.append(yours)
			if theirs is CardData:
				out.append(theirs)
	return out

static func _describe_pending_for_refusal(pending: PendingAction) -> String:
	match pending.kind:
		"krakens_grasp":
			var realm: String = pending.payload.get("realm_name", "your set")
			return "Kraken's Grasp — stealing your %s.\nRefuse?" % realm
		"slippery_eel":
			var card: CardData = pending.payload.get("stolen_card")
			var nm := card.name if card != null else "a card"
			return "Slippery Eel — taking your %s.\nRefuse?" % nm
		"trade_winds":
			# From the initiator's PendingAction: own_card = theirs, their_card = yours.
			var their: CardData = pending.payload.get("own_card")
			var yours: CardData = pending.payload.get("their_card")
			return "Trade Winds — swapping %s for %s.\nRefuse?" % [
				their.name if their else "their card",
				yours.name if yours else "your card",
			]
		"toll_of_the_tides":
			var per: int = int(pending.payload.get("per_target", 5))
			return "Toll of the Tides — pay %d P.\nRefuse?" % per
		"sirens_toll":
			var per: int = int(pending.payload.get("per_target", 5))
			var r: String = pending.payload.get("charger_realm", "a realm")
			return "Siren's Toll on %s — pay %d P.\nRefuse?" % [r, per]
		"mermaids_feast":
			var per: int = int(pending.payload.get("per_target", 2))
			return "Mermaid's Feast — pay %d P.\nRefuse?" % per
		"tribute":
			var per: int = int(pending.payload.get("per_target", 0))
			var r: String = pending.payload.get("charger_realm", "?")
			return "Tribute on %s — pay %d P.\nRefuse?" % [r, per]
	return "Action against you.\nRefuse?"

# --- Rendering -----------------------------------------------------------

func _refresh_all() -> void:
	_refresh_mid_table()
	_opponent_board.refresh()
	_player_board.refresh()
	_refresh_hand()
	_refresh_actions()
	_apply_selection_pulses()
	# Catch a win the moment the winning play lands on any peer — offline
	# used to rely on _reset_to_idle / _after_turn_transition, but in HvH
	# the loser's _apply_play_realm applies the winning card without ever
	# touching those paths, so their game-over dialog never opened.
	if _gs != null and _gs.is_game_over() and _state != InteractionState.GAME_OVER:
		_show_game_over()

# Pop the realm chip(s) on the player's own board that match the currently
# selected realm/wild-realm card in hand. Chips are rebuilt on every board
# refresh so this must run AFTER _player_board.refresh().
func _apply_selection_pulses() -> void:
	if _player_board == null:
		return
	var targets: Array = []
	if _selected_card != null and _state == InteractionState.IDLE:
		match _selected_card.type:
			CardData.Type.REALM:
				targets = [_selected_card.realm]
			CardData.Type.WILD_REALM:
				# Rainbow Conch matches all 10 realms — popping every chip
				# reads as noise rather than guidance, so skip it.
				if not _selected_card.is_rainbow_conch():
					targets = _selected_card.realms
			CardData.Type.TRIBUTE:
				# Highlight the realms this tribute can actually charge from —
				# Siren's Toll (empty realms list) matches any owned chargeable
				# realm; a regular tribute matches only its listed realms.
				var human: PlayerState = _gs.players[HUMAN_ID]
				for r in human.realms.keys():
					if _is_valid_charger_realm(_selected_card, r):
						targets.append(r)
	_player_board.pop_realms(targets)

func _refresh_mid_table() -> void:
	var remaining_plays := 0
	if _state == InteractionState.GAME_OVER:
		_turn_label.text = "GAME OVER"
		_plays_label.text = ""
	elif _gs.current_player_index == HUMAN_ID:
		_turn_label.text = "YOUR TURN"
		remaining_plays = TurnManager.MAX_PLAYS - _tm.plays_this_turn
		_plays_label.text = "%d plays left" % remaining_plays
	else:
		_turn_label.text = ("%s's turn" % OPPONENT_NAME).to_upper()
		remaining_plays = max(0, TurnManager.MAX_PLAYS - _tm.plays_this_turn)
		_plays_label.text = "%d plays left" % remaining_plays
	_refresh_plays_dots(remaining_plays)
	_draw_label.text = "%d" % _gs.draw_pile.size()
	_discard_label.text = "%d" % _gs.discard_pile.size()
	# Top-of-discard: show the actual card art if the top card has one,
	# otherwise fall back to the coloured banner + short-name placeholder.
	# Realms lay on boards (not discard) so the top is usually an action /
	# tribute — the packed art for those is what the player recognises.
	var discard_outline := get_node_or_null("Root/GameCol/MidTable/DiscardPileBox/DiscardOutline")
	if _gs.discard_pile.is_empty():
		_discard_art.texture = null
		_discard_art.visible = false
		_discard_top_banner.visible = false
		_discard_top_label.visible = false
		if discard_outline != null:
			discard_outline.visible = true
	else:
		if discard_outline != null:
			discard_outline.visible = false
		var top: CardData = _gs.discard_pile[_gs.discard_pile.size() - 1]
		var tex := CardView._load_card_art(top.art_path)
		if tex != null:
			_discard_art.texture = tex
			_discard_art.visible = true
			_discard_top_banner.visible = false
			_discard_top_label.visible = false
		else:
			_discard_art.texture = null
			_discard_art.visible = false
			_discard_top_banner.visible = true
			_discard_top_banner.color = CardColors.for_card(top)
			var display := top.name
			if top.type == CardData.Type.ACTION:
				var short := CardView._short_action_name(top.action_effect)
				if not short.is_empty():
					display = short
			_discard_top_label.text = display
			_discard_top_label.visible = true

const _HAND_SELECT_LIFT_PX := 12   # small upward slide when selected
const _HAND_SELECT_PUSH_PX := 18   # sideways slide of neighbours to open a gap
const _HAND_ANIM_TIME := 0.16      # seconds — snappy but visible

func _refresh_hand() -> void:
	var human := _gs.players[HUMAN_ID]
	# Fast path: hand hasn't changed (same cards in same order, same count)
	# — just reflow positions with a tween so selection changes animate
	# instead of hard-cutting to the new layout.
	if _hand_matches_children(human.hand):
		_reflow_hand()
		return
	for child in _hand_row.get_children():
		child.queue_free()
	# Cards overlap by ~72% so the left edge of every card except the rightmost
	# is visible; the Fan button widens that gap temporarily.
	var step_ratio := 0.85 if _hand_fanned else 0.28
	var overlap := int(CardView.WIDTH * step_ratio)
	var lift := CardView.LIFT_PX
	var count := human.hand.size()
	# Set the container's min width so ScrollContainer knows how wide the
	# hand is, and its height to fit the tallest (lifted) card. Extra
	# horizontal room for the sideways push when a card is selected.
	var total_width: int = 0
	if count > 0:
		total_width = (count - 1) * overlap + CardView.WIDTH + 2 * _HAND_SELECT_PUSH_PX
	_hand_row.custom_minimum_size = Vector2(max(CardView.WIDTH, total_width), CardView.HEIGHT + lift)
	# Position each card. Selected/lifted cards need to draw on top of their
	# neighbours, so we defer them to a second pass and add them last.
	var selected_view: CardView = null
	var i := 0
	for c in human.hand:
		var view := CardView.new()
		view.card = c
		var is_lifted := _is_hand_card_lifted(c)
		view.selected_state = is_lifted
		view.selected.connect(_on_hand_card_selected)
		view.drag_started.connect(_on_hand_drag_started)
		view.drag_moved.connect(_on_hand_drag_moved)
		view.drag_ended.connect(_on_hand_drag_ended)
		_hand_row.add_child(view)
		view.position = _hand_card_target(i, is_lifted, _selected_hand_index())
		view.size = Vector2(CardView.WIDTH, CardView.HEIGHT)
		if is_lifted:
			selected_view = view
		i += 1
	# Reorder so the selected card renders on top of everything else — later
	# children draw above earlier ones and receive input first.
	if selected_view != null:
		_hand_row.move_child(selected_view, -1)

func _hand_matches_children(hand: Array) -> bool:
	if _hand_row == null:
		return false
	if _hand_row.get_child_count() != hand.size():
		return false
	for i in range(hand.size()):
		var view := _hand_row.get_child(i) as CardView
		if view == null or view.card != hand[i]:
			return false
	return true

func _is_hand_card_lifted(c: CardData) -> bool:
	if _state == InteractionState.DISCARD:
		return _pending_discards.has(c)
	if _selected_card != null and _selected_card == c:
		return true
	# Ambient highlight: while the opponent is thinking, lift any Siren's
	# Refusal in the local hand so the player knows they can react instantly
	# if an action lands. Purely local — the attacker's mirror doesn't render
	# our hand, so it can't leak the fact that we're holding a Refusal.
	if _state == InteractionState.AI_TURN and c != null and c.action_effect == "sirens_refusal":
		return true
	return false

# Index of the currently-selected card in the human's hand, or -1.
func _selected_hand_index() -> int:
	var human := _gs.players[HUMAN_ID]
	if _state == InteractionState.DISCARD:
		# Discard mode picks multiple cards — no single "selected" to push
		# neighbours around; each lifted card just rises in place.
		return -1
	if _selected_card == null:
		return -1
	return human.hand.find(_selected_card)

# Target position for the card at `index` given whether a card is selected.
# When any card is selected, cards to its left slide left, cards to its
# right slide right, and the selected card itself slides up slightly. The
# stack stays otherwise stacked (no fan spread).
func _hand_card_target(index: int, is_lifted: bool, selected_index: int) -> Vector2:
	var step_ratio := 0.85 if _hand_fanned else 0.28
	var overlap := int(CardView.WIDTH * step_ratio)
	var lift := CardView.LIFT_PX
	var x := index * overlap
	var y := float(lift)
	if selected_index >= 0:
		if index < selected_index:
			x -= _HAND_SELECT_PUSH_PX
		elif index > selected_index:
			x += _HAND_SELECT_PUSH_PX
	if is_lifted:
		y = lift - _HAND_SELECT_LIFT_PX
	return Vector2(x, y)

# Same layout as _refresh_hand but tweens existing children instead of
# rebuilding — used when the underlying hand list hasn't changed (typical
# case for selection / deselection).
func _reflow_hand() -> void:
	var selected_index := _selected_hand_index()
	var lifted_view: CardView = null
	for i in range(_hand_row.get_child_count()):
		var view := _hand_row.get_child(i) as CardView
		if view == null:
			continue
		var is_lifted := _is_hand_card_lifted(view.card)
		view.selected_state = is_lifted
		if is_lifted:
			lifted_view = view
	# Reorder BEFORE tweening so the lifted card is the topmost sibling and
	# renders over its shifted neighbours as the tween runs.
	if lifted_view != null:
		_hand_row.move_child(lifted_view, -1)
	# Post-reorder: iterate again by current index because move_child shifted
	# siblings around.
	for i in range(_hand_row.get_child_count()):
		var view := _hand_row.get_child(i) as CardView
		if view == null:
			continue
		var hand_index := _gs.players[HUMAN_ID].hand.find(view.card)
		if hand_index < 0:
			continue
		var is_lifted := _is_hand_card_lifted(view.card)
		var target := _hand_card_target(hand_index, is_lifted, selected_index)
		var tw := view.create_tween()
		tw.set_parallel(true)
		tw.tween_property(view, "position", target, _HAND_ANIM_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hand_drag_started(card: CardData, gpos: Vector2) -> void:
	# Drag-to-reorder is a local convenience — disallow it during targeting
	# picks and discard multi-select, where it would collide with the picker
	# state or the multi-lift.
	if _state == InteractionState.DISCARD or _state == InteractionState.GAME_OVER:
		return
	if _is_targeting_state():
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	_drag_from_index = human.hand.find(card)
	if _drag_from_index < 0:
		return
	_drag_card = card
	_drag_current_index = _drag_from_index
	for i in range(_hand_row.get_child_count()):
		var v := _hand_row.get_child(i) as CardView
		if v != null and v.card == card:
			_drag_view = v
			# Draw on top of siblings + visually lift so the drag is obvious.
			_hand_row.move_child(v, -1)
			_drag_view.selected_state = true
			# Preserve the pointer-to-card-corner offset so the card doesn't
			# jump under the finger when the drag starts.
			var local: Vector2 = _hand_row.get_global_transform().affine_inverse() * gpos
			_drag_grab_offset = _drag_view.position - local
			break

func _on_hand_drag_moved(card: CardData, gpos: Vector2) -> void:
	if _drag_view == null or _drag_card != card:
		return
	var local: Vector2 = _hand_row.get_global_transform().affine_inverse() * gpos
	_drag_view.position = local + _drag_grab_offset
	var step_ratio := 0.85 if _hand_fanned else 0.28
	var overlap := int(CardView.WIDTH * step_ratio)
	var count: int = _gs.players[HUMAN_ID].hand.size()
	if overlap <= 0 or count <= 0:
		return
	# Snap the drop index off the dragged card's centre X. round() puts the
	# boundary between two slots halfway between their centres — feels right.
	var center_x: float = _drag_view.position.x + float(CardView.WIDTH) * 0.5
	var new_index: int = int(clamp(round((center_x - float(CardView.WIDTH) * 0.5) / float(overlap)), 0, count - 1))
	if new_index != _drag_current_index:
		_drag_current_index = new_index
		_reflow_hand_ghost()

func _reflow_hand_ghost() -> void:
	# Slide siblings into their positions in the hypothetical reorder (drag
	# card removed from `from_i` and inserted at `to_i`). Uses the same tween
	# duration as normal selection reflow so it feels consistent.
	var human: PlayerState = _gs.players[HUMAN_ID]
	var step_ratio := 0.85 if _hand_fanned else 0.28
	var overlap := int(CardView.WIDTH * step_ratio)
	var lift := CardView.LIFT_PX
	var from_i := _drag_from_index
	var to_i := _drag_current_index
	for child in _hand_row.get_children():
		if child == _drag_view:
			continue
		var v := child as CardView
		if v == null:
			continue
		var orig: int = human.hand.find(v.card)
		if orig < 0:
			continue
		var virt := orig
		if from_i < to_i:
			if orig > from_i and orig <= to_i:
				virt = orig - 1
		elif from_i > to_i:
			if orig >= to_i and orig < from_i:
				virt = orig + 1
		var target := Vector2(virt * overlap, float(lift))
		var tw := v.create_tween()
		tw.tween_property(v, "position", target, _HAND_ANIM_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hand_drag_ended(card: CardData, _gpos: Vector2) -> void:
	if _drag_view == null or _drag_card != card:
		_drag_card = null
		_drag_view = null
		_drag_from_index = -1
		_drag_current_index = -1
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	var from_i := _drag_from_index
	var to_i: int = int(clamp(_drag_current_index, 0, human.hand.size() - 1))
	_drag_card = null
	_drag_view = null
	_drag_from_index = -1
	_drag_current_index = -1
	if from_i != to_i and from_i >= 0 and to_i >= 0:
		var moved: CardData = human.hand[from_i]
		human.hand.remove_at(from_i)
		human.hand.insert(to_i, moved)
	# _refresh_hand rebuilds child order when the underlying hand differs
	# from the current children — no-op reorder falls through to _reflow_hand
	# which snaps the dragged view back to its slot.
	_refresh_hand()

func _refresh_actions() -> void:
	if _state == InteractionState.GAME_OVER:
		# Game-over overlay owns the flow — the underlying bar just goes quiet.
		_bank_button.disabled = true
		_play_button.disabled = true
		_end_turn_button.disabled = true
		_end_turn_button.text = "End turn"
		return
	if _state == InteractionState.DISCARD:
		_bank_button.disabled = true
		_play_button.disabled = true
		var need: int = int(_ctx.get("discard_needed", 0))
		_end_turn_button.text = "Discard (%d/%d)" % [_pending_discards.size(), need]
		_end_turn_button.disabled = _pending_discards.size() != need
		return
	var human_turn := _gs.current_player_index == HUMAN_ID
	if not human_turn or _state == InteractionState.AI_TURN:
		_bank_button.disabled = true
		_play_button.disabled = true
		_end_turn_button.disabled = true
		_end_turn_button.text = "End turn"
		return
	# Targeting states (mid-play chip-tap or menu selection) — swap Play for
	# a Cancel affordance so the player can back out without hunting for the
	# menu Cancel or double-tapping the board.
	if _is_targeting_state():
		_bank_button.disabled = true
		_play_button.disabled = false
		_play_button.text = "Cancel action"
		_end_turn_button.disabled = true
		_end_turn_button.text = "End turn"
		return
	_play_button.text = "Play card"
	# Selection-dependent enablement.
	var have_selection := _selected_card != null
	var can_play_turn := _tm.can_play()
	_bank_button.disabled = not (have_selection and can_play_turn and _selected_card.can_bank())
	_play_button.disabled = not (have_selection and _card_is_playable(_selected_card))
	# Block End Turn while a payment is still in flight (opponent settling
	# a tribute / toll / feast against us).
	_end_turn_button.disabled = _awaiting_payment
	_end_turn_button.text = "Waiting for payment…" if _awaiting_payment else "End turn"

func _is_targeting_state() -> bool:
	return _state in [
		InteractionState.SELECT_OWN_REALM,
		InteractionState.SELECT_OWN_COMPLETED_REALM,
		InteractionState.SELECT_OWN_REALM_FOR_CHARGE,
		InteractionState.SELECT_OPP_PLAYER,
		InteractionState.SELECT_OPP_REALM,
		InteractionState.SELECT_OPP_CARD,
		InteractionState.SELECT_OWN_CARD_FOR_TRADE,
		InteractionState.SELECT_OWN_DEST_FOR_STOLEN,
		InteractionState.SELECT_MODIFIER_DEST,
	]

func _card_is_playable(card: CardData) -> bool:
	if not _tm.can_play():
		return false
	match card.type:
		CardData.Type.REALM, CardData.Type.WILD_REALM:
			return true
		CardData.Type.TRIBUTE:
			# Always enabled — the no-matching-realm case pops a "bank it?"
			# confirmation instead of just quietly disabling the button.
			return true
		CardData.Type.ACTION:
			# Refusal is reactive; High Tide is an add-on that only rides a
			# Tribute — neither is playable on its own.
			if card.action_effect in ["sirens_refusal", "high_tide"]:
				return false
			return true
		CardData.Type.PEARL:
			return false
	return false

func _prompt(msg: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = msg

# Brief centred banner flashed on turn changes. Fades in fast, holds, fades
# out — non-blocking so the AI turn can begin underneath it.
func _flash_turn_banner(text: String) -> void:
	if _turn_banner == null:
		return
	_turn_banner.text = text
	_turn_banner.add_theme_font_size_override("font_size", 32)
	_turn_banner.modulate.a = 0.0
	_turn_banner.scale = Vector2.ONE
	_turn_banner.pivot_offset = _turn_banner.size * 0.5
	var tw := create_tween()
	tw.tween_property(_turn_banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.55)
	tw.tween_property(_turn_banner, "modulate:a", 0.0, 0.35)
	if _sfx != null:
		_sfx.play("turn_change")

# Bigger, poppier variant of the turn banner for action-card plays. Scales up
# with an elastic pop, holds long enough to read, then slow-fades out —
# deliberately more attention-grabbing so players can't miss that an action
# landed. Total on-screen time ~3 seconds with a 1-second fade tail.
func _flash_action_banner(action_name: String) -> void:
	if _turn_banner == null:
		return
	_turn_banner.text = action_name
	_turn_banner.add_theme_font_size_override("font_size", 52)
	_turn_banner.modulate.a = 0.0
	# Pivot from the label's own centre so the elastic scale-pop grows
	# from the middle instead of drifting toward the top-left.
	_turn_banner.pivot_offset = _turn_banner.size * 0.5
	_turn_banner.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_turn_banner, "modulate:a", 1.0, 0.22)
	tw.tween_property(_turn_banner, "scale", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	# Hold at full opacity long enough to read (total ~3s including fade).
	tw.tween_interval(1.45)
	# Slow 1-second fade — deliberately gentle so it dissolves rather than
	# snapping away. Very slight scale drift adds a "floating away" feel.
	tw.set_parallel(true)
	tw.tween_property(_turn_banner, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_turn_banner, "scale", Vector2(1.05, 1.05), 1.0)
	if _sfx != null:
		_sfx.play("action")

# Map a raw play_logged verb to a display-ready action title (ALL CAPS with a
# bang), or "" for lines that shouldn't flash (banks, lays, draws, payments,
# refusals — refusals get their own banner earlier in _on_play_logged).
static func _extract_action_flash(text: String) -> String:
	if text.begins_with("played "):
		var tail := text.substr(7)
		# Trim the trailing "on ..." / "on their ..." target clause so the
		# banner is just the card name.
		var cut := tail.find(" on ")
		if cut != -1:
			tail = tail.substr(0, cut)
		return (tail.strip_edges() + "!").to_upper()
	if text.begins_with("attached "):
		var tail2 := text.substr(9)
		var cut2 := tail2.find(" to ")
		if cut2 != -1:
			tail2 = tail2.substr(0, cut2)
		return (tail2.strip_edges() + "!").to_upper()
	if text.find("Ride the Current") != -1:
		return "RIDE THE CURRENT!"
	return ""

# --- Play log ------------------------------------------------------------

func _on_play_logged(actor_id: int, text: String) -> void:
	# Feed the match-stats tracker before the display transforms mangle the
	# text (we rely on the raw resolver-output verbs to bucket steals/tributes).
	_track_play_for_stats(actor_id, text)
	# Text uses "P0"/"P1" placeholders for player references — substitute
	# names for display. Actor gets bolded before the verb.
	var who := HUMAN_NAME if actor_id == HUMAN_ID else OPPONENT_NAME
	var line := text
	# Redact banked-card info when it's the opponent: banks are hidden
	# information, so the pearl value + card name would leak state that the
	# viewer isn't supposed to see. Only reveal your own bank plays.
	if actor_id != HUMAN_ID and text.begins_with("banked "):
		line = "banked a card"
	line = line.replace("P%d" % HUMAN_ID, "you")
	# Substitute the OTHER peer/AI's label. Uses NetSession's opponent name
	# online, OPPONENT_NAME ("Coral") in vs-AI mode.
	line = line.replace("P%d" % (1 - HUMAN_ID), OPPONENT_NAME)
	_append_log("[b]%s[/b] %s" % [who, line])
	# Siren's Refusal is silent by nature — the initiator sees no visible
	# effect from their played card. Flash a centred banner so it's clear
	# something got cancelled instead of just "nothing happened."
	if text.find("Siren's Refusal") != -1:
		var banner_text := "%s REFUSED!" % who.to_upper()
		if text.begins_with("counter-refused"):
			banner_text = "%s COUNTER-REFUSED!" % who.to_upper()
		_flash_turn_banner(banner_text)
	else:
		# Every other action-card play gets a big centred pop so it's obvious
		# what just landed without having to scan the log. Skip realm lays,
		# banks, plain draws, payments, and any refusal follow-ups.
		var action_name := _extract_action_flash(text)
		if not action_name.is_empty():
			_flash_action_banner(action_name)
	# Bucket the log line into an SFX event by looking at the leading verb.
	if _sfx != null:
		if text.begins_with("banked"):
			_sfx.play("card_bank")
		elif text.begins_with("laid"):
			_sfx.play("card_play")
		elif text.begins_with("drew"):
			pass  # draws are noisy — don't fire on every refill
		else:
			_sfx.play("action")

func _append_log(bbcode_line: String) -> void:
	if _log_list == null:
		return
	# One RichTextLabel per entry, added to the log VBox — guarantees each
	# entry sits on its own line (bbcode is used per-entry for bold actor).
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("normal_font_size", 10)
	line.add_theme_color_override("default_color", CardColors.MIST)
	line.text = bbcode_line
	_log_list.add_child(line)
	# Auto-scroll to bottom once layout resolves the new size.
	if _log_scroll != null:
		await get_tree().process_frame
		var vsb := _log_scroll.get_v_scroll_bar()
		if vsb != null:
			_log_scroll.scroll_vertical = int(vsb.max_value)

# --- Hand interactions ---------------------------------------------------

func _on_hand_card_selected(card: CardData) -> void:
	if _gs.current_player_index != HUMAN_ID:
		return
	if _state == InteractionState.DISCARD:
		if _pending_discards.has(card):
			_pending_discards.erase(card)
		else:
			var need: int = int(_ctx.get("discard_needed", 0))
			if _pending_discards.size() < need:
				_pending_discards.append(card)
		_refresh_hand()
		_refresh_actions()
		return
	if _state != InteractionState.IDLE:
		return
	# Tap a different card → select it AND open the detail popup so the
	# player sees the card's name, type and effect before committing.
	# Tapping the same card again after closing the popup deselects it.
	if _selected_card == card and _card_peek.visible:
		# No-op — popup is already open for this card.
		return
	if _selected_card == card:
		_selected_card = null
		_prompt("Tap a card in your hand.")
	else:
		_selected_card = card
		_prompt("Tap Bank it or Play card.")
		if _zoom_enabled:
			_show_card_peek(card)
	_refresh_hand()
	_refresh_actions()
	_apply_selection_pulses()

# --- Bank/Play buttons ---------------------------------------------------

func _on_bank_pressed() -> void:
	# Bottom bar Bank shares the same code as menu-driven bank confirmations.
	_do_bank()

func _on_play_pressed() -> void:
	if _is_targeting_state():
		# Play button doubles as "Cancel action" mid-flow (see _refresh_actions).
		_on_menu_cancel_pressed()
		return
	if _selected_card == null:
		return
	var card := _selected_card
	# Belt-and-suspenders: the button should already be disabled for these,
	# but reject them explicitly so a mis-click never resets the selection.
	if card.type == CardData.Type.PEARL:
		_prompt("Pearls can only be banked.")
		return
	match card.type:
		CardData.Type.REALM, CardData.Type.WILD_REALM:
			_begin_play_realm()
		CardData.Type.TRIBUTE:
			# Tribute chain is a coroutine — await it so the tail
			# (_reset_to_idle) doesn't get orphaned.
			await _begin_play_tribute()
		CardData.Type.ACTION:
			await _begin_play_action(card)
		_:
			_reset_to_idle()

func _on_end_turn_pressed() -> void:
	if _state == InteractionState.GAME_OVER:
		return
	if _state == InteractionState.DISCARD:
		var need: int = int(_ctx.get("discard_needed", 0))
		if _pending_discards.size() == need:
			_finish_discard()
		return
	if _gs.current_player_index == HUMAN_ID and _state == InteractionState.IDLE:
		_end_human_turn()

func _on_menu_cancel_pressed() -> void:
	_hide_menu()
	# Cancelling any target-pick step returns to idle but keeps the card
	# selected so the player can try again.
	_state = InteractionState.IDLE
	_ctx.clear()
	_refresh_actions()
	_prompt("Cancelled.")

# --- Chip taps used for target picking -----------------------------------

func _on_opp_chip_pressed(player_id: int, realm_name: String) -> void:
	if realm_name.is_empty():
		return
	if _state == InteractionState.SELECT_OPP_REALM:
		# Kraken: pick the completed realm they tapped.
		var target_id: int = int(_ctx.get("target_id", -1))
		if target_id < 0:
			return
		var opp: PlayerState = _gs.players[target_id]
		if not opp.is_realm_complete(realm_name):
			_prompt("Kraken can only steal completed sets.")
			return
		_do_kraken(target_id, realm_name)
		return
	if _state == InteractionState.SELECT_OPP_CARD:
		# Eel / Trade Winds — chip tap opens the realm's card peek in picker
		# mode. Enforce the "no complete sets, no empty realms" rule.
		var pick_target: int = int(_ctx.get("eel_target", _ctx.get("trade_target", -1)))
		if player_id != pick_target:
			return
		var opp: PlayerState = _gs.players[player_id]
		if opp.is_realm_complete(realm_name):
			_prompt("Can only take a loose card from an incomplete set.")
			return
		var stack: Array = opp.realms.get(realm_name, [])
		if stack.is_empty():
			return
		var kind: String = _ctx.get("card_pick_kind", "")
		match kind:
			"eel":
				_show_realm_peek(player_id, realm_name, Callable(self, "_eel_stolen_picked"))
			"trade_theirs":
				_show_realm_peek(player_id, realm_name, Callable(self, "_trade_theirs_picked"))
		return
	_show_realm_peek(player_id, realm_name)

func _on_own_chip_pressed(player_id: int, realm_name: String) -> void:
	# Empty realm name = the "+" placeholder chip. Use it as a shortcut for
	# "start a new realm here" when a realm/wild card is selected. Rainbow
	# Conch specifically can start any realm; two-realm wilds start one of
	# their two; plain realm cards start their own realm.
	if realm_name.is_empty():
		if _selected_card == null:
			return
		if _gs.current_player_index != HUMAN_ID:
			return
		if _state != InteractionState.IDLE:
			return
		var t := _selected_card.type
		if t == CardData.Type.REALM or t == CardData.Type.WILD_REALM:
			_begin_play_realm()
		return
	if _state == InteractionState.SELECT_MODIFIER_DEST:
		var dests: Array = _ctx.get("move_mod_dests", [])
		if not dests.has(realm_name):
			return
		var mod: CardData = _ctx.get("move_mod_card")
		var from_r: String = _ctx.get("move_mod_from", "")
		if mod == null or from_r.is_empty():
			_reset_to_idle()
			return
		_do_move_modifier(mod, from_r, realm_name)
		return
	if _state == InteractionState.SELECT_OWN_REALM:
		if not _valid_realms_for(_selected_card).has(realm_name):
			return
		_place_realm(realm_name)
		return
	elif _state == InteractionState.SELECT_OWN_COMPLETED_REALM:
		var human: PlayerState = _gs.players[HUMAN_ID]
		if not human.is_realm_complete(realm_name):
			return
		_apply_modifier(realm_name)
		return
	elif _state == InteractionState.SELECT_OWN_REALM_FOR_CHARGE:
		if not _is_valid_charger_realm(_selected_card, realm_name):
			return
		await _tribute_pick_target(realm_name)
		return
	elif _state == InteractionState.SELECT_OWN_CARD_FOR_TRADE:
		# Trade Winds — pick which of your own loose cards to hand over.
		var me: PlayerState = _gs.players[HUMAN_ID]
		if me.is_realm_complete(realm_name):
			_prompt("Can only give up a loose card from an incomplete set.")
			return
		var stack: Array = me.realms.get(realm_name, [])
		if stack.is_empty():
			return
		_show_realm_peek(HUMAN_ID, realm_name, Callable(self, "_trade_own_picked"))
		return
	_show_realm_peek(player_id, realm_name)

# --- Play flows ----------------------------------------------------------

func _begin_play_realm() -> void:
	if _selected_card == null:
		return
	var candidates := _valid_realms_for(_selected_card)
	if candidates.is_empty():
		_prompt("No legal realm for that card.")
		return
	if candidates.size() == 1:
		_place_realm(candidates[0])
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	var options: Array = []
	for r in candidates:
		# Rainbow Conch (and other wilds) can go into any of several realms —
		# show current progress next to each so the player can pick the set
		# closest to completion at a glance.
		var stack: Array = human.realms.get(r, [])
		var target := Realms.size_of(r)
		var label := "%s (%d/%d)" % [r, stack.size(), target]
		options.append({
			"label": label,
			"realm": r,
			"cb": Callable(self, "_place_realm").bind(r),
		})
	_state = InteractionState.SELECT_OWN_REALM
	_show_menu("Play %s in…" % _selected_card.name, options)

func _place_realm(target_realm: String) -> void:
	_hide_menu()
	var card := _selected_card
	if card == null:
		return
	if _tm.play_realm(card, target_realm):
		_prompt("Played %s in %s." % [card.name, target_realm])
		_broadcast({
			"kind": NetProtocol.KIND_PLAY_REALM,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"realm": target_realm,
		})
	_selected_card = null
	_reset_to_idle()

func _begin_play_action(card: CardData) -> void:
	match card.action_effect:
		"ride_the_current":
			if _tm.play_ride_the_current(card):
				_prompt("Rode the Current — drew 2.")
				_broadcast({
					"kind": NetProtocol.KIND_PLAY_RIDE,
					"actor": HUMAN_ID,
					"card_id": card.id,
				})
			_reset_to_idle()
		"mermaids_feast":
			var pending := _tm.initiate_mermaids_feast(card)
			if pending == null:
				_reset_to_idle()
				return
			if _is_online:
				_broadcast({
					"kind": NetProtocol.KIND_INIT_FEAST,
					"actor": HUMAN_ID,
					"card_id": card.id,
				})
				var result: Variant = await _run_online_refusable_flow()
				if result is Dictionary:
					await _settle_online(result)
					_prompt("Mermaid's Feast settled.")
				else:
					_prompt("Feast refused.")
				_reset_to_idle()
			else:
				await _open_refusal_window()
				var result: Variant = _tm.resolve_pending()
				if result is Dictionary:
					_settle_owed_to_human(result, "Mermaid's Feast")
				_reset_to_idle()
		"toll_of_the_tides":
			await _prompt_opponent_pick("Toll of the Tides — target?", Callable(self, "_do_toll"))
		"krakens_grasp":
			await _prompt_opponent_pick("Kraken's Grasp — target?", Callable(self, "_kraken_pick_realm"))
		"slippery_eel":
			await _prompt_opponent_pick("Slippery Eel — target?", Callable(self, "_eel_pick_card"))
		"trade_winds":
			await _prompt_opponent_pick("Trade Winds — target?", Callable(self, "_trade_pick_their_card"))
		"coral_cottage":
			_begin_cottage()
		"pearl_palace":
			_begin_palace()
		_:
			_reset_to_idle()

func _do_toll(target_id: int) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var card := _selected_card
	var pending := _tm.initiate_toll_of_the_tides(card, target_id)
	if pending == null:
		_reset_to_idle()
		return
	if _is_online:
		_broadcast({
			"kind": NetProtocol.KIND_INIT_TOLL,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"target": target_id,
		})
		var result: Variant = await _run_online_refusable_flow()
		if result is Dictionary:
			await _settle_online(result)
			_prompt("Toll settled.")
		else:
			_prompt("Toll refused.")
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	if result is Dictionary:
		_settle_owed_to_human(result, "Toll of the Tides")
	_reset_to_idle()

func _kraken_pick_realm(target_id: int) -> void:
	_hide_menu()
	var opp: PlayerState = _gs.players[target_id]
	var complete: Array[String] = []
	for r in opp.realms.keys():
		if opp.is_realm_complete(r):
			complete.append(r)
	if complete.is_empty():
		_prompt("%s has no completed sets." % OPPONENT_NAME)
		_reset_to_idle()
		return
	_ctx["target_id"] = target_id
	if complete.size() == 1:
		_do_kraken(target_id, complete[0])
		return
	# Multiple completed sets — the gold border on the opponent's chips marks
	# which are stealable. Player taps the coloured chip directly, no menu.
	_state = InteractionState.SELECT_OPP_REALM
	_prompt("Tap %s's completed set (gold border) to steal it." % OPPONENT_NAME)

func _do_kraken(target_id: int, realm_name: String) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var card := _selected_card
	var pending := _tm.initiate_krakens_grasp(card, target_id, realm_name)
	if pending == null:
		_reset_to_idle()
		return
	if _is_online:
		_broadcast({
			"kind": NetProtocol.KIND_INIT_KRAKEN,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"target": target_id,
			"realm": realm_name,
		})
		var result: Variant = await _run_online_refusable_flow()
		if bool(result):
			_prompt("Stole %s." % realm_name)
		else:
			_prompt("Kraken refused.")
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	if bool(result):
		_prompt("Stole %s." % realm_name)
	else:
		_prompt("Kraken refused.")
	_reset_to_idle()

func _eel_pick_card(target_id: int) -> void:
	_hide_menu()
	var opp: PlayerState = _gs.players[target_id]
	# Enumerate incomplete realms with at least one loose card.
	var stealable_realms: Array[String] = []
	for r in opp.realms.keys():
		if opp.is_realm_complete(r):
			continue
		if (opp.realms[r] as Array).is_empty():
			continue
		stealable_realms.append(r)
	if stealable_realms.is_empty():
		_prompt("No loose card to steal.")
		_reset_to_idle()
		return
	_ctx["eel_target"] = target_id
	_ctx["card_pick_kind"] = "eel"
	# If there's only one candidate set, jump straight to its card picker;
	# otherwise prompt for a chip tap.
	if stealable_realms.size() == 1:
		_show_realm_peek(target_id, stealable_realms[0], Callable(self, "_eel_stolen_picked"))
		_state = InteractionState.SELECT_OPP_CARD
		return
	_state = InteractionState.SELECT_OPP_CARD
	_prompt("Tap %s's incomplete set to see the cards, then tap the one to steal." % OPPONENT_NAME)

func _eel_stolen_picked(card: CardData) -> void:
	var target_id: int = int(_ctx.get("eel_target", -1))
	if target_id < 0 or card == null:
		_reset_to_idle()
		return
	# Rainbow Conch is untouchable — reject with a prompt so the picker feels
	# consistent (also enforced by the resolver).
	if card.is_rainbow_conch():
		_prompt("Rainbow Conch can't be stolen. Pick another card.")
		# Reopen the peek so the player can try again in the same realm.
		var pid: int = int(_ctx.get("peek_player", target_id))
		var realm: String = _ctx.get("peek_realm", "")
		if not realm.is_empty():
			_show_realm_peek(pid, realm, Callable(self, "_eel_stolen_picked"))
		return
	_eel_pick_dest(target_id, card)

func _eel_pick_dest(target_id: int, stolen: CardData) -> void:
	_hide_menu()
	_ctx["eel_target"] = target_id
	_ctx["eel_stolen"] = stolen
	# Plain realm cards have exactly one legal destination (their own realm);
	# skip the redundant "place it in…" menu and land it directly.
	if stolen.type == CardData.Type.REALM:
		await _do_eel(stolen.realm)
		return
	var options := _destination_options_for(stolen, Callable(self, "_do_eel"))
	if options.is_empty():
		_prompt("Nowhere on your board for that card.")
		_reset_to_idle()
		return
	_state = InteractionState.SELECT_OWN_DEST_FOR_STOLEN
	_show_menu("Place %s in your…" % stolen.name, options)

func _do_eel(dest_realm: String) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var target_id: int = int(_ctx.get("eel_target", -1))
	var stolen: CardData = _ctx.get("eel_stolen")
	if target_id < 0 or stolen == null:
		_reset_to_idle()
		return
	var card := _selected_card
	var pending := _tm.initiate_slippery_eel(card, target_id, stolen, dest_realm)
	if pending == null:
		_reset_to_idle()
		return
	if _is_online:
		_broadcast({
			"kind": NetProtocol.KIND_INIT_EEL,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"target": target_id,
			"stolen_id": stolen.id,
			"dest": dest_realm,
		})
		var result: Variant = await _run_online_refusable_flow()
		if bool(result):
			_prompt("Stole %s." % stolen.name)
		else:
			_prompt("Eel refused.")
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	if bool(result):
		_prompt("Stole %s." % stolen.name)
	else:
		_prompt("Eel refused.")
	_reset_to_idle()

func _trade_pick_their_card(target_id: int) -> void:
	_hide_menu()
	_ctx["trade_target"] = target_id
	var opp: PlayerState = _gs.players[target_id]
	var stealable_realms: Array[String] = []
	for r in opp.realms.keys():
		if opp.is_realm_complete(r):
			continue
		if (opp.realms[r] as Array).is_empty():
			continue
		stealable_realms.append(r)
	if stealable_realms.is_empty():
		_prompt("No loose card to take.")
		_reset_to_idle()
		return
	_state = InteractionState.SELECT_OPP_CARD
	_ctx["card_pick_kind"] = "trade_theirs"
	if stealable_realms.size() == 1:
		_show_realm_peek(target_id, stealable_realms[0], Callable(self, "_trade_theirs_picked"))
		return
	_prompt("Tap %s's incomplete set to see the cards, then tap the one you want." % OPPONENT_NAME)

func _trade_theirs_picked(card: CardData) -> void:
	if card == null:
		_reset_to_idle()
		return
	if card.is_rainbow_conch():
		_prompt("Rainbow Conch can't be swapped. Pick another card.")
		var realm: String = _ctx.get("peek_realm", "")
		var pid: int = int(_ctx.get("peek_player", _ctx.get("trade_target", -1)))
		if not realm.is_empty():
			_show_realm_peek(pid, realm, Callable(self, "_trade_theirs_picked"))
		return
	_ctx["trade_their_card"] = card
	# Now pick one of our own loose cards to hand over.
	var human: PlayerState = _gs.players[HUMAN_ID]
	var own_realms: Array[String] = []
	for r in human.realms.keys():
		if human.is_realm_complete(r):
			continue
		if (human.realms[r] as Array).is_empty():
			continue
		own_realms.append(r)
	if own_realms.is_empty():
		_prompt("No loose card of yours to give up.")
		_reset_to_idle()
		return
	_state = InteractionState.SELECT_OWN_CARD_FOR_TRADE
	_ctx["card_pick_kind"] = "trade_own"
	if own_realms.size() == 1:
		_show_realm_peek(HUMAN_ID, own_realms[0], Callable(self, "_trade_own_picked"))
		return
	_prompt("Tap one of your incomplete sets, then tap the card to hand over.")

func _trade_own_picked(card: CardData) -> void:
	if card == null:
		_reset_to_idle()
		return
	if card.is_rainbow_conch():
		_prompt("Rainbow Conch can't be swapped. Pick another card.")
		var realm: String = _ctx.get("peek_realm", "")
		if not realm.is_empty():
			_show_realm_peek(HUMAN_ID, realm, Callable(self, "_trade_own_picked"))
		return
	# _trade_pick_their_dest picks the destination realm on our board for
	# their card. Its first arg (own_realm) is ignored — we only need the card.
	_trade_pick_their_dest("", card)

func _trade_pick_their_dest(_own_realm: String, own_card: CardData) -> void:
	# First destination menu — where THEIR card lands on OUR board.
	_hide_menu()
	_ctx["trade_own_card"] = own_card
	var their_card: CardData = _ctx["trade_their_card"]
	if their_card.type == CardData.Type.REALM:
		# Plain realm — only one legal destination on our board.
		await _trade_pick_own_board_dest(their_card.realm)
		return
	var options := _destination_options_for(their_card, Callable(self, "_trade_pick_own_board_dest"))
	if options.is_empty():
		_prompt("Nowhere on your board for that card.")
		_reset_to_idle()
		return
	_show_menu("Place their card in your…", options)

# Named for clarity: `own_board_dest` = destination on OUR board (resolver's
# own_dest_realm). Fixes an arg-order bug where this used to be named
# their_dest_realm and passed into the wrong resolver slot — the internal
# can-be-assigned-to check then compared each card against the wrong realm
# and silently rejected the trade.
func _trade_pick_own_board_dest(own_board_dest: String) -> void:
	_hide_menu()
	_ctx["trade_own_board_dest"] = own_board_dest
	var opp_id: int = int(_ctx["trade_target"])
	var opp: PlayerState = _gs.players[opp_id]
	var own_card: CardData = _ctx["trade_own_card"]
	var realms: Array = []
	for r in _valid_realms_for(own_card):
		if opp.is_realm_complete(r):
			continue
		realms.append(r)
	if realms.is_empty():
		_prompt("Nowhere on their board for your card.")
		_reset_to_idle()
		return
	# Plain realm — only one landing spot on their board (once we exclude any
	# completed set of the same colour, which the loop above already did).
	if own_card.type == CardData.Type.REALM and realms.size() == 1:
		await _do_trade(realms[0])
		return
	var options: Array = []
	for r in realms:
		options.append({"label": r, "cb": Callable(self, "_do_trade").bind(r)})
	_show_menu("Place your card on their…", options)

# `their_board_dest` = destination on THEIR board (resolver's their_dest_realm).
func _do_trade(their_board_dest: String) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var opp_id: int = int(_ctx["trade_target"])
	var own_card: CardData = _ctx["trade_own_card"]
	var their_card: CardData = _ctx["trade_their_card"]
	var own_board_dest: String = _ctx["trade_own_board_dest"]
	var card := _selected_card
	# Resolver order: (own_card, their_dest_realm, their_card, own_dest_realm)
	var pending := _tm.initiate_trade_winds(card, opp_id,
		own_card, their_board_dest, their_card, own_board_dest)
	if pending == null:
		_reset_to_idle()
		return
	if _is_online:
		_broadcast({
			"kind": NetProtocol.KIND_INIT_TRADE,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"target": opp_id,
			"own_id": own_card.id,
			"their_id": their_card.id,
			"own_dest": own_board_dest,
			"their_dest": their_board_dest,
		})
		var result: Variant = await _run_online_refusable_flow()
		if bool(result):
			_prompt("Traded %s for %s." % [own_card.name, their_card.name])
		else:
			_prompt("Trade refused.")
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	if bool(result):
		_prompt("Traded %s for %s." % [own_card.name, their_card.name])
	else:
		_prompt("Trade refused.")
	_reset_to_idle()

func _begin_cottage() -> void:
	var human: PlayerState = _gs.players[HUMAN_ID]
	var options: Array = []
	for r in human.realms.keys():
		if human.is_realm_complete(r) and not human.has_cottage(r):
			options.append({"label": r, "cb": Callable(self, "_do_cottage").bind(r)})
	if options.is_empty():
		_prompt("No set to attach a Cottage to.")
		_reset_to_idle()
		return
	_state = InteractionState.SELECT_OWN_COMPLETED_REALM
	_ctx["modifier"] = "coral_cottage"
	_show_menu("Coral Cottage — which set?", options)

func _do_cottage(realm: String) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var card := _selected_card
	if _tm.play_coral_cottage(card, realm):
		_prompt("Cottage on %s." % realm)
		_broadcast({
			"kind": NetProtocol.KIND_PLAY_COTTAGE,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"realm": realm,
		})
	_reset_to_idle()

func _begin_palace() -> void:
	var human: PlayerState = _gs.players[HUMAN_ID]
	var options: Array = []
	for r in human.realms.keys():
		if human.is_realm_complete(r) and human.has_cottage(r) and not human.has_palace(r):
			options.append({"label": r, "cb": Callable(self, "_do_palace").bind(r)})
	if options.is_empty():
		_prompt("Pearl Palace needs a Cottage first.")
		_reset_to_idle()
		return
	_state = InteractionState.SELECT_OWN_COMPLETED_REALM
	_ctx["modifier"] = "pearl_palace"
	_show_menu("Pearl Palace — which set?", options)

func _do_palace(realm: String) -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var card := _selected_card
	if _tm.play_pearl_palace(card, realm):
		_prompt("Palace on %s." % realm)
		_broadcast({
			"kind": NetProtocol.KIND_PLAY_PALACE,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"realm": realm,
		})
	_reset_to_idle()

func _apply_modifier(realm_name: String) -> void:
	# Router for chip-tap driven modifier placement.
	var kind: String = _ctx.get("modifier", "")
	if kind == "coral_cottage":
		_do_cottage(realm_name)
	elif kind == "pearl_palace":
		_do_palace(realm_name)

func _begin_play_tribute() -> void:
	if _selected_card == null:
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	var eligible: Array[String] = []
	for r in human.realms.keys():
		if _is_valid_charger_realm(_selected_card, r):
			eligible.append(r)
	if eligible.is_empty():
		# No realm to charge from — offer to bank instead of failing silently.
		var bank_options: Array = [
			{"label": "Bank it (%d P)" % _selected_card.value, "cb": Callable(self, "_do_bank")},
		]
		_show_menu("No matching realm to charge from — bank it?", bank_options)
		return
	if eligible.size() == 1:
		await _tribute_pick_target(eligible[0])
		return
	# Multiple eligible realms — show a colour-coded menu AND accept chip
	# taps. The menu makes the flow obvious (previously chip-only left the
	# player stuck if they missed the prompt), while the chip route stays as
	# a shortcut.
	_state = InteractionState.SELECT_OWN_REALM_FOR_CHARGE
	_prompt("Pick the realm to charge from (menu or tap the chip).")
	var opts: Array = []
	for r in eligible:
		var rent: int = RentCalculator.rent(human, r, false)
		opts.append({"label": "%s — %d P" % [r, rent], "cb": Callable(self, "_tribute_pick_target").bind(r)})
	_show_menu("Charge tribute from your…", opts)

# --- Bank action (button + tribute-no-realm confirmation) ----------------

func _do_bank() -> void:
	_hide_menu()
	if _selected_card == null:
		return
	var card := _selected_card
	if _tm.bank_card(card):
		_prompt("Banked %s." % card.name)
		_broadcast({
			"kind": NetProtocol.KIND_BANK,
			"actor": HUMAN_ID,
			"card_id": card.id,
		})
	_selected_card = null
	_reset_to_idle()

func _is_valid_charger_realm(tribute: CardData, realm_name: String) -> bool:
	var human: PlayerState = _gs.players[HUMAN_ID]
	# A lone Rainbow Conch doesn't count — need at least one actual realm
	# or wild card in the set to charge rent on it.
	if not human.has_chargeable_card_in(realm_name):
		return false
	if tribute.realms.is_empty():
		return true # Siren's Toll — any realm we own
	return tribute.realms.has(realm_name)

func _tribute_pick_target(charger_realm: String) -> void:
	_hide_menu()
	_ctx["tribute_realm"] = charger_realm
	if _selected_card.realms.is_empty():
		# Siren's Toll — needs a chosen target. The lambda awaits the coroutine
		# chain so a paused _do_tribute (e.g. an HvH refusal modal) doesn't
		# leave the tribute in limbo.
		await _prompt_opponent_pick("Siren's Toll — target?",
			func(target_id: int): await _tribute_maybe_high_tide(charger_realm, target_id))
	else:
		await _tribute_maybe_high_tide(charger_realm, -1)

# After realm + optional target are chosen, offer to stack a High Tide onto
# the tribute — but only if the player has one in hand AND has a spare play
# left (High Tide burns an extra play). If either check fails, just charge
# the tribute straight through.
func _tribute_maybe_high_tide(charger_realm: String, target_id: int) -> void:
	var human: PlayerState = _gs.players[HUMAN_ID]
	var high_tide: CardData = null
	for c in human.hand:
		if c.action_effect == "high_tide":
			high_tide = c
			break
	# High Tide is free (rides along with the tribute), so no extra-play
	# check needed — offer it whenever the player holds one.
	if high_tide == null:
		await _do_tribute(charger_realm, target_id, null)
		return
	var base_rent := RentCalculator.rent(human, charger_realm, false)
	var high_tide_rent := RentCalculator.rent(human, charger_realm, true)
	var options: Array = [
		{
			"label": "Charge %d P" % base_rent,
			"cb": Callable(self, "_do_tribute").bind(charger_realm, target_id, null),
		},
		{
			"label": "Charge with High Tide — %d P (free)" % high_tide_rent,
			"cb": Callable(self, "_do_tribute").bind(charger_realm, target_id, high_tide),
		},
	]
	_show_menu("Add High Tide?", options)

func _do_tribute(charger_realm: String, target_id: int = -1, high_tide: CardData = null) -> void:
	_hide_menu()
	if _selected_card == null:
		# Belt-and-suspenders — nothing selected shouldn't reach here, but if
		# it does we must reset state so the UI isn't stuck in
		# SELECT_OWN_REALM_FOR_CHARGE / SELECT_OPP_PLAYER.
		_reset_to_idle()
		return
	var card := _selected_card
	var pending := _tm.initiate_tribute(card, charger_realm, target_id, high_tide)
	if pending == null:
		_reset_to_idle()
		return
	var label := "Tribute (%s)" % charger_realm
	if high_tide != null:
		label += " + High Tide"
	if _is_online:
		_broadcast({
			"kind": NetProtocol.KIND_INIT_TRIBUTE,
			"actor": HUMAN_ID,
			"card_id": card.id,
			"charger_realm": charger_realm,
			"target": target_id,
			"ht_id": high_tide.id if high_tide != null else "",
		})
		var result: Variant = await _run_online_refusable_flow()
		if result is Dictionary:
			await _settle_online(result)
			_prompt("%s settled." % label)
		else:
			_prompt("%s refused." % label)
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	if result is Dictionary:
		_settle_owed_to_human(result, label)
	_reset_to_idle()

# --- Target-picker plumbing ---------------------------------------------

func _prompt_opponent_pick(title: String, cb: Callable) -> void:
	var options: Array = []
	for p in _gs.players:
		if p.id == HUMAN_ID:
			continue
		var display := OPPONENT_NAME if p.id == 1 else ("Opponent %d" % p.id)
		options.append({"label": display, "cb": cb.bind(p.id)})
	if options.size() == 1:
		var only: Dictionary = options[0]
		var only_cb: Callable = only["cb"]
		# await — the callback (Kraken picker, Eel picker, etc.) is a coroutine.
		# A sync call could detach the tail.
		await only_cb.call()
		return
	_state = InteractionState.SELECT_OPP_PLAYER
	_show_menu(title, options)

func _valid_realms_for(card: CardData) -> Array[String]:
	var out: Array[String] = []
	match card.type:
		CardData.Type.REALM:
			out.append(card.realm)
		CardData.Type.WILD_REALM:
			if card.is_rainbow_conch():
				out = Realms.all_realms()
			else:
				out.append_array(card.realms)
	return out

func _destination_options_for(card: CardData, cb: Callable) -> Array:
	var out: Array = []
	for r in _valid_realms_for(card):
		out.append({"label": r, "cb": cb.bind(r)})
	return out

func _settle_owed_to_human(owed: Dictionary, label: String) -> void:
	var receiver: PlayerState = _gs.players[HUMAN_ID]
	var total := 0
	for k in owed.keys():
		var payer_id: int = int(k)
		var amount: int = int(owed[k])
		if amount <= 0:
			continue
		var payer: PlayerState = _gs.players[payer_id]
		# Split pick-selection from application so we can log which cards
		# actually moved. smart_picks flattens realms into one pool and
		# grabs the lowest-value cards first (feedback: previously auto
		# never touched complete sets).
		var picks := PaymentResolver.smart_picks(payer, amount)
		var from_bank: Array[CardData] = picks["bank"]
		var from_realms: Array[CardData] = picks["realms"]
		var paid := PaymentResolver.pay(payer, receiver, amount, from_bank, from_realms)
		_tm.log_payment(payer_id, HUMAN_ID, from_bank, from_realms)
		total += paid
	if total > 0:
		_prompt("%s paid: %d pearls." % [label, total])
	elif owed.is_empty():
		_prompt("%s — no takers." % label)

func _reset_to_idle() -> void:
	_hide_menu()
	_hide_card_peek()
	_selected_card = null
	_state = InteractionState.IDLE
	_ctx.clear()
	if _gs.is_game_over():
		_show_game_over()
		return
	if _tm.can_play():
		_prompt("Tap a card in your hand.")
	else:
		_prompt("No plays left — end your turn.")
	_refresh_all()

# --- Menu plumbing -------------------------------------------------------

func _show_menu(title: String, options: Array) -> void:
	_menu_title.text = title
	for child in _menu_buttons.get_children():
		child.queue_free()
	for opt in options:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(0, 48)
		# Colour-code buttons that reference a realm. Prefer an explicit
		# "realm" key on the option dict (so labels like "Coral Gardens (2/3)"
		# still colour correctly); fall back to matching the label itself
		# for legacy call sites that pass a bare realm name.
		var realm_key: String = String(opt.get("realm", opt["label"]))
		if CardColors.REALM.has(realm_key):
			_style_button_as_realm(b, realm_key)
		var cb: Callable = opt["cb"]
		if cb.is_valid():
			# Await the callable — several menu callbacks are coroutines
			# (_do_tribute, _do_kraken, etc.). Without await, if they pause
			# even briefly, the tail (_reset_to_idle) runs detached and the
			# UI can get stuck in a non-IDLE state.
			b.pressed.connect(func(): await cb.call())
		else:
			b.disabled = true
		_menu_buttons.add_child(b)
	_menu_root.visible = true
	# Ensure the top of the list is visible even if there are many options
	# (Rainbow Conch has 10 target realms — bottom would clip without scroll).
	_menu_scroll.scroll_vertical = 0
	# Splash ripple + subtle nudge so the popup arrives with a sense of impact
	# instead of blinking into place. Uses the same shake used for the "hurry
	# up" nudge, scaled down so it doesn't jolt the whole screen for menu open.
	_splash_menu()
	_nudge_menu()

func _hide_menu() -> void:
	if _menu_root != null:
		_menu_root.visible = false

func _splash_menu() -> void:
	# Ripple concentric arcs from the menu's centre. Attached to Root so the
	# splash renders in the overlay layer above gameplay but under nothing that
	# blocks input (the SplashEffect Control ignores mouse itself).
	if _menu_root == null:
		return
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	var rect := _menu_root.get_global_rect()
	SplashEffect.spawn_at(root, rect.get_center())

func _nudge_menu() -> void:
	# Tiny 3-frame elastic wiggle on the menu itself — same "vibe" as the
	# opponent-nudge shake but tightly localised so it doesn't move the whole
	# playfield when the menu is just opening.
	if _menu_root == null:
		return
	var origin := _menu_root.position
	var tw := create_tween()
	tw.tween_property(_menu_root, "position", origin + Vector2(0, -6), 0.06) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_menu_root, "position", origin + Vector2(0, 3), 0.08) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_menu_root, "position", origin, 0.14) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# Paint a menu button in the realm's chip colour so realm-name buttons match
# the coloured chips on the boards.
func _style_button_as_realm(b: Button, realm_name: String) -> void:
	var bg: Color = CardColors.REALM.get(realm_name, CardColors.PANEL_EDGE)
	var hover_bg := bg.lightened(0.10)
	var pressed_bg := bg.darkened(0.15)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state_name:
			"hover":  sb.bg_color = hover_bg
			"pressed": sb.bg_color = pressed_bg
			_: sb.bg_color = bg
		sb.border_color = CardColors.PANEL_EDGE
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state_name, sb)
	b.add_theme_color_override("font_color", CardColors.text_on(bg))
	b.add_theme_color_override("font_hover_color", CardColors.text_on(bg))
	b.add_theme_color_override("font_pressed_color", CardColors.text_on(bg))

# --- Realm peek overlay --------------------------------------------------

# Popup that shows the full card faces in one realm on tap. Two modes:
#   * informational (default) — read-only, plus a wild-shift affordance on
#     your own realms.
#   * picker (pick_cb set) — every card tap fires the callback with the card;
#     used by Slippery Eel and Trade Winds to let the player pick a specific
#     card visually rather than from a text menu.
func _on_bank_view_requested(player_id: int) -> void:
	# Opponent banks are hidden info — tap on their pearl total shouldn't
	# reveal their cards.
	if player_id != HUMAN_ID:
		_prompt("Opponent bank is hidden.")
		return
	_show_bank_peek(player_id)

func _on_payment_applied(payer_id: int, receiver_id: int, total: int, card_count: int) -> void:
	_track_payment_for_stats(payer_id, receiver_id, total, card_count)
	# Fly a small burst of pearl icons from the payer's board area to the
	# receiver's bank pill. Capped so a 6-card settle doesn't spawn 6 sprites.
	var count: int = clamp(card_count, 1, 6)
	var src := _board_center(payer_id)
	var dst := _bank_pill_center(receiver_id)
	if src == Vector2.ZERO or dst == Vector2.ZERO:
		return
	for i in range(count):
		var pearl := Panel.new()
		pearl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pearl.custom_minimum_size = Vector2(16, 16)
		pearl.size = Vector2(16, 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = CardColors.PEARL
		sb.border_color = CardColors.GOLD
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 4
		pearl.add_theme_stylebox_override("panel", sb)
		var jitter := Vector2(randf_range(-12, 12), randf_range(-8, 8))
		pearl.position = src + jitter - Vector2(8, 8)
		add_child(pearl)
		var stagger: float = 0.05 * float(i)
		var tw := create_tween()
		tw.tween_interval(stagger)
		tw.tween_property(pearl, "position", dst - Vector2(8, 8), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(pearl, "scale", Vector2(0.3, 0.3), 0.15)
		tw.tween_callback(pearl.queue_free)

# Screen-space centre of the given player's board strip.
func _board_center(player_id: int) -> Vector2:
	var board: Control = _player_board if player_id == HUMAN_ID else _opponent_board
	if board == null:
		return Vector2.ZERO
	var rect := board.get_global_rect()
	return get_global_transform().affine_inverse() * (rect.position + rect.size * 0.5)

# Screen-space centre of the given player's bank pill (the "P" icon).
func _bank_pill_center(player_id: int) -> Vector2:
	var board: PlayerBoardView = _player_board if player_id == HUMAN_ID else _opponent_board
	if board == null:
		return Vector2.ZERO
	var pill := board.get_node_or_null("HBoxContainer") as Control
	if pill == null:
		# Fall back to board centre.
		return _board_center(player_id)
	var rect := board.get_global_rect()
	# Bank pill sits at the right side of the header row — biased right.
	return get_global_transform().affine_inverse() * (rect.position + Vector2(rect.size.x * 0.75, rect.size.y * 0.25))

func _on_discard_pile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_show_discard_peek()

# Peek modal showing the full discard pile — most recent card first so it
# reads as a play history. Purely informational, no picker mode.
func _show_discard_peek() -> void:
	var count := _gs.discard_pile.size()
	_peek_title.text = "Discard pile"
	_peek_subtitle.text = "%d card%s discarded" % [count, "" if count == 1 else "s"]
	_ctx.erase("peek_pick_cb")
	_ctx["peek_player"] = -1
	_ctx["peek_realm"] = ""
	for child in _peek_row.get_children():
		child.queue_free()
	if count == 0:
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", CardColors.HAZE)
		_peek_row.add_child(empty)
	else:
		# Reverse so the most-recently discarded card sits leftmost —
		# players scan the "top of pile" first.
		for i in range(count - 1, -1, -1):
			var view := CardView.new()
			view.card = _gs.discard_pile[i]
			_peek_row.add_child(view)
	_peek_close.text = "Close"
	_peek_confirm.visible = false
	_ctx.erase("pay_pending")
	_peek_prev.visible = false
	_peek_next.visible = false
	_peek_root.visible = true

func _show_bank_peek(player_id: int) -> void:
	var player: PlayerState = _gs.players[player_id]
	_peek_title.text = "Your bank"
	var total := player.total_bank_value()
	var count := player.bank.size()
	_peek_subtitle.text = "%d pearls · %d card%s" % [
		total, count, "" if count == 1 else "s"
	]
	# Not a picker — pure inspection. Clear any lingering picker context.
	_ctx.erase("peek_pick_cb")
	_ctx["peek_player"] = player_id
	_ctx["peek_realm"] = ""
	for child in _peek_row.get_children():
		child.queue_free()
	if count == 0:
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", CardColors.HAZE)
		_peek_row.add_child(empty)
	else:
		var sorted := player.bank.duplicate()
		sorted.sort_custom(func(a, b): return a.value < b.value)
		for c in sorted:
			var view := CardView.new()
			view.card = c
			_peek_row.add_child(view)
	_peek_close.text = "Close"
	_peek_confirm.visible = false
	_ctx.erase("pay_pending")
	_peek_prev.visible = false
	_peek_next.visible = false
	_peek_root.visible = true

func _show_realm_peek(player_id: int, realm_name: String, pick_cb: Callable = Callable()) -> void:
	var player: PlayerState = _gs.players[player_id]
	var stack: Array = player.realms.get(realm_name, [])
	_peek_title.text = realm_name
	var who := HUMAN_NAME if player_id == HUMAN_ID else OPPONENT_NAME
	var count := stack.size()
	var target := Realms.size_of(realm_name)
	var complete := player.is_realm_complete(realm_name)
	var badge := " · complete" if complete else ""
	_peek_subtitle.text = "%s · %d/%d%s" % [who, count, target, badge]
	# Modifier suffix — cottage/palace add real rent, worth calling out.
	var mods := player.modifiers_on(realm_name)
	if not mods.is_empty():
		var mod_names: Array[String] = []
		for m in mods:
			mod_names.append(_modifier_display_name(m))
		_peek_subtitle.text += " · " + " + ".join(mod_names)
	# Picker mode wins over wild-shift hint if both would apply.
	if pick_cb.is_valid():
		_peek_subtitle.text += "\nTap a card to choose it."
	elif player_id == HUMAN_ID \
			and _gs.current_player_index == HUMAN_ID \
			and _state == InteractionState.IDLE \
			and _stack_has_shiftable_wild(stack, realm_name):
		_peek_subtitle.text += "\nTap a wild to move it (free)."

	# Stash context so the tap handler knows which realm/player we're peeking,
	# and (if picker) the callback to invoke.
	_ctx["peek_player"] = player_id
	_ctx["peek_realm"] = realm_name
	if pick_cb.is_valid():
		_ctx["peek_pick_cb"] = pick_cb
	else:
		_ctx.erase("peek_pick_cb")

	for child in _peek_row.get_children():
		child.queue_free()
	for c in stack:
		var view := CardView.new()
		view.card = c
		view.selected.connect(_on_peek_card_selected)
		_peek_row.add_child(view)
	# Modifier row below the realm cards — only shown for the human's own
	# realm (opponent's modifiers stay in the subtitle line only) and only
	# outside of picker mode (picker only cares about the realm stack).
	_populate_peek_modifier_row(player, realm_name, pick_cb.is_valid())
	# Always just "Close" — even in picker mode. Closing the peek returns
	# to the chip-picking state so you can browse other realms without
	# aborting the action. Real cancel is the "Cancel action" button in
	# the actions row (which lives on the Play slot during targeting).
	_peek_close.text = "Close"
	_peek_confirm.visible = false
	_ctx.erase("pay_pending")
	# Prev/next only make sense for realm peeks — enable when the peeked
	# player has more than one in-play realm to cycle through.
	var cyclable := _peek_cyclable_realms(player)
	var can_cycle := cyclable.size() > 1
	_peek_prev.visible = can_cycle
	_peek_next.visible = can_cycle
	_peek_root.visible = true

func _hide_peek() -> void:
	if _peek_root != null:
		_peek_root.visible = false
	if _peek_confirm != null:
		_peek_confirm.visible = false
	if _peek_divider != null:
		_peek_divider.visible = false
	if _peek_modifiers_row != null:
		_peek_modifiers_row.visible = false
		for child in _peek_modifiers_row.get_children():
			child.queue_free()
	_ctx.erase("peek_player")
	_ctx.erase("peek_realm")

# Lazy-build a divider + modifier row inside the PeekVBox, positioned
# just above the actions row. Idempotent — reuses the nodes on repeat
# calls, only their children get rebuilt per open.
func _ensure_peek_modifier_row() -> void:
	if _peek_divider != null and _peek_modifiers_row != null:
		return
	var vbox := _peek_root.get_node_or_null("PeekMargin/PeekVBox") as VBoxContainer
	if vbox == null:
		return
	var actions := vbox.get_node_or_null("PeekActions")
	var actions_idx := actions.get_index() if actions != null else vbox.get_child_count()
	_peek_divider = ColorRect.new()
	_peek_divider.custom_minimum_size = Vector2(0, 1)
	_peek_divider.color = Color(CardColors.GOLD.r, CardColors.GOLD.g, CardColors.GOLD.b, 0.25)
	vbox.add_child(_peek_divider)
	vbox.move_child(_peek_divider, actions_idx)
	_peek_modifiers_row = HBoxContainer.new()
	_peek_modifiers_row.add_theme_constant_override("separation", 6)
	_peek_modifiers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_peek_modifiers_row)
	vbox.move_child(_peek_modifiers_row, actions_idx + 1)

func _populate_peek_modifier_row(player: PlayerState, realm_name: String, in_picker_mode: bool) -> void:
	_ensure_peek_modifier_row()
	if _peek_modifiers_row == null:
		return
	for child in _peek_modifiers_row.get_children():
		child.queue_free()
	var mods := player.modifiers_on(realm_name)
	var owns_realm := player.id == HUMAN_ID
	var human_turn := _gs.current_player_index == HUMAN_ID
	var show := not in_picker_mode and not mods.is_empty()
	_peek_divider.visible = show
	_peek_modifiers_row.visible = show
	if not show:
		return
	for m in mods:
		var view := CardView.new()
		view.card = m
		# Tapping is only meaningful on your own realms during your turn —
		# opponent modifiers are shown for information only.
		if owns_realm and human_turn:
			view.selected.connect(_on_peek_modifier_selected.bind(m, realm_name))
		_peek_modifiers_row.add_child(view)

# Peek-modal close button. In picker mode (Eel / Trade Winds mid-flow) closing
# the peek used to strand the player in a non-IDLE state — now it cancels the
# whole action so they can pick a different card or bank instead. Payment mode
# treats Close as "auto-pay" (fall back to smart selection).
func _peek_cyclable_realms(player: PlayerState) -> Array[String]:
	# In-play realms (any card laid). Skips empty realms so the cycle
	# doesn't land on nothing.
	var out: Array[String] = []
	for r in player.realms.keys():
		var stack: Array = player.realms[r]
		if not stack.is_empty():
			out.append(r)
	return out

func _cycle_realm_peek(delta: int) -> void:
	# Cycle to the next/previous realm on the currently-peeked player.
	# Keeps peek_pick_cb intact so Eel/Trade browsing survives the flip.
	var player_id: int = int(_ctx.get("peek_player", -1))
	var current_realm: String = String(_ctx.get("peek_realm", ""))
	if player_id < 0 or current_realm.is_empty():
		return
	var player: PlayerState = _gs.players[player_id]
	var cyclable := _peek_cyclable_realms(player)
	if cyclable.size() < 2:
		return
	var idx := cyclable.find(current_realm)
	if idx < 0:
		idx = 0
	var next_idx := (idx + delta) % cyclable.size()
	if next_idx < 0:
		next_idx += cyclable.size()
	var next_realm: String = cyclable[next_idx]
	var cb_var: Variant = _ctx.get("peek_pick_cb", Callable())
	var cb: Callable = cb_var if cb_var is Callable else Callable()
	_show_realm_peek(player_id, next_realm, cb)

func _on_peek_close_pressed() -> void:
	var was_pay_picker: bool = _ctx.has("pay_pending")
	if was_pay_picker:
		_ctx.erase("pay_pending")
		_hide_peek()
		_payment_answered.emit(null)
		return
	# For an action picker (Eel/Trade browsing), Close just hides the peek —
	# the picker callback stays live so tapping another chip opens the next
	# realm. Full cancel is the "Cancel action" button in the actions row.
	_hide_peek()

func _stack_has_shiftable_wild(stack: Array, current_realm: String) -> bool:
	for c in stack:
		if c.type != CardData.Type.WILD_REALM:
			continue
		# Rainbow Conch has all 10 in its realms list; two-realm wilds have 2.
		# Either way, if there's any legal target other than the current one,
		# it's shiftable.
		for r in c.realms:
			if r != current_realm:
				return true
	return false

func _on_peek_card_selected(card: CardData) -> void:
	# Payment picker mode: taps toggle each card's selection; the running total
	# is shown in the subtitle and the Confirm button enables once we've
	# selected enough to cover the remaining debt.
	if _ctx.has("pay_pending"):
		_toggle_pay_pick(card)
		return
	# Picker mode: a targeting flow (Eel / Trade) opened the peek to let the
	# player pick a specific card. Fire its callback and dismiss.
	var pick_cb_var: Variant = _ctx.get("peek_pick_cb")
	if pick_cb_var is Callable and (pick_cb_var as Callable).is_valid():
		var cb: Callable = pick_cb_var
		# Clear the picker context BEFORE hiding — otherwise _on_peek_close_pressed
		# could later see a stale peek_pick_cb and mistakenly cancel a follow-up
		# informational peek.
		_ctx.erase("peek_pick_cb")
		_hide_peek()
		cb.call(card)
		return
	# Informational mode: on your own realm, tapping a wild opens a move menu.
	var pid: int = int(_ctx.get("peek_player", -1))
	var realm: String = _ctx.get("peek_realm", "")
	if pid != HUMAN_ID or _gs.current_player_index != HUMAN_ID:
		return
	if _state != InteractionState.IDLE:
		return
	if card == null or card.type != CardData.Type.WILD_REALM:
		return
	var candidates: Array[String] = []
	for r in card.realms:
		if r != realm:
			candidates.append(r)
	if candidates.is_empty():
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	var options: Array = []
	for r in candidates:
		# Match the play-realm menu — show current N/M so you can spot the
		# set closest to completion when shifting a wild between realms.
		var stack: Array = human.realms.get(r, [])
		var target := Realms.size_of(r)
		var label := "%s (%d/%d)" % [r, stack.size(), target]
		options.append({
			"label": label,
			"realm": r,
			"cb": Callable(self, "_do_wild_shift").bind(card, realm, r),
		})
	# Close the peek before showing the destination menu so overlays don't
	# stack weirdly; we'll reopen the peek on the destination after the move.
	_hide_peek()
	_show_menu("Move %s to…" % card.name, options)

func _do_wild_shift(card: CardData, from_realm: String, to_realm: String) -> void:
	_hide_menu()
	var human: PlayerState = _gs.players[HUMAN_ID]
	human.reassign_wild(card, from_realm, to_realm)
	_prompt("%s moved from %s to %s." % [card.name, from_realm, to_realm])
	_broadcast({
		"kind": NetProtocol.KIND_REASSIGN_WILD,
		"actor": HUMAN_ID,
		"card_id": card.id,
		"from": from_realm,
		"to": to_realm,
	})
	# State stays IDLE — reassigning a wild is free. Refresh boards, then
	# reopen the peek on the destination so the player sees where it landed.
	_refresh_all()
	_show_realm_peek(HUMAN_ID, to_realm)

static func _modifier_display_name(m: CardData) -> String:
	match m.action_effect:
		"coral_cottage": return "Coral Cottage"
		"pearl_palace": return "Pearl Palace"
	return m.name

# Tap on a Coral Cottage / Pearl Palace card inside the realm-peek modifier
# row. Closes the peek and enters SELECT_MODIFIER_DEST, popping the chips
# of every legal destination realm on the local player's board.
func _on_peek_modifier_selected(_card: CardData, mod: CardData, from_realm: String) -> void:
	if _gs.current_player_index != HUMAN_ID:
		return
	_hide_peek()
	var human: PlayerState = _gs.players[HUMAN_ID]
	var destinations: Array[String] = []
	for r in human.realms.keys():
		if r == from_realm:
			continue
		if not human.is_realm_complete(r):
			continue
		if mod.action_effect == "coral_cottage" and human.has_cottage(r):
			continue
		if mod.action_effect == "pearl_palace":
			# Palace can only move onto a set that already has a Coral Cottage
			# and doesn't already have another Palace on it.
			if not human.has_cottage(r):
				continue
			if human.has_palace(r):
				continue
		destinations.append(r)
	if destinations.is_empty():
		_prompt("Nowhere to move %s." % _modifier_display_name(mod))
		return
	_ctx["move_mod_card"] = mod
	_ctx["move_mod_from"] = from_realm
	_ctx["move_mod_dests"] = destinations
	_state = InteractionState.SELECT_MODIFIER_DEST
	_player_board.pop_realms(destinations)
	_refresh_actions()
	_prompt("Tap a highlighted realm chip to move %s." % _modifier_display_name(mod))

func _do_move_modifier(mod: CardData, from_realm: String, to_realm: String) -> void:
	var human: PlayerState = _gs.players[HUMAN_ID]
	if not human.move_modifier(mod, from_realm, to_realm):
		_prompt("Can't move %s there." % _modifier_display_name(mod))
		_reset_to_idle()
		return
	_prompt("Moved %s from %s to %s." % [_modifier_display_name(mod), from_realm, to_realm])
	_broadcast({
		"kind": NetProtocol.KIND_MOVE_MODIFIER,
		"actor": HUMAN_ID,
		"card_id": mod.id,
		"from": from_realm,
		"to": to_realm,
	})
	_refresh_all()
	_reset_to_idle()

# --- Human-payment picker -------------------------------------------------
#
# When an AI-driven tribute/toll/feast charges the human, this hook lets the
# player choose which realm cards to spend once their bank can't cover the
# debt. Falls back to the AI's smart auto-pay when the bank alone suffices
# or when the picker is dismissed via Close.

func _prompt_human_payment(payer: PlayerState, receiver: PlayerState, amount: int) -> Variant:
	if payer == null or payer.id != HUMAN_ID:
		return null
	# In HvH, ALWAYS make the human pick their own cards — no silent bank
	# auto-drain even when the bank alone would cover the debt. In offline
	# vs-AI mode, keep the shortcut when the bank covers so the human isn't
	# forced through a picker for every trivial 2 P Feast.
	if not _is_online:
		var bank_total := payer.total_bank_value()
		if bank_total >= amount:
			return null
	var picks_dict: Variant = await _open_pay_picker(payer, receiver, amount)
	if picks_dict == null:
		return null
	return picks_dict

# Repurpose the RealmPeek modal as a card-selection UI. Enforces the "bank
# first" rule: while the bank has any pearls, only bank cards are pickable
# — you can't pay with a realm card unless the bank is empty (or can't
# cover the debt, in which case all bank cards get auto-included and the
# picker shows realm cards for the shortfall).
# Returns {"bank": Array[CardData], "realms": Array[CardData]} on confirm,
# or null if the user hit Auto / Cancel.
func _open_pay_picker(payer: PlayerState, receiver: PlayerState, amount: int) -> Variant:
	var who := OPPONENT_NAME if receiver.id != HUMAN_ID else "yourself"
	_peek_title.text = "Pay %d P to %s" % [amount, who]
	var bank_cards: Array[CardData] = []
	for c in payer.bank:
		if c.value > 0:
			bank_cards.append(c)
	var realm_cards: Array[CardData] = []
	for r in payer.realms.keys():
		var stack: Array = payer.realms[r]
		for c in stack:
			# Zero-value cards (Rainbow Conch) can't pay a debt.
			if c.value > 0:
				realm_cards.append(c)
	bank_cards.sort_custom(func(a, b): return a.value < b.value)
	realm_cards.sort_custom(func(a, b): return a.value < b.value)

	# Mode selection: bank-first rule.
	var bank_total := 0
	for c in bank_cards:
		bank_total += c.value
	var forced_bank: Array[CardData] = []
	var visible_cards: Array[CardData] = []
	if bank_total >= amount:
		# Bank covers the debt on its own — player picks which pearls to
		# spend. Realm cards stay off-limits.
		visible_cards = bank_cards
		_peek_subtitle.text = "Pick bank cards summing to at least %d P." % amount
	else:
		# Bank can't cover — auto-drain it and let the player pick realm
		# cards to cover the shortfall.
		forced_bank = bank_cards.duplicate()
		visible_cards = realm_cards
		var shortfall := amount - bank_total
		_peek_subtitle.text = "Bank (%d P) is auto-drained. Pick realm cards for %d P more." % [bank_total, shortfall]

	_ctx["pay_pending"] = {
		"amount": amount,
		"picks": [] as Array[CardData],
		"bank_ids": _card_ids_set(bank_cards),
		"forced_bank": forced_bank,
	}
	_ctx.erase("peek_pick_cb")
	_ctx.erase("peek_player")
	_ctx.erase("peek_realm")
	for child in _peek_row.get_children():
		child.queue_free()
	for c in visible_cards:
		var view := CardView.new()
		view.card = c
		view.selected.connect(_on_peek_card_selected)
		_peek_row.add_child(view)
	_peek_confirm.text = "Confirm (0 P)"
	_peek_confirm.disabled = true
	_peek_confirm.visible = true
	# Payment is never cancellable — the debt must be paid. The close button
	# always reads "Auto" and falls back to smart_picks (bank first, then
	# lowest-value realm cards) so a mis-tap still settles.
	_peek_close.text = "Auto"
	_peek_prev.visible = false
	_peek_next.visible = false
	_peek_root.visible = true
	var answer: Variant = await _payment_answered
	return answer

# Helper: build a Dictionary-as-set of card ids for O(1) `in`-checks when
# partitioning picks back into bank vs realm buckets at confirm-time.
static func _card_ids_set(cards: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in cards:
		if c is CardData:
			out[(c as CardData).id] = true
	return out

func _toggle_pay_pick(card: CardData) -> void:
	var pending: Dictionary = _ctx.get("pay_pending", {})
	if pending.is_empty():
		return
	var picks: Array[CardData] = pending.get("picks", [] as Array[CardData])
	if picks.has(card):
		picks.erase(card)
	else:
		picks.append(card)
	pending["picks"] = picks
	_ctx["pay_pending"] = pending
	# Reflect selection state on the matching CardView so the border switches
	# to the "selected" style.
	for child in _peek_row.get_children():
		if child is CardView and (child as CardView).card == card:
			(child as CardView).selected_state = picks.has(card)
	var selected_sum := 0
	for c in picks:
		selected_sum += c.value
	# Forced-bank total is added to picks-sum in realm mode (auto-drained
	# bank cards count toward covering the debt).
	var forced_bank: Array = pending.get("forced_bank", [])
	var forced_sum := 0
	for c in forced_bank:
		if c is CardData:
			forced_sum += (c as CardData).value
	var amount: int = int(pending.get("amount", 0))
	var effective := selected_sum + forced_sum
	_peek_confirm.text = "Confirm (%d P)" % effective
	_peek_confirm.disabled = effective < amount

func _on_peek_confirm_pressed() -> void:
	var pending: Dictionary = _ctx.get("pay_pending", {})
	if pending.is_empty():
		return
	var picks: Array[CardData] = pending.get("picks", [] as Array[CardData])
	var bank_ids_set: Dictionary = pending.get("bank_ids", {})
	# Auto-drained bank cards (only populated when bank alone couldn't cover
	# the debt — the picker showed realms then).
	var forced_bank_raw: Array = pending.get("forced_bank", [])
	var from_bank: Array[CardData] = []
	var from_realms: Array[CardData] = []
	for c in forced_bank_raw:
		if c is CardData:
			from_bank.append(c)
	# Partition user picks by which pool each card originated from.
	for c in picks:
		if bank_ids_set.has(c.id):
			from_bank.append(c)
		else:
			from_realms.append(c)
	_ctx.erase("pay_pending")
	_hide_peek()
	_payment_answered.emit({"bank": from_bank, "realms": from_realms})

# --- Card peek (tap-a-card in hand for details) --------------------------
#
# Layout mirrors the card anatomy in docs/sirens-bargain-card-designs.svg:
#   [ colour banner + name ]
#   [ art window — text description for now, real art later ]
#   [ info box — rent tiers or "N pearls to bank" ]
#   [ Bank | Play | Close ]
#
# A full-screen semi-transparent scrim sits behind the panel so taps outside
# the card dismiss the popup and so bottom-bar buttons can't be poked through.

func _style_card_peek() -> void:
	# Card frame — gold hairline, deep-ink fill, rounded 10.
	var frame := StyleBoxFlat.new()
	frame.bg_color = CardColors.INK
	frame.border_color = CardColors.GOLD
	frame.border_width_left = 1
	frame.border_width_right = 1
	frame.border_width_top = 1
	frame.border_width_bottom = 1
	frame.corner_radius_top_left = 10
	frame.corner_radius_top_right = 10
	frame.corner_radius_bottom_left = 10
	frame.corner_radius_bottom_right = 10
	_card_peek.add_theme_stylebox_override("panel", frame)
	# Inner panels (body + info) — subtle darker fill with hairline edge.
	_apply_inner_panel_style(_card_peek_body)
	_apply_inner_panel_style(_card_peek_info)
	# Full-face art node — sits AS the card in the popup (not inside the info
	# body). Fills the space above the button row; the placeholder banner /
	# body / info panels only show when the card has no art asset.
	_card_peek_art = TextureRect.new()
	_card_peek_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_peek_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_peek_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_peek_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_peek_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_peek_art.visible = false
	var vbox := _card_peek_banner.get_parent()
	vbox.add_child(_card_peek_art)
	# Move it to the top so it sits above the placeholder + actions row.
	vbox.move_child(_card_peek_art, 0)

func _apply_inner_panel_style(p: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardColors.PANEL
	sb.border_color = CardColors.PANEL_EDGE
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", sb)

func _show_card_peek(card: CardData) -> void:
	if card == null:
		return
	_card_peek_card = card

	# Banner: coloured strip keyed to the card's realm/type; dark text.
	var banner_color := CardColors.for_card(card)
	var banner_sb := StyleBoxFlat.new()
	banner_sb.bg_color = banner_color
	banner_sb.corner_radius_top_left = 6
	banner_sb.corner_radius_top_right = 6
	banner_sb.corner_radius_bottom_left = 6
	banner_sb.corner_radius_bottom_right = 6
	_card_peek_banner.add_theme_stylebox_override("panel", banner_sb)
	_card_peek_title.text = card.name
	_card_peek_title.add_theme_color_override("font_color", CardColors.text_on(banner_color))

	_card_peek_subtype.text = _card_subtype_text(card)
	_card_peek_description.text = _card_description(card)
	_card_peek_info_text.text = _card_info_text(card)
	# Art mode: fills the popup as the whole card face and hides all the
	# placeholder chrome (banner, body panel, info panel) — only the button
	# row stays visible below.
	# Text mode (no art): shows the placeholder banner + description + info,
	# just as before, so actions/tributes still read.
	var art_tex := CardView._load_card_art(card.art_path)
	if art_tex != null:
		_card_peek_art.texture = art_tex
		_card_peek_art.visible = true
		_card_peek_banner.visible = false
		_card_peek_body.visible = false
		_card_peek_info.visible = false
	else:
		_card_peek_art.texture = null
		_card_peek_art.visible = false
		_card_peek_banner.visible = true
		_card_peek_body.visible = true
		_card_peek_info.visible = true

	# Button enablement mirrors the bottom bar rules.
	var can_play_turn := _tm.can_play() and _gs.current_player_index == HUMAN_ID
	_card_peek_bank.disabled = not (can_play_turn and card.can_bank())
	_card_peek_play.disabled = not (can_play_turn and _card_is_playable(card))

	_card_peek_scrim.visible = true
	_card_peek.visible = true

func _hide_card_peek() -> void:
	_card_peek_card = null
	if _card_peek != null:
		_card_peek.visible = false
	if _card_peek_scrim != null:
		_card_peek_scrim.visible = false

# Cycle the zoomed card modal to the previous / next card in the human's
# hand, wrapping around at the ends. Called by the ‹/› buttons in the peek
# actions row. Also updates _selected_card so state stays coherent.
func _cycle_card_peek(delta: int) -> void:
	if _card_peek_card == null:
		return
	var human: PlayerState = _gs.players[HUMAN_ID]
	if human.hand.is_empty():
		return
	var idx := human.hand.find(_card_peek_card)
	if idx < 0:
		return
	var count := human.hand.size()
	var next_idx := (idx + delta) % count
	if next_idx < 0:
		next_idx += count
	var next_card := human.hand[next_idx]
	_selected_card = next_card
	_show_card_peek(next_card)
	_refresh_hand()
	_refresh_actions()

func _on_card_peek_bank_pressed() -> void:
	_hide_card_peek()
	_on_bank_pressed()

func _on_card_peek_play_pressed() -> void:
	_hide_card_peek()
	_on_play_pressed()

func _on_card_peek_scrim_input(event: InputEvent) -> void:
	# Tap-outside dismiss. Same behaviour for touch and mouse.
	if event is InputEventMouseButton and event.pressed:
		_hide_card_peek()
	elif event is InputEventScreenTouch and event.pressed:
		_hide_card_peek()

# --- Card description helpers -------------------------------------------

static func _card_subtype_text(c: CardData) -> String:
	match c.type:
		CardData.Type.REALM:
			return "Realm — %s" % c.realm
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				return "Wild — any realm"
			return "Wild — %s" % " or ".join(c.realms)
		CardData.Type.PEARL:
			return "Pearls"
		CardData.Type.TRIBUTE:
			if c.realms.is_empty():
				return "Tribute — Siren's Toll"
			return "Tribute — %s" % " or ".join(c.realms)
		CardData.Type.ACTION:
			return "Action"
	return ""

static func _card_description(c: CardData) -> String:
	match c.type:
		CardData.Type.REALM:
			return "Play into %s to build your set. Complete sets win the game (4 in a 2-player match). Can't be banked — its pearl value only prices it if it's paid to satisfy a debt." % c.realm
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				return "Plays into any realm. Cannot be banked as pearls, and can't be taken by Slippery Eel or Trade Winds. On your turn you can shift it freely between realms — free action."
			return "Plays into either %s. On your turn you can shift it between the two realms — free action. Can't be banked." % " or ".join(c.realms)
		CardData.Type.PEARL:
			return "Bank it to pay tributes and other players' actions. Pearls can only be banked, not played."
		CardData.Type.TRIBUTE:
			if c.realms.is_empty():
				return "Charge one chosen opponent 5 pearls of rent on any realm you own. If they can't pay from bank, they pay with realm cards."
			return "Charge every opponent rent based on how many cards you have in your %s. Pair with High Tide to double it." % " or ".join(c.realms)
		CardData.Type.ACTION:
			return _action_description(c.action_effect)
	return ""

static func _action_description(effect: String) -> String:
	match effect:
		"ride_the_current": return "Draw 2 extra cards."
		"mermaids_feast": return "Every opponent pays you 2 pearls."
		"toll_of_the_tides": return "Force one chosen opponent to pay you 5 pearls."
		"slippery_eel": return "Steal one loose realm card from any opponent (not from a completed set)."
		"trade_winds": return "Swap one of your realm cards for one of an opponent's."
		"krakens_grasp": return "Steal an entire completed realm from any opponent."
		"sirens_refusal": return "Cancel an action played against you. Played reactively — hold it for defense, or bank it."
		"high_tide": return "Doubles the next Tribute you charge this turn. Free — doesn't use a play. Cannot be played on its own — bank it, or hold it."
		"coral_cottage": return "Attach to one of your completed realms to raise its rent."
		"pearl_palace": return "Attach on top of a Coral Cottage for an even bigger rent boost."
	return ""

static func _card_info_text(c: CardData) -> String:
	# Info-box footer: rent tiers for realms/wilds, otherwise the bank value.
	# Realm/wild cards can NEVER be banked — their pearl value only prices
	# them when they're used to pay a debt.
	var lines: Array[String] = []
	match c.type:
		CardData.Type.REALM:
			var tiers: Array = Realms.RENT_TIERS.get(c.realm, [])
			lines.append("Rent by set size: " + _format_tiers(tiers))
			lines.append("Set size: %d · Worth %d P toward a debt (can't be banked)" % [Realms.size_of(c.realm), c.value])
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				lines.append("Can't be banked or paid — a wild placeholder only.")
			else:
				lines.append("Worth %d P toward a debt (can't be banked)" % c.value)
		CardData.Type.PEARL:
			lines.append("%d pearls to bank" % c.value)
		CardData.Type.TRIBUTE:
			lines.append("Bank value: %d P" % c.value)
		CardData.Type.ACTION:
			if c.value > 0:
				lines.append("Bank value: %d P" % c.value)
			else:
				lines.append("Cannot be banked.")
	return "\n".join(lines)

static func _format_tiers(tiers: Array) -> String:
	var parts: Array[String] = []
	for t in tiers:
		parts.append(str(t))
	return " / ".join(parts)

# --- Mockup-styled chrome ------------------------------------------------
#
# Lifts the chrome styling from docs/sirens-bargain-gameplay-styled.html:
# radial navy background, gold-outlined draw pile, Cinzel turn labels, three
# button variants (prim / ghost / util / gold-text), and a bottom-bar gradient
# behind the Actions row. Called at the end of _ready so it overrides the
# defaults baked into the .tscn without touching the scene layout.

func _apply_mockup_styling() -> void:
	_style_background()
	_style_action_bar_backdrop()
	_style_button_as(_bank_button, "ghost")
	_style_button_as(_play_button, "prim")
	_style_button_as(_end_turn_button, "ghost")
	_style_button_as(_fan_button, "util")
	_style_button_as(_zoom_button, "util")
	_style_button_as(_to_menu_button, "ghost")
	_style_turn_block()
	_style_draw_pile()
	_style_prompt_label()
	_style_action_menu()

# Darken the popup ActionMenu so its text never fades into the gameplay
# behind it. Godot's default Panel stylebox was near-transparent grey.
func _style_action_menu() -> void:
	if _menu_root == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.067, 0.122, 0.97)
	sb.border_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.45)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 12
	_menu_root.add_theme_stylebox_override("panel", sb)

func _style_background() -> void:
	# Overlay a radial-gradient TextureRect on top of the existing solid
	# Background ColorRect so the ColorRect can act as a fallback fill under
	# any transparent edges of the gradient.
	var bg := get_node_or_null("Background")
	if bg is ColorRect:
		(bg as ColorRect).color = CH_NAVY_DEEP
	if has_node("BackgroundGlow"):
		return
	var glow := TextureRect.new()
	glow.name = "BackgroundGlow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([CH_NAVY_MID, CH_NAVY, CH_NAVY_DEEP])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(1.2, 1.2)
	gt.width = 1024
	gt.height = 1024
	glow.texture = gt
	# Insert immediately after Background so it renders behind everything else
	# but above the flat colour fill.
	add_child(glow)
	move_child(glow, 1)

func _style_action_bar_backdrop() -> void:
	# Bottom-bar treatment from the mockup — a vertical gradient that fades
	# from opaque navy at the bottom to transparent higher up, giving the
	# controls a "docked" chin without a hard divider line.
	if has_node("ActionBarBackdrop"):
		return
	var bar := TextureRect.new()
	bar.name = "ActionBarBackdrop"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.offset_top = -110
	bar.offset_bottom = 0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color(0.024, 0.067, 0.122, 0.0),
		Color(0.024, 0.067, 0.122, 0.55),
		Color(0.024, 0.067, 0.122, 0.96),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 32
	gt.height = 128
	bar.texture = gt
	add_child(bar)
	# Layer it BEHIND the Root HBox — otherwise the gradient draws over the
	# Actions buttons and swallows their outlines. `Root` is a direct child of
	# GameScreen, so placing the bar at Root's index shifts Root up and the
	# bar renders under it.
	var root_node := get_node_or_null("Root")
	if root_node != null:
		move_child(bar, root_node.get_index())

# --- Button variants ------------------------------------------------------

func _style_button_as(btn: Button, kind: String) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 11
	sb.corner_radius_top_right = 11
	sb.corner_radius_bottom_left = 11
	sb.corner_radius_bottom_right = 11
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	match kind:
		"prim":
			# Primary gold — solid GOLD fill (StyleBoxFlat can't gradient),
			# GOLD_LT on hover to hint at the mockup's sheen.
			sb.bg_color = CH_GOLD
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.border_width_top = 0
			sb.border_width_bottom = 0
			sb.shadow_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.35)
			sb.shadow_size = 5
			sb.shadow_offset = Vector2(0, 4)
			btn.add_theme_color_override("font_color", CH_INK_ON_GOLD)
			btn.add_theme_color_override("font_hover_color", CH_INK_ON_GOLD)
			btn.add_theme_color_override("font_pressed_color", CH_INK_ON_GOLD)
			btn.add_theme_color_override("font_disabled_color", Color(CH_INK_ON_GOLD.r, CH_INK_ON_GOLD.g, CH_INK_ON_GOLD.b, 0.5))
			var hover := sb.duplicate()
			hover.bg_color = CH_GOLD_LT
			hover.shadow_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.5)
			hover.shadow_size = 7
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			# Disabled ("dim") — 35 % opacity via a duplicated stylebox with
			# alpha-lowered bg; matches the mockup's `.dim` treatment.
			var disabled := sb.duplicate()
			disabled.bg_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.35)
			disabled.shadow_size = 0
			btn.add_theme_stylebox_override("disabled", disabled)
		"ghost":
			# Bumped from 4%/35% to 12%/70% — over the gradient chin the low
			# opacity was reading as invisible; this gives the outline enough
			# contrast to define the button.
			sb.bg_color = Color(0.055, 0.114, 0.184, 0.75)
			sb.border_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.7)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			btn.add_theme_color_override("font_color", CH_PEARL)
			btn.add_theme_color_override("font_hover_color", CH_PEARL)
			btn.add_theme_color_override("font_pressed_color", CH_PEARL)
			btn.add_theme_color_override("font_disabled_color", Color(CH_PEARL.r, CH_PEARL.g, CH_PEARL.b, 0.4))
			var hover := sb.duplicate()
			hover.bg_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.2)
			hover.border_color = CH_GOLD_LT
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			var disabled := sb.duplicate()
			disabled.bg_color = Color(0.055, 0.114, 0.184, 0.45)
			disabled.border_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.3)
			btn.add_theme_stylebox_override("disabled", disabled)
		"util":
			# Quieter cousin of ghost — solid navy tint with a subtle gold
			# outline, so Fan/Zoom stay legible against the gradient chin.
			sb.bg_color = Color(0.055, 0.114, 0.184, 0.65)
			sb.border_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.5)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			sb.content_margin_top = 11
			sb.content_margin_bottom = 11
			btn.add_theme_color_override("font_color", CH_MIST)
			btn.add_theme_color_override("font_hover_color", CH_PEARL)
			btn.add_theme_color_override("font_pressed_color", CH_PEARL)
			btn.add_theme_color_override("font_disabled_color", Color(CH_MIST.r, CH_MIST.g, CH_MIST.b, 0.4))
			var hover := sb.duplicate()
			hover.bg_color = Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.18)
			hover.border_color = CH_GOLD_LT
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			btn.add_theme_stylebox_override("disabled", sb.duplicate())
		"gold-text":
			# Transparent button, gold-lt text — used for text-only affordances.
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.border_width_top = 0
			sb.border_width_bottom = 0
			btn.add_theme_color_override("font_color", CH_GOLD_LT)
			btn.add_theme_color_override("font_hover_color", Color("F2D98A"))
			btn.add_theme_color_override("font_pressed_color", Color("F2D98A"))
			btn.add_theme_stylebox_override("hover", sb.duplicate())
			btn.add_theme_stylebox_override("pressed", sb.duplicate())
			btn.add_theme_stylebox_override("disabled", sb.duplicate())
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("focus", sb)

# --- Turn block + draw pile ---------------------------------------------

func _style_turn_block() -> void:
	if _turn_label != null:
		_turn_label.add_theme_font_override("font", _chrome_serif_font())
		_turn_label.add_theme_font_size_override("font_size", 26)
		_turn_label.add_theme_color_override("font_color", CH_PEARL)
		_turn_label.add_theme_constant_override("shadow_offset_y", 1)
		_turn_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _plays_label != null:
		_plays_label.add_theme_font_size_override("font_size", 15)
		_plays_label.add_theme_color_override("font_color", CH_HAZE)
		_plays_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Plays-remaining dots — 3 pips under the plays label. Gold when the
	# player still has that play, muted white when spent.
	if _plays_label != null and _plays_dots == null:
		var parent := _plays_label.get_parent()
		_plays_dots = HBoxContainer.new()
		_plays_dots.add_theme_constant_override("separation", 6)
		_plays_dots.alignment = BoxContainer.ALIGNMENT_CENTER
		_plays_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in range(TurnManager.MAX_PLAYS):
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(9, 9)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_plays_dots.add_child(dot)
		parent.add_child(_plays_dots)

func _refresh_plays_dots(remaining: int) -> void:
	if _plays_dots == null:
		return
	for i in range(_plays_dots.get_child_count()):
		var dot := _plays_dots.get_child(i) as Panel
		if dot == null:
			continue
		var lit := i < remaining
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 5
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_left = 5
		sb.corner_radius_bottom_right = 5
		sb.bg_color = CH_GOLD_LT if lit else Color(1, 1, 1, 0.18)
		dot.add_theme_stylebox_override("panel", sb)

func _style_draw_pile() -> void:
	# Draw pile — navy fill + subtle drop shadow. No gold border (the card
	# art on top already provides its own edge, and the outline was reading
	# as a redundant halo).
	var box := get_node_or_null("Root/GameCol/MidTable/DrawPileBox")
	if box != null and not box.has_node("DrawFrame"):
		var frame := Panel.new()
		frame.name = "DrawFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = CH_NAVY
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		frame.add_theme_stylebox_override("panel", sb)
		box.add_child(frame)
		box.move_child(frame, 0)
	if _draw_label != null:
		_draw_label.add_theme_font_override("font", _chrome_serif_font())
		_draw_label.add_theme_font_size_override("font_size", 20)
		_draw_label.add_theme_color_override("font_color", CH_GOLD_LT)
	# Discard pile placeholder — dashed gold outline shown only when the
	# discard is empty. Attached to the DiscardPileBox behind its texture
	# children so any drawn top-card art fully covers it.
	var disc := get_node_or_null("Root/GameCol/MidTable/DiscardPileBox")
	if disc != null and not disc.has_node("DiscardOutline"):
		var outline := Control.new()
		outline.name = "DiscardOutline"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.set_anchors_preset(Control.PRESET_FULL_RECT)
		outline.draw.connect(_draw_dashed_border.bind(outline))
		disc.add_child(outline)
		disc.move_child(outline, 0)

# Called from a DiscardOutline's `draw` signal. Draws a 1 px dashed rectangle
# around the control's rect in a low-opacity gold — matches the mockup's
# `.discard .d { border:1px dashed rgba(201,162,39,.3); }`.
func _draw_dashed_border(ctrl: Control) -> void:
	if ctrl == null:
		return
	var color := Color(CH_GOLD.r, CH_GOLD.g, CH_GOLD.b, 0.3)
	var w := ctrl.size.x
	var h := ctrl.size.y
	var dash := 4.0
	var gap := 3.0
	var step := dash + gap
	var x := 0.0
	while x < w:
		var seg_end: float = min(x + dash, w)
		ctrl.draw_line(Vector2(x, 0), Vector2(seg_end, 0), color, 1.0)
		ctrl.draw_line(Vector2(x, h - 1), Vector2(seg_end, h - 1), color, 1.0)
		x += step
	var y := 0.0
	while y < h:
		var seg_end: float = min(y + dash, h)
		ctrl.draw_line(Vector2(0, y), Vector2(0, seg_end), color, 1.0)
		ctrl.draw_line(Vector2(w - 1, y), Vector2(w - 1, seg_end), color, 1.0)
		y += step

func _style_prompt_label() -> void:
	if _prompt_label == null:
		return
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", CH_HAZE)

func _chrome_serif_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

# --- Online refusable-action protocol -----------------------------------
#
# Refusable actions (Kraken / Eel / Trade / Toll / Feast / Tribute) require
# three networked steps to stay in lockstep:
#   1. INITIATE_* — both mirrors create the same PendingAction.
#   2. REFUSE / RESOLVE — both apply the same refusal stack, then the same
#      resolve. Whichever peer's HUMAN_ID is the "next refuser" acts; the
#      other peer awaits their broadcast.
#   3. SETTLE_PAYMENT (owed-map actions only) — the payer's peer picks the
#      cards (auto via smart_picks or via the user picker) and broadcasts
#      the exact ids; both peers apply PaymentResolver.pay with the same
#      lists so their mirrors transfer the same cards.

static func _find_refusal_in_hand(player: PlayerState) -> CardData:
	for c in player.hand:
		if c.action_effect == "sirens_refusal":
			return c
	return null

# Prompt the local human whether to refuse the pending action. Unlike
# _prompt_human_refusal, this doesn't gate on target_id — used for both the
# defender's initial refusal AND the attacker's counter-refusal. Caller has
# already confirmed HUMAN_ID is `next_refuser_for(target)`.
func _prompt_local_refusal(pending: PendingAction) -> bool:
	var human: PlayerState = _gs.players[HUMAN_ID]
	if _find_refusal_in_hand(human) == null:
		return false
	_show_refusal_modal(pending)
	var choice: bool = await _refusal_answered
	_hide_refusal_modal()
	return choice

func _run_online_refusable_flow() -> Variant:
	var pending: PendingAction = _gs.pending_action
	if pending == null:
		return null
	# Reset the resolve-result cache so we can't return stale data from a
	# previous action.
	_last_resolve_result = null
	# Anchor the mask clock at the moment BOTH peers see the pending action.
	_pending_action_initiated_msec = Time.get_ticks_msec()
	for target_id in pending.targets.duplicate():
		var outcome: String = await _refusal_cycle_for_target(target_id)
		if outcome == "cancelled":
			return null
	return _last_resolve_result

# Hold the attacker's peer until at least _REFUSABLE_MASK_MSEC has passed
# since the action was initiated. No-op on the defender's peer — they
# already know their own decision, so masking their view just feels laggy.
func _wait_for_refusable_mask() -> void:
	var pending: PendingAction = _gs.pending_action
	if pending == null:
		return
	if pending.initiator_id != HUMAN_ID:
		return
	var elapsed := Time.get_ticks_msec() - _pending_action_initiated_msec
	var remaining := _REFUSABLE_MASK_MSEC - elapsed
	if remaining > 0:
		await get_tree().create_timer(remaining / 1000.0).timeout

func _refusal_cycle_for_target(target_id: int) -> String:
	while true:
		var pa: PendingAction = _gs.pending_action
		if pa == null:
			return "cancelled"
		var next_refuser: int = pa.next_refuser_for(target_id)
		var refuser: PlayerState = _gs.players[next_refuser]
		var refusal_card := _find_refusal_in_hand(refuser)
		if next_refuser == HUMAN_ID:
			if refusal_card == null:
				# Can't refuse — resolve.
				await _apply_resolve_locally_and_broadcast()
				return "resolved"
			var wants: bool = await _prompt_local_refusal(pa)
			if wants:
				_tm.refuse(target_id, HUMAN_ID, refusal_card)
				_broadcast({
					"kind": NetProtocol.KIND_REFUSE,
					"target": target_id,
					"refuser": HUMAN_ID,
					"card_id": refusal_card.id,
				})
				_refresh_all()
				# Loop — opponent gets to counter-refuse or resolve.
			else:
				await _apply_resolve_locally_and_broadcast()
				return "resolved"
		else:
			# Opponent's turn to decide — wait for their event.
			var decision: String = await _remote_refusal_decision
			if decision == "resolved":
				return "resolved"
			# else "refused" — loop and check whether we can counter-refuse.
	# Unreachable — the `while true` above always returns from one of its
	# branches. Only here to satisfy Godot's "all paths return a value" check.
	return "cancelled"

func _apply_resolve_locally_and_broadcast() -> void:
	# Broadcast first so the opponent's peer starts its own resolve without
	# waiting on our mask. THEN pad locally before applying — the attacker
	# sees a consistent delay regardless of how fast the decision landed.
	_broadcast({"kind": NetProtocol.KIND_RESOLVE})
	await _wait_for_refusable_mask()
	_last_resolve_result = _tm.resolve_pending()
	_refresh_all()

# Receiver-side entry point — called after applying an INITIATE_* event. We
# run our own refusal cycle in parallel with the attacker's; both cycles
# converge on the same resolve. If the resolve produced an owed map, run
# settlement (which either broadcasts our payment or awaits theirs).
func _handle_remote_initiated_action() -> void:
	_state = InteractionState.AI_TURN
	_refresh_all()
	var result: Variant = await _run_online_refusable_flow()
	if result is Dictionary:
		await _settle_online(result)
	_refresh_all()

func _settle_online(owed: Dictionary) -> void:
	# In 2P HvH the receiver of the payment is always the attacker of the
	# pending action, i.e. the opponent of any local payer.
	var opp_id: int = 1 - HUMAN_ID
	for k in owed.keys():
		var payer_id: int = int(k)
		var amount: int = int(owed[k])
		if amount <= 0:
			continue
		if payer_id == HUMAN_ID:
			var payer: PlayerState = _gs.players[HUMAN_ID]
			var receiver: PlayerState = _gs.players[opp_id]
			# _prompt_human_payment returns a Dict when the bank alone can't
			# cover the debt (user picked their realm cards); returns null
			# when the bank covers, in which case we fall back to smart auto.
			var picks_var: Variant = await _prompt_human_payment(payer, receiver, amount)
			# Defensively build strongly-typed arrays: Dict values come back
			# as Variant and direct assignment to `Array[CardData]` can throw
			# a runtime type-mismatch that silently kills the coroutine —
			# which was leaving Cancel-triggered auto-pay in limbo.
			var from_bank: Array[CardData] = []
			var from_realms: Array[CardData] = []
			var src_bank: Array = []
			var src_realms: Array = []
			if picks_var is Dictionary:
				src_bank = (picks_var as Dictionary).get("bank", [])
				src_realms = (picks_var as Dictionary).get("realms", [])
			else:
				# Cancel / null → fall back to smart auto so the debt still
				# gets paid instead of stranding both peers on a hung modal.
				var auto := PaymentResolver.smart_picks(payer, amount)
				src_bank = auto.get("bank", [])
				src_realms = auto.get("realms", [])
			for c in src_bank:
				if c is CardData:
					from_bank.append(c)
			for c in src_realms:
				if c is CardData:
					from_realms.append(c)
			_broadcast({
				"kind": NetProtocol.KIND_SETTLE_PAYMENT,
				"payer": HUMAN_ID,
				"receiver": receiver.id,
				"amount": amount,
				"bank_ids": _card_ids_from(from_bank),
				"realm_ids": _card_ids_from(from_realms),
			})
			PaymentResolver.pay(payer, receiver, amount, from_bank, from_realms)
			_tm.log_payment(HUMAN_ID, receiver.id, from_bank, from_realms)
			_refresh_all()
		else:
			# Opponent is paying — wait for their SETTLE_PAYMENT broadcast.
			# Lock End Turn until they send it so we can't skip past.
			_awaiting_payment = true
			_refresh_actions()
			await _remote_payment_decided
			_awaiting_payment = false
			_refresh_actions()

static func _card_ids_from(cards: Array[CardData]) -> Array:
	var out: Array = []
	for c in cards:
		out.append(c.id)
	return out

# --- Incoming event handlers --------------------------------------------

func _apply_initiate_kraken(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var card_id := String(payload.get("card_id", ""))
	var target_id := int(payload.get("target", -1))
	var realm_name := String(payload.get("realm", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	if card == null:
		return
	_tm.initiate_krakens_grasp(card, target_id, realm_name)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_initiate_eel(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var target_id := int(payload.get("target", -1))
	var card_id := String(payload.get("card_id", ""))
	var stolen_id := String(payload.get("stolen_id", ""))
	var dest_realm := String(payload.get("dest", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	var stolen := NetProtocol.find_in_realms(_gs.players[target_id], stolen_id)
	if card == null or stolen == null:
		return
	_tm.initiate_slippery_eel(card, target_id, stolen, dest_realm)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_initiate_trade(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var target_id := int(payload.get("target", -1))
	var card_id := String(payload.get("card_id", ""))
	var own_id := String(payload.get("own_id", ""))
	var their_id := String(payload.get("their_id", ""))
	var own_dest := String(payload.get("own_dest", ""))
	var their_dest := String(payload.get("their_dest", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	var own_card := NetProtocol.find_in_realms(_gs.players[actor], own_id)
	var their_card := NetProtocol.find_in_realms(_gs.players[target_id], their_id)
	if card == null or own_card == null or their_card == null:
		return
	_tm.initiate_trade_winds(card, target_id, own_card, their_dest, their_card, own_dest)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_initiate_toll(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var target_id := int(payload.get("target", -1))
	var card_id := String(payload.get("card_id", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	if card == null:
		return
	_tm.initiate_toll_of_the_tides(card, target_id)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_initiate_feast(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var card_id := String(payload.get("card_id", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	if card == null:
		return
	_tm.initiate_mermaids_feast(card)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_initiate_tribute(payload: Dictionary) -> void:
	var actor := int(payload.get("actor", -1))
	var card_id := String(payload.get("card_id", ""))
	var charger_realm := String(payload.get("charger_realm", ""))
	var target_id := int(payload.get("target", -1))
	var ht_id := String(payload.get("ht_id", ""))
	var card := NetProtocol.find_in_hand(_gs.players[actor], card_id)
	if card == null:
		return
	var ht_card: CardData = null
	if not ht_id.is_empty():
		ht_card = NetProtocol.find_in_hand(_gs.players[actor], ht_id)
	_tm.initiate_tribute(card, charger_realm, target_id, ht_card)
	_refresh_all()
	_handle_remote_initiated_action()

func _apply_refuse(payload: Dictionary) -> void:
	var target_id := int(payload.get("target", -1))
	var refuser_id := int(payload.get("refuser", -1))
	var card_id := String(payload.get("card_id", ""))
	var refuser: PlayerState = _gs.players[refuser_id]
	var card := NetProtocol.find_in_hand(refuser, card_id)
	if card == null:
		return
	_tm.refuse(target_id, refuser_id, card)
	_refresh_all()
	_remote_refusal_decision.emit("refused")

func _apply_resolve(_payload: Dictionary) -> void:
	# Attacker's peer: pad to the minimum mask duration so the visible
	# resolve timing never leaks whether the defender was thinking or
	# auto-passing. Defender's peer skips this — they already know.
	await _wait_for_refusable_mask()
	_last_resolve_result = _tm.resolve_pending()
	_refresh_all()
	_remote_refusal_decision.emit("resolved")

func _apply_settle_payment(payload: Dictionary) -> void:
	var payer_id := int(payload.get("payer", -1))
	var receiver_id := int(payload.get("receiver", -1))
	var amount := int(payload.get("amount", 0))
	var bank_ids: Array = payload.get("bank_ids", [])
	var realm_ids: Array = payload.get("realm_ids", [])
	var payer: PlayerState = _gs.players[payer_id]
	var receiver: PlayerState = _gs.players[receiver_id]
	var from_bank: Array[CardData] = []
	for id in bank_ids:
		var c := NetProtocol.find_in(payer.bank, String(id))
		if c != null:
			from_bank.append(c)
	var from_realms: Array[CardData] = []
	for id in realm_ids:
		var c := NetProtocol.find_in_realms(payer, String(id))
		if c != null:
			from_realms.append(c)
	PaymentResolver.pay(payer, receiver, amount, from_bank, from_realms)
	_tm.log_payment(payer_id, receiver_id, from_bank, from_realms)
	_refresh_all()
	# If WE were the receiver, flash a banner so the payment is
	# unmistakable. The log line is small; the banner catches the eye.
	if receiver_id == HUMAN_ID:
		var payer_name := OPPONENT_NAME if payer_id != HUMAN_ID else HUMAN_NAME
		_flash_turn_banner("%s PAID YOU %d P" % [payer_name.to_upper(), amount])
	_remote_payment_decided.emit()

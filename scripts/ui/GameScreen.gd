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
	DISCARD,
	AI_TURN,
	GAME_OVER,
}

const HUMAN_ID := 0
const OPPONENT_NAME := "Coral"
const HUMAN_NAME := "You"

@onready var _turn_label: Label = %TurnLabel
@onready var _plays_label: Label = %PlaysLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _discard_top_banner: ColorRect = %DiscardTopBanner
@onready var _discard_top_label: Label = %DiscardTopLabel
@onready var _draw_label: Label = %DrawLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _log_scroll: ScrollContainer = %LogScroll
@onready var _log_list: VBoxContainer = %LogList
@onready var _turn_banner: Label = %TurnBanner
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
@onready var _refuse_button: Button = %RefuseButton
@onready var _accept_button: Button = %AcceptButton

signal _refusal_answered(refuse: bool)
@onready var _opponent_board: PlayerBoardView = %OpponentBoard
@onready var _player_board: PlayerBoardView = %PlayerBoard
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _bank_button: Button = %BankButton
@onready var _play_button: Button = %PlayButton
@onready var _end_turn_button: Button = %EndTurnButton
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

var _card_peek_card: CardData = null
var _card_peek_art: TextureRect = null

var _gs: GameState
var _tm: TurnManager
var _ais: Dictionary = {}     # id -> AIOpponent (opponents only)
var _sfx: SoundEffects = null

var _state: int = InteractionState.IDLE
var _selected_card: CardData = null
var _ctx: Dictionary = {}      # scratchpad for multi-step target picks
var _pending_discards: Array[CardData] = []

func _ready() -> void:
	_setup_game()
	_configure_boards()
	_setup_sound()
	_wire_signals()
	_style_card_peek()
	_hide_menu()
	_hide_peek()
	_hide_card_peek()
	_hide_game_over()
	_hide_refusal_modal()
	_start_human_turn()

func _setup_sound() -> void:
	_sfx = SoundEffects.new()
	add_child(_sfx)

# --- Game setup ----------------------------------------------------------

func _setup_game() -> void:
	var deck := DeckBuilder.build_deck()
	var seed_value: int = Time.get_ticks_usec()
	_gs = GameState.new(2, deck, seed_value)
	_tm = TurnManager.new(_gs)
	_shuffle_draw_pile()
	for p in _gs.players:
		for i in range(5):
			var c := _gs.draw_card()
			if c != null:
				p.hand.append(c)
	_ais[1] = AIOpponent.new(1)

func _shuffle_draw_pile() -> void:
	var arr: Array[CardData] = _gs.draw_pile
	for i in range(arr.size() - 1, 0, -1):
		var j := _gs.rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _configure_boards() -> void:
	_opponent_board.player = _gs.players[1]
	_opponent_board.configure(OPPONENT_NAME, "AI", OPPONENT_NAME.substr(0, 1), CardColors.STEEL, false)
	_player_board.player = _gs.players[HUMAN_ID]
	_player_board.configure(HUMAN_NAME, "", "M", Color("6e5aa8"), true)

func _wire_signals() -> void:
	_bank_button.pressed.connect(_on_bank_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_menu_cancel.pressed.connect(_on_menu_cancel_pressed)
	_peek_close.pressed.connect(_hide_peek)
	_card_peek_bank.pressed.connect(_on_card_peek_bank_pressed)
	_card_peek_play.pressed.connect(_on_card_peek_play_pressed)
	_card_peek_close.pressed.connect(_hide_card_peek)
	_card_peek_scrim.gui_input.connect(_on_card_peek_scrim_input)
	_opponent_board.realm_chip_pressed.connect(_on_opp_chip_pressed)
	_player_board.realm_chip_pressed.connect(_on_own_chip_pressed)
	# Play-by-play log fed by TurnManager. Fires for both human and AI plays.
	_tm.play_logged.connect(_on_play_logged)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_refuse_button.pressed.connect(func(): _refusal_answered.emit(true))
	_accept_button.pressed.connect(func(): _refusal_answered.emit(false))
	# Give the AI a coroutine to await when it initiates something at the
	# human — modal → user picks Refuse / Accept → resolve.
	for id in _ais.keys():
		var ai: AIOpponent = _ais[id]
		ai.human_refusal_hook = _prompt_human_refusal

# --- Turn loop -----------------------------------------------------------

func _start_human_turn() -> void:
	_state = InteractionState.IDLE
	_selected_card = null
	_ctx.clear()
	_tm.start_turn()
	_refresh_all()
	_flash_turn_banner("Your turn")
	_prompt("Tap a card in your hand.")

func _end_human_turn() -> void:
	var human := _gs.players[HUMAN_ID]
	var over := human.hand.size() - TurnManager.HAND_LIMIT
	if over > 0:
		_begin_discard(over)
		return
	_tm.end_turn([])
	_run_ai_turns()

func _begin_discard(count: int) -> void:
	_state = InteractionState.DISCARD
	_pending_discards.clear()
	_ctx["discard_needed"] = count
	_prompt("Tap %d card(s) to discard." % count)
	_refresh_all()

func _finish_discard() -> void:
	_tm.end_turn(_pending_discards)
	_pending_discards.clear()
	_run_ai_turns()

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
		_flash_turn_banner("%s's turn" % OPPONENT_NAME)
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
	var winner_id := _gs.winner()
	var winner_is_you := winner_id == HUMAN_ID
	_game_over_title.text = "You win!" if winner_is_you else "%s wins" % OPPONENT_NAME
	_game_over_subtitle.text = "First to %d completed realms." % _gs.sets_to_win()
	# Populate per-player stat rows so the player can see the final board.
	for child in _game_over_stats.get_children():
		child.queue_free()
	for p in _gs.players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := Label.new()
		name_lbl.text = HUMAN_NAME if p.id == HUMAN_ID else OPPONENT_NAME
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", CardColors.PEARL if p.id == winner_id else CardColors.MIST)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var stats_lbl := Label.new()
		stats_lbl.text = "%d sets · %d ◈" % [p.completed_realm_count(), p.total_bank_value()]
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", CardColors.MIST)
		row.add_child(stats_lbl)
		_game_over_stats.add_child(row)
	_game_over_scrim.visible = true
	_game_over_panel.visible = true
	_prompt("Game over.")
	_refresh_all()
	if _sfx != null:
		_sfx.play("game_over")

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
	_refusal_scrim.visible = true
	_refusal_panel.visible = true

func _hide_refusal_modal() -> void:
	if _refusal_panel != null:
		_refusal_panel.visible = false
	if _refusal_scrim != null:
		_refusal_scrim.visible = false

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
			return "Toll of the Tides — pay %d ◈.\nRefuse?" % per
		"sirens_toll":
			var per: int = int(pending.payload.get("per_target", 5))
			var r: String = pending.payload.get("charger_realm", "a realm")
			return "Siren's Toll on %s — pay %d ◈.\nRefuse?" % [r, per]
		"mermaids_feast":
			var per: int = int(pending.payload.get("per_target", 2))
			return "Mermaid's Feast — pay %d ◈.\nRefuse?" % per
		"tribute":
			var per: int = int(pending.payload.get("per_target", 0))
			var r: String = pending.payload.get("charger_realm", "?")
			return "Tribute on %s — pay %d ◈.\nRefuse?" % [r, per]
	return "Action against you.\nRefuse?"

# --- Rendering -----------------------------------------------------------

func _refresh_all() -> void:
	_refresh_mid_table()
	_opponent_board.refresh()
	_player_board.refresh()
	_refresh_hand()
	_refresh_actions()

func _refresh_mid_table() -> void:
	if _state == InteractionState.GAME_OVER:
		_turn_label.text = "Game over"
		_plays_label.text = ""
	elif _gs.current_player_index == HUMAN_ID:
		_turn_label.text = "Your turn"
		var left: int = TurnManager.MAX_PLAYS - _tm.plays_this_turn
		_plays_label.text = "%d plays left" % left
	else:
		_turn_label.text = "%s's turn" % OPPONENT_NAME
		_plays_label.text = "%d plays left" % max(0, TurnManager.MAX_PLAYS - _tm.plays_this_turn)
	_draw_label.text = "%d" % _gs.draw_pile.size()
	_discard_label.text = "%d" % _gs.discard_pile.size()
	# Top-of-discard indicator: the last card discarded (usually an action or
	# tribute — realms lay on boards, not the discard pile). Empty pile hides.
	if _gs.discard_pile.is_empty():
		_discard_top_banner.color = CardColors.INK
		_discard_top_label.text = ""
	else:
		var top: CardData = _gs.discard_pile[_gs.discard_pile.size() - 1]
		_discard_top_banner.color = CardColors.for_card(top)
		var display := top.name
		if top.type == CardData.Type.ACTION:
			var short := CardView._short_action_name(top.action_effect)
			if not short.is_empty():
				display = short
		_discard_top_label.text = display

func _refresh_hand() -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	var human := _gs.players[HUMAN_ID]
	for c in human.hand:
		var view := CardView.new()
		view.card = c
		# Highlight either the currently-selected card (normal play) or
		# cards queued for discard (end-of-turn).
		var is_lifted := false
		if _state == InteractionState.DISCARD:
			is_lifted = _pending_discards.has(c)
		else:
			is_lifted = _selected_card != null and _selected_card == c
		view.selected_state = is_lifted
		view.size_flags_vertical = Control.SIZE_SHRINK_END
		view.selected.connect(_on_hand_card_selected)
		_hand_row.add_child(view)

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
	# Selection-dependent enablement.
	var have_selection := _selected_card != null
	var can_play_turn := _tm.can_play()
	_bank_button.disabled = not (have_selection and can_play_turn and _selected_card.can_bank())
	_play_button.disabled = not (have_selection and _card_is_playable(_selected_card))
	_end_turn_button.disabled = false
	_end_turn_button.text = "End turn"

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
	_turn_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_turn_banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.55)
	tw.tween_property(_turn_banner, "modulate:a", 0.0, 0.35)
	if _sfx != null:
		_sfx.play("turn_change")

# --- Play log ------------------------------------------------------------

func _on_play_logged(actor_id: int, text: String) -> void:
	# Text uses "P0"/"P1" placeholders for player references — substitute
	# names for display. Actor gets bolded before the verb.
	var who := HUMAN_NAME if actor_id == HUMAN_ID else OPPONENT_NAME
	var line := text
	# Order matters: "P10" would be broken by naive "P1" replacement, but
	# we only ever have two players so it's safe.
	line = line.replace("P%d" % HUMAN_ID, "you")
	if _ais.has(1):
		line = line.replace("P1", OPPONENT_NAME)
	_append_log("[b]%s[/b] %s" % [who, line])
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
		_show_card_peek(card)
	_refresh_hand()
	_refresh_actions()

# --- Bank/Play buttons ---------------------------------------------------

func _on_bank_pressed() -> void:
	# Bottom bar Bank shares the same code as menu-driven bank confirmations.
	_do_bank()

func _on_play_pressed() -> void:
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
	var options: Array = []
	for r in candidates:
		options.append({"label": r, "cb": Callable(self, "_place_realm").bind(r)})
	_state = InteractionState.SELECT_OWN_REALM
	_show_menu("Play %s in…" % _selected_card.name, options)

func _place_realm(target_realm: String) -> void:
	_hide_menu()
	var card := _selected_card
	if card == null:
		return
	if _tm.play_realm(card, target_realm):
		_prompt("Played %s in %s." % [card.name, target_realm])
	_selected_card = null
	_reset_to_idle()

func _begin_play_action(card: CardData) -> void:
	match card.action_effect:
		"ride_the_current":
			if _tm.play_ride_the_current(card):
				_prompt("Rode the Current — drew 2.")
			_reset_to_idle()
		"mermaids_feast":
			var pending := _tm.initiate_mermaids_feast(card)
			if pending == null:
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
	var pending := _tm.initiate_toll_of_the_tides(_selected_card, target_id)
	if pending == null:
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
	var pending := _tm.initiate_krakens_grasp(_selected_card, target_id, realm_name)
	if pending == null:
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
	var pending := _tm.initiate_slippery_eel(_selected_card, target_id, stolen, dest_realm)
	if pending == null:
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
	var options: Array = []
	for r in _valid_realms_for(own_card):
		if opp.is_realm_complete(r):
			continue
		options.append({"label": r, "cb": Callable(self, "_do_trade").bind(r)})
	if options.is_empty():
		_prompt("Nowhere on their board for your card.")
		_reset_to_idle()
		return
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
	# Resolver order: (own_card, their_dest_realm, their_card, own_dest_realm)
	var pending := _tm.initiate_trade_winds(_selected_card, opp_id,
		own_card, their_board_dest, their_card, own_board_dest)
	if pending == null:
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
	if _tm.play_coral_cottage(_selected_card, realm):
		_prompt("Cottage on %s." % realm)
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
	if _tm.play_pearl_palace(_selected_card, realm):
		_prompt("Palace on %s." % realm)
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
			{"label": "Bank it (%d ◈)" % _selected_card.value, "cb": Callable(self, "_do_bank")},
		]
		_show_menu("No matching realm to charge from — bank it?", bank_options)
		return
	if eligible.size() == 1:
		await _tribute_pick_target(eligible[0])
		return
	# Multiple eligible realms — tap the chip on your own strip. Colour +
	# progress count on the chip make the choice obvious; no name menu needed.
	_state = InteractionState.SELECT_OWN_REALM_FOR_CHARGE
	_prompt("Tap your realm to charge from.")

# --- Bank action (button + tribute-no-realm confirmation) ----------------

func _do_bank() -> void:
	_hide_menu()
	if _selected_card == null:
		return
	if _tm.bank_card(_selected_card):
		_prompt("Banked %s." % _selected_card.name)
	_selected_card = null
	_reset_to_idle()

func _is_valid_charger_realm(tribute: CardData, realm_name: String) -> bool:
	var human: PlayerState = _gs.players[HUMAN_ID]
	var stack: Array = human.realms.get(realm_name, [])
	if stack.is_empty():
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
			"label": "Charge %d ◈" % base_rent,
			"cb": Callable(self, "_do_tribute").bind(charger_realm, target_id, null),
		},
		{
			"label": "Charge with High Tide — %d ◈ (free)" % high_tide_rent,
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
	var pending := _tm.initiate_tribute(_selected_card, charger_realm, target_id, high_tide)
	if pending == null:
		_reset_to_idle()
		return
	await _open_refusal_window()
	var result: Variant = _tm.resolve_pending()
	var label := "Tribute (%s)" % charger_realm
	if high_tide != null:
		label += " + High Tide"
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
		var paid := PaymentResolver.settle_greedy(payer, receiver, amount)
		total += paid
	if total > 0:
		_prompt("%s → %d pearls." % [label, total])
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

func _hide_menu() -> void:
	if _menu_root != null:
		_menu_root.visible = false

# --- Realm peek overlay --------------------------------------------------

# Popup that shows the full card faces in one realm on tap. Two modes:
#   * informational (default) — read-only, plus a wild-shift affordance on
#     your own realms.
#   * picker (pick_cb set) — every card tap fires the callback with the card;
#     used by Slippery Eel and Trade Winds to let the player pick a specific
#     card visually rather than from a text menu.
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
	_peek_root.visible = true

func _hide_peek() -> void:
	if _peek_root != null:
		_peek_root.visible = false
	_ctx.erase("peek_player")
	_ctx.erase("peek_realm")

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
	# Picker mode: a targeting flow (Eel / Trade) opened the peek to let the
	# player pick a specific card. Fire its callback and dismiss.
	var pick_cb_var: Variant = _ctx.get("peek_pick_cb")
	if pick_cb_var is Callable and (pick_cb_var as Callable).is_valid():
		var cb: Callable = pick_cb_var
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
	var options: Array = []
	for r in candidates:
		options.append({"label": r, "cb": Callable(self, "_do_wild_shift").bind(card, realm, r)})
	# Close the peek before showing the destination menu so overlays don't
	# stack weirdly; we'll reopen the peek on the destination after the move.
	_hide_peek()
	_show_menu("Move %s to…" % card.name, options)

func _do_wild_shift(card: CardData, from_realm: String, to_realm: String) -> void:
	_hide_menu()
	var human: PlayerState = _gs.players[HUMAN_ID]
	human.reassign_wild(card, from_realm, to_realm)
	_prompt("%s moved: %s → %s." % [card.name, from_realm, to_realm])
	# State stays IDLE — reassigning a wild is free. Refresh boards, then
	# reopen the peek on the destination so the player sees where it landed.
	_refresh_all()
	_show_realm_peek(HUMAN_ID, to_realm)

static func _modifier_display_name(m: CardData) -> String:
	match m.action_effect:
		"coral_cottage": return "Coral Cottage"
		"pearl_palace": return "Pearl Palace"
	return m.name

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
			return "Play into %s to build your set. Complete sets win the game (4 in a 2-player match)." % c.realm
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				return "Plays into any realm. Cannot be banked as pearls, and can't be taken by Slippery Eel or Trade Winds. On your turn you can shift it freely between realms — free action."
			return "Plays into either %s. On your turn you can shift it between the two realms — free action." % " or ".join(c.realms)
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
	var lines: Array[String] = []
	match c.type:
		CardData.Type.REALM:
			var tiers: Array = Realms.RENT_TIERS.get(c.realm, [])
			lines.append("Rent by set size: " + _format_tiers(tiers))
			lines.append("Set size: %d · Bank value: %d ◈" % [Realms.size_of(c.realm), c.value])
		CardData.Type.WILD_REALM:
			if c.is_rainbow_conch():
				lines.append("Cannot be banked.")
			else:
				lines.append("Bank value: %d ◈" % c.value)
		CardData.Type.PEARL:
			lines.append("%d pearls to bank" % c.value)
		CardData.Type.TRIBUTE:
			lines.append("Bank value: %d ◈" % c.value)
		CardData.Type.ACTION:
			if c.value > 0:
				lines.append("Bank value: %d ◈" % c.value)
			else:
				lines.append("Cannot be banked.")
	return "\n".join(lines)

static func _format_tiers(tiers: Array) -> String:
	var parts: Array[String] = []
	for t in tiers:
		parts.append(str(t))
	return " / ".join(parts)

# Siren's Bargain — Build Plan
*Godot 4 project structure + step-by-step Claude Code prompts*

Companion to `card-spec.md`. Keep both files in the project's `docs/` folder so Claude Code can read the card spec while building.

---

## 1. Project File Structure

```
sirens-bargain/
├── project.godot
├── docs/
│   ├── card-spec.md            # the 106-card spec — Claude Code reads this
│   └── build-plan.md           # this file
│
├── data/
│   └── cards.json              # generated deck data (all 106 cards)
│
├── scripts/
│   ├── autoload/
│   │   ├── GameEvents.gd       # global signal bus (singleton)
│   │   └── Settings.gd         # audio/prefs (singleton)
│   │
│   ├── core/                   # pure logic — NO UI code in here
│   │   ├── CardData.gd         # Resource: one card's data
│   │   ├── DeckBuilder.gd      # builds + shuffles the 106-card deck
│   │   ├── PlayerState.gd      # hand, bank, realms for one player
│   │   ├── GameState.gd        # whole match state
│   │   ├── TurnManager.gd      # draw / 3 plays / discard / win check
│   │   ├── RentCalculator.gd   # rent tables, High Tide, Cottage, Palace
│   │   ├── PaymentResolver.gd  # paying from bank + realms, no change given
│   │   └── ActionResolver.gd   # standalone action card effects
│   │
│   ├── ai/
│   │   └── AIOpponent.gd       # greedy opponent logic
│   │
│   └── ui/
│       ├── CardView.gd
│       ├── HandView.gd
│       ├── PlayerBoardView.gd
│       ├── GameScreen.gd
│       └── MainMenu.gd
│
├── scenes/
│   ├── Main.tscn               # entry point
│   ├── MainMenu.tscn
│   ├── GameScreen.tscn
│   ├── CardView.tscn
│   ├── HandView.tscn
│   └── PlayerBoardView.tscn
│
├── assets/
│   ├── art/
│   │   ├── cards/              # original mermaid art only
│   │   ├── ui/
│   │   └── backgrounds/
│   ├── fonts/
│   └── audio/
│       ├── sfx/
│       └── music/
│
└── tests/                      # GUT test suite
    ├── test_deck_builder.gd
    ├── test_rent_calculator.gd
    ├── test_payment_resolver.gd
    └── test_action_resolver.gd
```

**The one rule that matters:** everything in `scripts/core/` must run with no UI attached. If the game logic can play a full match headlessly in tests, the UI becomes easy and swapping in multiplayer later stays possible. If logic leaks into UI scripts, you'll be rewriting later.

---

## 2. Setup Before You Prompt

1. Install **Godot 4** (free, godotengine.org).
2. Create a new project named `sirens-bargain`, GL Compatibility renderer (best for mobile/web export).
3. Create the folders above (empty is fine).
4. Drop `card-spec.md` into `docs/`.
5. Install **GUT** (Godot Unit Test) from the AssetLib tab inside Godot — free, and it's what makes the "test each step" workflow work.
6. Open a terminal in the project folder and run `claude`.

---

## 3. The Build Prompts

Run these in order. **Finish and verify each one before moving to the next.** The whole point of this order is that every step is testable on its own.

---

### Phase 1 — Deck & Data Model

```
Read docs/card-spec.md.

Build the card data layer for a Godot 4 GDScript project:

1. scripts/core/CardData.gd — a Resource class representing one card, with
   fields: id, name, type (REALM, WILD_REALM, PEARL, TRIBUTE, ACTION),
   value, realm, realms (for wilds), rent_tiers, action_effect.
2. data/cards.json — the complete 106-card deck exactly matching the spec's
   counts and values.
3. scripts/core/DeckBuilder.gd — loads cards.json into CardData objects,
   validates the total is 106 with correct per-type counts, and provides
   build_deck() and shuffle(seed) with a seedable RNG for testing.
4. tests/test_deck_builder.gd — GUT tests asserting total count, per-type
   counts, and that each realm has the right number of cards.

Pure data and logic only, no UI. Run the tests and show me they pass.
```

---

### Phase 2 — Turn Loop & Banking

```
Build the match skeleton:

1. scripts/core/PlayerState.gd — hand, bank, and realms (dictionary of
   realm name to array of cards). Methods to bank a card and compute
   total bank value.
2. scripts/core/GameState.gd — players, draw pile, discard pile,
   current player index.
3. scripts/core/TurnManager.gd — draw 2 at turn start (5 if hand empty),
   allow up to 3 card plays per turn, enforce the 7-card hand limit at
   end of turn, then advance to the next player. Reshuffle the discard
   pile into the draw pile when it empties.

Only banking is a legal "play" for now. Add GUT tests covering the draw
rules, the 3-play limit, and the discard limit.
```

---

### Phase 3 — Laying Realms & Win Condition

```
Add realm (property) play:

1. Playing a REALM card lays it in front of the player under its realm.
2. WILD_REALM cards can be assigned to either of their realms and flipped
   later; Rainbow Conch counts as any realm and can never be banked.
3. Track which realms are complete (card count meets the spec's requirement).
4. Win check: match ends immediately when a player has the target number of completed realms — **4 in a 2-player match, 3 with 3+ players**. Encode as a helper on GameState (e.g. `sets_to_win()`) rather than a hardcoded constant.

Add GUT tests for set completion, wild reassignment, and the win trigger.
```

---

### Phase 4 — Tributes, Payment & Rent Modifiers

```
Build the full rent system. Note these three cards are rent MODIFIERS, not
standalone actions — they only function through rent, so build them here:

1. scripts/core/RentCalculator.gd — rent for a realm based on how many
   cards the owner has, using the spec's rent tables.
   - Coral Cottage: added to a COMPLETED realm, raises its rent.
   - Pearl Palace: only stacks on top of a Coral Cottage.
   - High Tide: doubles the Tribute charged this turn. It cannot be
     played alone, must accompany a Tribute, and consumes one of the
     player's 3 card plays.
2. Tribute cards: standard ones charge all players on a matching realm;
   Siren's Toll charges one chosen player on any one realm.
3. scripts/core/PaymentResolver.gd — pay from bank and/or laid realm
   cards. No change is given. A player with nothing pays nothing.

GUT tests: each rent tier, Cottage and Palace stacking, High Tide doubling,
underpayment when the bank is short, and paying with realm cards.
```

---

### Phase 5 — Standalone Action Cards

Do these **one at a time** — a separate prompt per card, testing each before the next.

```
Implement the [CARD NAME] action card in scripts/core/ActionResolver.gd,
per docs/card-spec.md. Add GUT tests for it, including edge cases
(no valid target, empty hand, targeting a completed set).
```

Order to work through them:

1. **Ride the Current** — draw 2. Simplest, proves the resolver wiring.
2. **Mermaid's Feast** — every player pays 2.
3. **Toll of the Tides** — one player pays 5.
4. **Slippery Eel** — steal one loose realm card (never from a completed set).
5. **Trade Winds** — swap one realm card with another player.
6. **Kraken's Grasp** — steal a whole completed realm.
7. **Siren's Refusal** — last, and hardest: it cancels an action played
   against you, and can itself be cancelled by another Siren's Refusal.
   Build it as a response stack that resolves in reverse order.

---

### Phase 6 — AI Opponent

```
Build scripts/ai/AIOpponent.gd — a greedy opponent that, on its turn:
- Plays realm cards that progress toward completing a set
- Charges rent whenever it has a Tribute and a matching realm, preferring
  the highest payout and adding High Tide when the payout justifies it
- Uses Kraken's Grasp / Slippery Eel on the leading player
- Banks cards it can't otherwise use, keeping Siren's Refusal in hand
  to defend
- Respects the 3-play limit and discards down to 7

Add a headless test that plays 100 full AI-vs-AI matches with seeded RNG
and asserts none crash, stall, or exceed a sane turn cap. Report the
average game length.
```

This phase is the real payoff — if 100 matches run clean with no UI, the rules engine is genuinely done.

---

### Phase 7 — UI

```
Build the UI in scenes/, reading from the core logic without duplicating
any rules:
- MainMenu.tscn: play, settings, quit
- GameScreen.tscn: your hand at the bottom, your board above it,
  opponent's board at the top, draw/discard piles, turn indicator,
  and a "plays remaining" counter
- CardView.tscn: one card, with tap-to-select and a play/bank choice
- PlayerBoardView.tscn: realms grouped by colour with completion markers

Portrait orientation, designed for phone screens, with touch targets no
smaller than 44px. Use placeholder coloured rectangles for art for now.
```

---

### Phase 8 — Polish & Export

```
Add: turn transition animations, card play sound effects, a game-over
screen, and a rules/how-to-play screen.
Then configure export presets for Android and Web, and tell me the exact
steps to produce a testable build.
```

---

## 4. Working Tips

- **One phase per session.** Start a fresh Claude Code conversation for each phase and point it at `docs/card-spec.md`. Long sessions drift.
- **Commit after every phase.** `git init` on day one. It's your undo button when a prompt goes sideways.
- **Insist on tests before moving on.** If a phase's tests don't pass, don't build on top of it — the bug compounds.
- **Play it early.** After Phase 6 you can play a full match in the terminal with no art at all. That's the moment you'll find out whether it's fun.
- **Art comes last on purpose.** It's the most personal part and the easiest to iterate on once the game actually runs.

---

## 5. About the Name

**Siren's Bargain** — the "bargain" points straight at the dealing/trading heart of the game, and "siren" carries the mermaid theme without being cutesy. It also matches the card names already in the spec (Siren's Refusal, Siren's Toll).

Alternatives if it doesn't land:

- **Tidebound** — moody, short, great app icon
- **Coral Crown** — leans into collecting and conquest
- **Pearl Reign** — the pearl economy plus winning
- **Reef & Ruin** — playful, hints at the steal/attack cards
- **Deepwater Deal** — most descriptive of the genre

Before you commit, run the final name through the free USPTO trademark search (tmsearch.uspto.gov) and a plain app-store search to make sure no existing game has it.

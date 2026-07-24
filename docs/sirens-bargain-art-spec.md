# Siren's Bargain — Art Spec

Companion to `card-spec.md` (rules and card list) and `build-plan.md` (Godot structure and prompts). Keep this in `docs/`.

---

## 1. Core palette

Shared by every card, regardless of type.

| Token | Hex | Use |
|---|---|---|
| Ink | `#0B1D33` | Card background — every card, every type |
| Ink deep | `#0A1626` | App background behind the cards |
| Frame gold | `#C9A227` | Card border hairline, 1px |
| Panel | `#14304F` | Art window and text-box fill |
| Panel edge | `#22496F` | Art window / text-box border, 0.5px |
| Cliff | `#1F4370` | Mid-depth art shapes, back-of-card details |
| Foam | `#F2F6F5` | Primary text on cards |
| Mist | `#C4D6E2` | Secondary text (rent labels, effect text) |
| Haze | `#9DB6C4` | Tertiary text ("to bank", captions) |
| Pearl | `#EDE6D4` | Pearl fill, bank-value badge |
| Pearl light | `#FBF7EC` | Pearl highlight dot |
| Pearl dark | `#3B2E12` | Text on a pearl badge |

## 2. Realm palette

Each realm has a **banner** tone (the coloured strip) and an **ink** tone (text sitting on that strip). Never use foam or black on a banner — always the realm's own ink tone.

| Realm | Banner | Ink |
|---|---|---|
| Tide pools | `#E0C18A` | `#4A3413` |
| Kelp forest | `#7FC9B4` | `#0B3A2E` |
| Coral gardens | `#F09CBA` | `#4B1528` |
| Pearl beds | `#F4A87A` | `#4A1B0C` |
| Shipwreck cove | `#E08585` | `#501313` |
| Sunken temple | `#EFC55E` | `#412402` |
| Seagrass lagoon | `#9AD16C` | `#173404` |
| Abyssal trench | `#7FA8E8` | `#12224A` |
| Ocean currents | `#BCC9D2` | `#2A3944` |
| Mystic springs | `#7FDCE8` | `#06363D` |

**Non-realm card banners:**

| Card type | Banner | Ink |
|---|---|---|
| Pearl (money) | `#EDE6D4` | `#3B2E12` |
| Tribute (rent) | `#EFC55E` | `#412402` |
| Action | `#A79EE8` | `#26215C` |
| Wild realm | Split diagonally between its two realms' banner tones | Ink of whichever half the label sits on |
| Rainbow conch | Five-band stripe: coral, gold, green, blue, aqua | `#0B1D33` on a foam label plate |

**Why every banner is a light-to-mid tone:** the spec describes Abyssal Trench as midnight blue, but a truly dark banner can't carry dark text, and light text on it disappears against the navy card. Lightening each realm and pairing it with its own deep ink keeps all ten distinguishable at thumbnail size. Colour separation at speed is the whole game.

---

## 3. Card geometry

Base card: **5:7 ratio**. Design at 500 × 700 px and export down; the reference layout below is at 180 × 252.

| Element | Position (x, y from card corner) | Size | Corner |
|---|---|---|---|
| Card body | 0, 0 | 180 × 252 | 10 |
| Banner | 8, 8 | 164 × 30 | 6 |
| Art window | 8, 44 | 164 × 96 | 6 |
| Info box (rent ladder / effect text) | 8, 146 | 164 × 52 | 6 |
| Bank badge (circle) | centre 24, 222 | r 14 | — |
| Bank caption | 46, 227 baseline | — | — |

**The anatomy never changes.** Realm cards put a rent ladder in the info box; tribute and action cards put two lines of effect text in the same box at the same size. Nothing shifts between card types. This means one `CardView.tscn` handles all 106 cards, with only the info-box contents swapped — build it that way in Phase 7.

### Type scale (at 180 × 252)

| Role | Size | Weight | Colour |
|---|---|---|---|
| Banner name | 14 | 500 | Realm ink |
| Rent label ("2 cards") | 12 | 400 | Mist |
| Rent value | 12 | 500 | Foam |
| Effect text (2 lines max) | 12 | 400 | Mist, centred |
| Bank badge number | 14 | 500 | Pearl dark |
| Bank caption | 12 | 400 | Haze |
| Denomination (pearl cards only) | 26 | 500 | Pearl |

Sentence case everywhere. No all-caps.

---

## 4. Card back

- Ink body, gold hairline, plus an inner frame inset 10px in Cliff.
- Centre emblem: a scallop shell (semicircular fan, `#2C5A8F` fill, `#7FA8E8` edge, five ribs in `#4E7FA8`) with a pearl resting below it.
- Wave line across the upper third in Cliff, 2px.
- Game name beneath the emblem, 16px / 500, Pearl.
- Rotationally asymmetric is fine — this is a hand-held card game, not a trick-taking deck where back orientation leaks information.

---

## 5. Art window direction

The art window renders at roughly **64px tall on a phone**. This is the single most important constraint in this document.

- **Silhouettes read; detail does not.** Design each illustration as a shape you could recognise as a black cutout.
- Two to three colours per illustration, drawn from the realm's banner tone plus one neighbour.
- Keep art **floating inside the window** with a 6px margin — never bleeding to the edge. This avoids needing clipping masks in Godot and keeps rounded corners clean.
- Line weight 4–5px at the 180px reference size. Thin lines vanish when scaled.
- Backgrounds stay flat Panel colour. No gradients, no glow — they muddy at small sizes and inflate texture memory.

**Per-realm motif suggestions:**

| Realm | Motif |
|---|---|
| Tide pools | Anemone ring, small shells, a starfish |
| Kelp forest | Tall swaying fronds, light shafts |
| Coral gardens | Branching coral stems with polyp bulbs |
| Pearl beds | Open oysters in rows |
| Shipwreck cove | Broken hull ribs, a mast at an angle |
| Sunken temple | Column silhouettes, a carved arch |
| Seagrass lagoon | Flat blades, a turtle silhouette |
| Abyssal trench | V-shaped chasm walls, bioluminescent dots |
| Ocean currents | Flow arcs, drifting bubbles |
| Mystic springs | Vent plume, rising bubble column |

**Action card motifs:** Kraken's grasp — tentacles and eyes. Siren's refusal — a raised hand behind a shell barrier. Slippery eel — a single S-curve body. Trade winds — two crossing arrows over waves. Toll of the tides — a wave carrying pearls. Mermaid's feast — a laid table of shells. Ride the current — a fish tail streaking with motion lines.

---

## 6. Motion

Small and quick. Nothing here needs a tween longer than 250ms.

| Moment | Treatment |
|---|---|
| Draw | Card slides from the draw pile to hand, 200ms, ease-out |
| Play to board | Card scales to 0.9 and slides to its realm stack, 220ms |
| Rent charged | Pearl badges pulse once on the paying player's bank |
| Set completed | Gold border animates around the realm stack, 300ms, once |
| Steal (Kraken / Eel) | Card lifts, crosses the table, settles — 350ms, the one slower beat |
| Siren's refusal | Screen-edge shell wipe, 250ms, then the cancelled card greys out |

---

## 7. Asset checklist

Minimum for a playable, good-looking build:

- 10 realm illustrations
- 7 action illustrations
- 1 tribute illustration (reused across all tribute cards, tinted per realm pair)
- 1 pearl cluster (scaled/recoloured for all six denominations)
- 1 card back
- 1 app icon (the scallop-and-pearl emblem works directly)
- UI: draw pile, discard pile, turn indicator, pearl icon

That's **20 original illustrations**. Well within reach for one person over a few weeks, and a sensible brief if you commission it.

**Sourcing on a zero budget:** draw them yourself (silhouette-first design is forgiving), or use free commercial-use sources. Whatever you use, confirm the licence permits commercial use and keep a record of where each asset came from. Never trace or trace-over art from an existing game.

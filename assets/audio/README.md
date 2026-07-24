# Audio drop-in slots

`SoundEffects.gd` looks up files by event name here. Drop a `.wav`, `.ogg`,
or `.mp3` in this directory using one of the names below and it'll play
without any code change. Missing files are silent no-ops.

| File name (any of `.wav`/`.ogg`/`.mp3`) | Fired when |
| --- | --- |
| `card_play` | You lay a realm card on your board |
| `card_bank` | You bank a card |
| `action` | You play an action or tribute card |
| `turn_change` | Any player's turn begins |
| `game_over` | The win condition is reached |

Keep clips short (< 400 ms) so they don't pile up during rapid AI turns.
Small file sizes matter for the web export.

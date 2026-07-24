class_name HowToPlay
extends Control

# Static rules screen. Content mirrors docs/card-spec.md but distilled for
# in-game reading — no card tables, just the rules the player needs while
# actually playing. Scroll to read; Back returns to the main menu.

@onready var _back_button: Button = %BackButton
@onready var _rules_text: RichTextLabel = %RulesText

const RULES_BBCODE := """[color=#EDE6D4][font_size=18]How to play[/font_size][/color]

[color=#EDE6D4][b]Goal[/b][/color]
Complete [b]4 realms[/b] (in a 2-player match) to win. A realm is complete when you have laid the number of cards its set requires.

[color=#EDE6D4][b]A turn[/b][/color]
• Draw [b]2[/b] cards at the start of your turn (or [b]5[/b] if your hand is empty).
• Play up to [b]3[/b] cards — bank pearls, lay realms, or play actions.
• Discard down to [b]7[/b] cards in hand if you're over.

[color=#EDE6D4][b]Card types[/b][/color]
• [b]Realm[/b] cards belong to one realm. Play them face-up into your set.
• [b]Wild[/b] cards stand in for a realm. You can shift them between their realms on your turn — free, doesn't cost a play.
• [b]Rainbow Conch[/b] is a wild for [i]any[/i] realm. Cannot be banked as pearls.
• [b]Pearls[/b] are money. Bank them to pay tributes and actions.
• [b]Tributes[/b] charge rent from other players when you own the matching realm.
• [b]Actions[/b] have effects — steal cards, force payments, cancel plays. Every action can be banked instead of played for its pearl value.

[color=#EDE6D4][b]Payment[/b][/color]
When you owe pearls, pay from your bank and/or laid realm cards. If you can't cover it, you pay what you have — no change given. A player with nothing pays nothing.

[color=#EDE6D4][b]Actions worth calling out[/b][/color]
• [b]Kraken's Grasp[/b] — steal a complete realm set. Very strong; hold a Siren's Refusal to defend.
• [b]Siren's Refusal[/b] — cancel an action played against you. Reactive; keep it in hand.
• [b]High Tide[/b] — doubles the next Tribute you charge. Only works alongside a Tribute — free, doesn't use a play.
• [b]Coral Cottage / Pearl Palace[/b] — attach to your completed realms to raise their rent.

[color=#EDE6D4][b]Tips[/b][/color]
• Tap a card in your hand to see its full details.
• Tap a realm chip to see the cards in it. On your own, tap a wild card there to move it.
• Watch the [b]plays left[/b] counter in the middle — three plays per turn is the core constraint of the game.
"""

func _ready() -> void:
	_rules_text.text = RULES_BBCODE
	_back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

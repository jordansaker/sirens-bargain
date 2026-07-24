class_name RentCalculator
extends RefCounted

# Rent for a realm the player owns, based on how many cards are laid there and
# any Coral Cottage / Pearl Palace attached. High Tide (if active) doubles the
# final amount. Cottage and Palace only add their bonus while the realm is
# actually complete — if the set is broken, the modifiers stay attached but
# stop contributing until the set is whole again.

static func base_rent(player: PlayerState, realm: String) -> int:
	if not player.realms.has(realm):
		return 0
	var stack: Array = player.realms[realm]
	return Realms.rent_for(realm, stack.size())

static func rent(player: PlayerState, realm: String, high_tide: bool = false) -> int:
	var amount := base_rent(player, realm)
	if amount == 0:
		return 0
	if player.is_realm_complete(realm):
		if player.has_cottage(realm):
			amount += Realms.CORAL_COTTAGE_BONUS
		if player.has_palace(realm):
			amount += Realms.PEARL_PALACE_BONUS
	if high_tide:
		amount *= 2
	return amount

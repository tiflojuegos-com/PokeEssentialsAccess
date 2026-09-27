# Insurgence's databox icons beyond the stock ones (068_PokeBattle_ActualScene.rb, PokemonDataBox#refresh): the
# Delta sign, the armour of an Armored form, and the Greek-letter boxes its Primal forms draw in place of the Mega box
# (alpha and omega for Kyogre and Groudon, zeta, omicron and epsilon for Giratina, Arceus and Regigigas).
PokeAccess::Battle.icon_mark(/\Adelta\z/i, :ins_mark_delta)
PokeAccess::Battle.icon_mark(/\Aarmor\z/i, :ins_mark_armor)
PokeAccess::Battle.icon_mark(/\A(?:alpha|omega|zeta|omicron|epsilon)\z/i, :bt_mark_primal)

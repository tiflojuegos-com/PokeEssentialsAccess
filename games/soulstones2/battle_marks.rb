# Soulstones 2's own databox icons (its edited Stat Change Overlay and Battle_Scene_Objects): a pinch ability at work
# under a third of its HP and a wild foe's held item; and the kit's Hyper Mode, as its databox is the kit's edited one.
PokeAccess::Battle.icon_mark(/\Aicon_pinch\z/i, :ss2_mark_pinch)
PokeAccess::Battle.icon_mark(/\Aicon_item\z/i, :ss2_adv_holds)
PokeAccess::Battle.icon_mark(/\Aicon_hyper_mode\z/i, :dbk_mark_hyper)

# The engine's databox boxes beyond the stock Mega one (Battle_Scene.rb, PokemonDataBox#refresh): PULSE, Rift and
# Perfection forms, Rejuvenation's Ultra Burst and Terastal boxes, and its ball for a species caught in another form.
PokeAccess::Battle.icon_mark(/\AbattlePulseEvoBox\z/i, :rv_mark_pulse)
PokeAccess::Battle.icon_mark(/\AbattleRiftEvoBox\z/i, :rv_mark_rift)
PokeAccess::Battle.icon_mark(/\AbattlePerfectionEvoBox\z/i, :rv_mark_perfection)
PokeAccess::Battle.icon_mark(/\AbattleUltraEvoBox\z/i, :bt_m_ultra)
PokeAccess::Battle.icon_mark(/\AbattleTerastalBox\z/i, :bt_m_tera)
PokeAccess::Battle.icon_mark(/\AbattleBoxOwnedSpecies\z/i, :rv_mark_owned_species)

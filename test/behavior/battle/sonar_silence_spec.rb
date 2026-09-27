# The sonar goes quiet in a gen-6 wild battle (no $game_temp.in_battle, the fight runs inside Scene_Map): the battle's
# start and end set Battle.in_battle?, which Spatial.busy? consults.
Suite.define("battle: sonar silenced while in battle (gen-6 wild)") do
  PokeAccess::Battle.battle_ended
  falsy "flag clear at rest", PokeAccess::Battle.in_battle?
  PokeAccess::Battle.battle_started
  truthy "flag set once a battle starts", PokeAccess::Battle.in_battle?
  truthy "busy is true while the in-battle flag is set", PokeAccess::Spatial.busy?
  PokeAccess::Battle.battle_ended
  falsy "flag clear after the battle ends", PokeAccess::Battle.in_battle?
end

# clear_battle runs every map frame, a gen-6 fight included, so it leaves the in-battle flag to battle_ended.
Suite.define("battle: clear_battle does NOT lower the in-battle flag") do
  PokeAccess::Battle.battle_started
  PokeAccess::Battle.clear_battle
  truthy "flag survives a per-frame clear_battle", PokeAccess::Battle.in_battle?
  PokeAccess::Battle.battle_ended
  falsy "only battle_ended clears it", PokeAccess::Battle.in_battle?
end

# battle_ended (the end marker of the gen-6 games that never set Game_Temp#in_battle) takes the battle's move and
# foes off the info key; a Pokemon or an item it had stays.
Suite.define("battle: the end of a fight takes the battle's move and foes off the info key") do
  PokeAccess::Battle.battle_started
  PokeAccess::Info.set_info(:battle_foe, nil)
  PokeAccess::Battle.battle_ended
  eq "the key no longer answers with the foes", PokeAccess::Info.instance_variable_get(:@kind), nil
  PokeAccess::Info.set_info(:pokemon, :someone)
  PokeAccess::Battle.battle_started
  PokeAccess::Battle.battle_ended
  eq "a Pokemon it had stays", PokeAccess::Info.instance_variable_get(:@kind), :pokemon
end

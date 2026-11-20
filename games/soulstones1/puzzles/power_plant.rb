# Neo Avion Power Plant (maps 401 and 402): five sprite-less "Bomb Panel" terminals (events 33 to 37, self switch A once
# done) raise variable 279; the sixth (event 32) already has its explosives and counts for nothing. Cameron, at the door of
# map 402 (event 30), lets the player by with 5.
PokeAccess::Game.define("soulstones1") do
  mechanic(:state, 401) do
    auto
    name 33..37, :ss1_plant_terminal, :when => lambda { |ev| !$game_self_switches[[401, ev.id, "A"]] }
    name 32, :ss1_plant_terminal_set, :when => false
    count :ss1_plant_explosives, :var => 279, :from => 0, :of => 5, :assist => true, :hide_zero => true
    hint :ss1_plant_hint
    solved { $game_variables[279].to_i >= 5 }
  end
end

# Teknite Cave 2F (map 639) and its crystal take (647): a wild battle leaving the Crystal Cavern field (Power Gem) turns
# the floor into 647, Earthquake back. The red crystal (event 5) reacts to the key and sets variable 375 to 1, so the
# rock at (15, 10) breaks with Rock Smash: once in 647, twice in 639 (2, then 3). At 3 the stairs up are open.
PokeAccess::Game.define("reborn") do
  rock = { 1 => :rbf_teknite_reacted, 2 => :rbf_teknite_cracked, 3 => :rbf_teknite_open }
  mechanic(:state, 647, :part => :crystal) do
    auto
    watch :var => 375, :label => :rbf_teknite_rock, :words => rock
    name 5, :rbf_teknite_crystal
    hint :rbf_teknite_hint_crystal
    solved(nil, :quiet => true) { $game_variables[375].to_i >= 3 }
  end
  mechanic(:state, 639, :part => :crystal) do
    auto
    watch :var => 375, :label => :rbf_teknite_rock, :words => rock
    hint :rbf_teknite_hint_cave
    solved(nil, :quiet => true) { $game_variables[375].to_i >= 3 }
  end
end

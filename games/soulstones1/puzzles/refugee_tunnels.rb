# Refugee Tunnels (maps 15, 17, 18, 19 and 21): with Artie along (switch 117), nine Joltik about the tunnels raise
# variable 194 from 1 to 10 as each is picked up, and with all of them (11) the three magnetised boulders before the way
# out of map 21 (events 24 to 26) give way.
PokeAccess::Game.define("soulstones1") do
  mechanic(:state, [15, 17, 18, 19, 21], :part => :joltik) do
    auto
    count :ss1_joltik, :value => lambda { [[$game_variables[194].to_i - 1, 0].max, 9].min }, :of => 9, :assist => true,
                       :hide_zero => true
    hint :ss1_joltik_hint
    solved(nil, :quiet => true) { $game_variables[194].to_i >= 11 }
  end
end

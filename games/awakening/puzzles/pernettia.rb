# Mount Pernettia's wind (maps 57, 61 and 62), on the only way on from the west: while variable 68 is under 2 the scene
# at (40, 6) of map 57 turns the player back from the climb, and on the climb of map 61 a gust at (16, 17) drives them
# back. Inside the mountain the chest at (38, 6) gives the orb (68 to 1) and the pedestal at (36, 48) takes it (68 to
# 2), both used facing up, and the wind outside stops. With the puzzle assist each map says the step left.
PokeAccess::Game.define("awakening") do
  mechanic(:state, [57, 61], :part => :orb) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? && $game_variables[68].to_i < 2 }, :quiet => true,
          :hint => :awk_orb_wind_hint
    solved { $game_variables[68].to_i >= 2 }
  end

  mechanic(:state, 62, :part => :orb) do
    auto
    name 22, :awk_orb_pedestal
    phase lambda { PokeAccess::Puzzles.assist? && $game_variables[68].to_i < 1 }, :quiet => true,
          :hint => :awk_orb_chest_hint
    phase lambda { PokeAccess::Puzzles.assist? && $game_variables[68].to_i == 1 }, :quiet => true,
          :hint => :awk_orb_pedestal_hint
    solved { $game_variables[68].to_i >= 2 }
  end
end

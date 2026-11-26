# Hydreigon's three Dark Matter: item balls in Iolia Valley at (15, 14) of map 345 and (11, 9) of 339, and at (35, 7) of
# 332 in the Subseven Sanctum's left room, behind the Sanctum Key's door. A purple crystal swaps Iolia's twin rooms (345
# and 350) with the Crystal Key in the bag; the altar of map 329 takes a Soul Candle once variable 159 is 18.
module PokeAccess
  module RebornHydreigonDarkMatter
    CRYSTALS = { 345 => [1, 6], 350 => [1, 3] }
    ALTAR_MAP = 329
    ALTAR = 124
    DEINO = 433
  end
end

PokeAccess::Game.define("reborn") do
  hy = PokeAccess::RebornHydreigonDarkMatter
  crystal = lambda { |_ev| PokeAccess::RebornIolia.purple_label }
  hy::CRYSTALS.each do |map, ids|
    mechanic(:state, map, :part => :crystals) do
      auto
      name ids, crystal
    end
  end

  mechanic(:state, hy::ALTAR_MAP, :part => :altar) do
    auto
    name hy::ALTAR, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rbj_hy_altar_hint : :rbj_hy_altar },
         :when => lambda { |_ev| $game_variables[159].to_i >= 18 && !$game_switches[hy::DEINO] }
  end
end

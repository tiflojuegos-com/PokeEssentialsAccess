# Tanzan Depths' unstable ground (maps 614 and 615): a battle on the cave field whose ceiling falls (a second use of
# Earthquake, Bulldoze, Magnitude or Fissure) leaves variable 10 at 1, and the ground then gives way: 614 drops the
# player to 617 (switches 740 to 742, the doors of 260 lead there), 615 to 618 (743). With the assist, how to do it.
module PokeAccess
  module RebornTanzanCollapse
    FLOORS = { 614 => 740, 615 => 743 }

    # The rule said on arriving, with the assist, while the floor of the map stands.
    def self.rule(map)
      PokeAccess::Puzzles.assist? && !$game_switches[FLOORS[map]] ? :rbj_tz_quake_hint : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  tc = PokeAccess::RebornTanzanCollapse
  tc::FLOORS.each do |map, sw|
    mechanic(:state, map, :part => :collapse) do
      auto
      arrival_hint lambda { tc.rule(map) }
      solved(nil, :quiet => true) { $game_switches[sw] }
    end
  end
end

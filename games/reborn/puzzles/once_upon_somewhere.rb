# Once Upon a Somewhere (map 696): the forest wraps round, each edge (events 1 to 62) sending the player to the opposite
# one. A wrap adds one to variable 380 when the way faced differs from variable 361, which each wrap sets to 2 after a
# vertical one and 4 after a sideways one. At 3 a bridge appears north-east (events 100 to 104) to map 697.
module PokeAccess
  module RebornSomewhere
    def self.count
      $game_variables[380].to_i
    end

    def self.bridge?
      count >= 3
    end

    # True while the bridge is up and on the player's screen.
    def self.bridge_in_sight?
      bridge? && ($game_player.x - 49).abs <= 10 && ($game_player.y - 26).abs <= 8
    end

    def self.hint
      bridge? ? :rbb_some_hint_bridge : [:rbb_some_hint, { :n => 3 - count }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  some = PokeAccess::RebornSomewhere
  mechanic(:state, 696, :part => :forest) do
    auto
    name 1..62, :rbb_some_edge, :grouped => true
    name [100, 101], :rbb_some_bridge, :grouped => true
    sent_back :rbb_some_wrap, :events => 1..62
    phase lambda { some.bridge_in_sight? }, :title => :rbb_some_bridge_seen, :quiet => true,
          :hint => :rbb_some_hint_bridge
    phase lambda { true }, :quiet => true, :hint => lambda { some.hint }
    active { !$game_switches[874] }
    solved(nil, :quiet => true) { $game_switches[874] }
  end
end

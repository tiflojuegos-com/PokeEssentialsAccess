# The Rhodochrine Tree (map 886): the obelisk, White Shard 101 at (18,15), stands only with the blindstep password
# (switch 2226), the nopuzzles one (2227) or the tree done in another save (2199), each its own page, so the shared
# waiting-obelisk notice misses it. With the assist, arriving says it can be skipped until variable 660 is 19.
module PokeAccess
  module RebornTreeObelisk
    SHOWN_BY = [2226, 2227, 2199]

    # With the assist and the obelisk not standing, the notice that a password brings it; nil otherwise.
    def self.rule
      return nil unless PokeAccess::Puzzles.assist?
      return nil if $game_variables[660].to_i >= 19
      SHOWN_BY.any? { |sw| $game_switches[sw] } ? nil : :reb_obelisk_hint
    end
  end
end

PokeAccess::Game.define("reborn") do
  tree = PokeAccess::RebornTreeObelisk
  mechanic(:state, 886, :part => :obelisk) do
    auto
    arrival_hint lambda { tree.rule }
  end
end

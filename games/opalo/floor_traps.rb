# Opalo's trap floor: the game sends a player who steps on terrain tag 4 (PBTerrain::Rock) back to the entrance of
# its psychic gym (map 36; 21,69), whatever the map, with no message, so no route steps on it, it is named as a trap
# and the move back is said as the trap's. The gym's path lights are a mechanic (puzzles.rb).
module PokeAccess
  module OpaloTraps
    # True where (x,y) is trap floor.
    def self.trap?(x, y)
      PokeAccess::World::Terrain.kind(x, y) == :rock
    end

    # The line for a teleport from trap floor onto the gym's entrance (21, 69 of map 36), else nil.
    def self.sent_back(from, to)
      to == [21, 69, 36] && trap?(from[0], from[1]) ? PokeAccess::I18n.t(:op_trap_back) : nil
    end
  end
end

PokeAccess::Game.define("opalo") do
  terrain_rule(:kinds => [:rock]) { |x, y, _d| PokeAccess::OpaloTraps.trap?(x, y) ? false : nil }

  PokeAccess::World::Terrain.label_rule { |x, y| PokeAccess::OpaloTraps.trap?(x, y) ? :op_trap : nil }

  PokeAccess::Locator.teleport_cause(:opalo_trap_floor) { |from, to| PokeAccess::OpaloTraps.sent_back(from, to) }
end

# Opalo's trap floor: the game sends a player who steps on terrain tag 4 (PBTerrain::Rock) back to the entrance of its
# psychic gym (map 36; 21,69), whatever the map, with no message. It looks like the floor round it, so only with the
# puzzle assist is it named as a trap and kept off by the routes; the move back is said as the trap's. What shows the
# way is the gym's path lights (puzzles/psychic_gym.rb).
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
  terrain_rule(:kinds => [:rock], :assist => true) { |x, y, _d| PokeAccess::OpaloTraps.trap?(x, y) ? false : nil }

  PokeAccess::World::Terrain.label_rule do |x, y|
    PokeAccess::OpaloTraps.trap?(x, y) ? (PokeAccess::Puzzles.assist? ? :op_trap : false) : nil
  end

  PokeAccess::Locator.teleport_cause(:opalo_trap_floor) { |from, to| PokeAccess::OpaloTraps.sent_back(from, to) }
end

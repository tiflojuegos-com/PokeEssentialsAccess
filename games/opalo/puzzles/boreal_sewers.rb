# Opalo's three levers of the Boreal sewers (map 226, at (77..81, 16)): they go down only in one order, the middle one
# (var 133), the left one (var 134) and the right one (var 135, switch 434), which opens the gate of (20..23, 47..48). A
# lever out of turn puts the three back up, with the same sound as a right one.
module PokeAccess
  module OpaloSewers
    LEVERS = [133, 134, 135]

    # How many levers stand down.
    def self.down
      LEVERS.count { |v| $game_variables[v].to_i >= 2 }
    end
  end
end

PokeAccess::Game.define("opalo") do
  mechanic(:state, 226) do
    auto
    name 19..21, :loc_lever
    obstacle({ :events => 28..35 }, :label => :loc_sign_locked)
    count :op_sewer_levers, :value => lambda { PokeAccess::OpaloSewers.down }, :of => 3, :reset => :op_sewer_reset
    solved { $game_switches[434] }
    hint :op_sewer_hint
  end
end

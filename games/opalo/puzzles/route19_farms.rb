# Opalo's boarded-up farm doors on Route 19 (event 37 of map 251 with switch 559, event 16 of map 252 with switch 560): they
# have no graphic and answer only with the plank from the farm (var 165), which breaks them open. Without a name they are
# listed as signs.
module PokeAccess
  module OpaloFarmDoors
    BROKEN = { 37 => 559, 16 => 560 }

    # The name of a door, told apart once the plank has broken it.
    def self.label(ev)
      $game_switches[BROKEN[ev.id]] ? :op_farm_door : :op_boarded_door
    end
  end
end

PokeAccess::Game.define("opalo") do
  doors = PokeAccess::OpaloFarmDoors
  mechanic(:state, 251) do
    auto
    name 37, lambda { |ev| doors.label(ev) }
  end
  mechanic(:state, 252) do
    auto
    name 16, lambda { |ev| doors.label(ev) }
  end
end

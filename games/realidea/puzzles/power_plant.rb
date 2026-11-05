# The Power Plant (map 46): five levers each open one gate for good, by a short scene that moves the player to the gate and
# back. Lever and gate each turn their self switch A on, which is what their pages and the count read. The five levers pulled
# end the rule and the count on the info key.
module PokeAccess
  module RealideaPlant
    MAP = 46
    LEVERS = [2, 6, 7, 11, 14]
    GATES = [8, 29, 13, 4, 5]

    # True once an event of the map has its self switch A on.
    def self.done?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # True once every lever has been pulled.
    def self.all_pulled?
      LEVERS.all? { |id| done?(id) }
    end
  end
end

PokeAccess::Game.define("realidea") do
  plant = PokeAccess::RealideaPlant
  mechanic(:state, plant::MAP) do
    auto
    name plant::LEVERS, lambda { |ev| plant.done?(ev.id) ? :rea_plant_lever_done : :rea_plant_lever }
    name plant::GATES, lambda { |ev| plant.done?(ev.id) ? :rea_plant_gate_open : :rea_plant_gate_closed }
    count :rea_plant_gates, :selfs => [plant::LEVERS, "A"]
    arrival_hint :rea_plant_rule
    solved { plant.all_pulled? }
  end
end

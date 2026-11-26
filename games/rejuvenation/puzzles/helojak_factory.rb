# Helojak Factory: two versions of one floor, the currents flowing right in map 212 (where the player comes in) and left
# in map 463; a machine takes the player to the other version, one tile down. Stepping onto a current from upstream
# rides it to its end and sets the lane's variable (183 to 190); from downstream it pushes back. WAY is the route.
module PokeAccess
  module RejuvHelojak
    FLOW = { 212 => :rj_helojak_flow_right, 463 => :rj_helojak_flow_left }
    MACHINES = { 212 => [12, 81, 82], 463 => [13, 81, 82, 83] }
    # The way, by map: [step, event, test of the lanes' variables while it is still ahead].
    WAY = {
      212 => [[1, 11, lambda { $game_variables[183].to_i == 0 }], [2, 9, lambda { $game_variables[183].to_i == 0 }],
              [3, 81, lambda { true }]],
      463 => [[4, 12, lambda { $game_variables[184].to_i == 0 }],
              [5, 59, lambda { $game_variables[184].to_i == 1 && $game_variables[186].to_i == 0 }],
              [6, 75, lambda { $game_variables[184].to_i == 1 && $game_variables[186].to_i == 0 }],
              [7, 39, lambda { $game_variables[186].to_i == 0 }], [8, 47, lambda { $game_variables[186].to_i == 1 }]]
    }

    # True while the factory is the story's next step.
    def self.live?
      $game_variables[96].to_i == 34
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  factory = PokeAccess::RejuvHelojak
  factory::FLOW.each do |map, flow|
    mechanic(:state, map, :part => :helojak) do
      auto
      name factory::MACHINES[map], :rj_helojak_machine
      factory::WAY[map].each do |n, id, ahead|
        spot :event => id, :label => [:rj_helojak_step, { :n => n }], :assist => true,
             :when => lambda { factory.live? && ahead.call }
      end
      phase(lambda { true }, :title => flow, :quiet => true, :entry_title => true, :hint => :rj_helojak_hint)
      solved(nil, :quiet => true) { $game_variables[96].to_i >= 35 }
    end
  end
end

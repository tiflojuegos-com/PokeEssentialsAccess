# Darchlight Manor (maps 112 and 408), the Clefairy doll: variable 316 walks a chain of clues from the diary (event 55)
# to the doll by the well (map 408, event 8, 316 at 16); the doll reappears one step further each time. STEPS lists the
# event and hint of each stop (there is no 13). Clues no sprite shows are named; with the assist the next one is said.
module PokeAccess
  module RejuvDarchlight
    # Variable 316 => [map, event of the next step, its hint].
    STEPS = {
      0 => [112, 55, :rje_dm_h_diary], 1 => [112, 58, :rje_dm_h_doll], 2 => [112, 19, :rje_dm_h_doll],
      3 => [112, 40, :rje_dm_h_doll], 4 => [112, 10, :rje_dm_h_key], 5 => [112, 18, :rje_dm_h_cabinet],
      6 => [112, 60, :rje_dm_h_doll], 7 => [112, 14, :rje_dm_h_portrait], 8 => [112, 24, :rje_dm_h_gatekey],
      9 => [112, 42, :rje_dm_h_doll], 10 => [112, 41, :rje_dm_h_boulder], 11 => [112, 63, :rje_dm_h_gate],
      12 => [112, 84, :rje_dm_h_note], 14 => [408, 6, :rje_dm_h_well], 15 => [408, 8, :rje_dm_h_ball]
    }
    # Variable 316 on map 112 once the chain has moved on to map 408: the gate out.
    GATE_OUT = 83

    # The chain's stage.
    def self.stage
      $game_variables[316].to_i
    end

    # The next step's event on this map, or nil when it lies elsewhere or the chain is over.
    def self.next_event
      step = STEPS[stage]
      return nil unless step
      return step[1] if step[0] == $game_map.map_id
      $game_map.map_id == 112 && step[0] == 408 ? GATE_OUT : nil
    end

    # Where the next step's event stands on this map, or nil.
    def self.next_tile
      id = next_event
      ev = id && $game_map.events[id]
      ev ? [ev.x, ev.y] : nil
    end

    # The hint of the stage: the step's own, or the way out to map 408.
    def self.hint
      step = STEPS[stage]
      return nil unless step
      step[0] == $game_map.map_id ? step[2] : :rje_dm_h_out
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  dm = PokeAccess::RejuvDarchlight
  mechanic(:state, 112, :part => :clefairy) do
    auto
    name [38, 58, 19, 40, 60, 16, 42], :rje_dm_doll
    name 55, :rje_dm_diary
    name 10, :rje_dm_cupboard, :when => lambda { |_ev| dm.stage == 4 }
    name 14, :rje_dm_portrait, :when => lambda { |_ev| dm.stage == 7 }
    name 43, :rje_dm_fireplace, :when => lambda { |_ev| dm.stage >= 8 }
    name [63, 83], :rje_dm_gate
    name 84, :rje_dm_note
    name 45, :rje_dm_crystal, :when => lambda { |_ev| !$game_switches[1139] }
    spot :at => lambda { dm.next_tile }, :label => :rje_dm_next, :assist => true
    dm::STEPS.each_key do |s|
      phase(lambda { PokeAccess::Puzzles.assist? && dm.stage == s }, :title => lambda { dm.hint })
    end
    solved(nil, :quiet => true) { dm.stage >= 16 }
  end
  mechanic(:state, 408, :part => :clefairy) do
    auto
    name 6, :rje_dm_well, :when => lambda { |_ev| dm.stage == 14 }
    name 8, :rje_dm_doll
    spot :at => lambda { dm.next_tile }, :label => :rje_dm_next, :assist => true
    dm::STEPS.each_key do |s|
      phase(lambda { PokeAccess::Puzzles.assist? && dm.stage == s }, :title => lambda { dm.hint })
    end
    solved(nil, :quiet => true) { dm.stage >= 16 }
  end
end

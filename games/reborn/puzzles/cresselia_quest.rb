# Cresselia Quest in the New World's Vanhanen Castle (maps 831 and 832), variable 562 from 1 (Cass's task) to 14: floors
# with no graphic set 2 and 4 (Luna's scenes give 3 and 5), the orbs at (56, 28) and (61, 5) set 6 and 8, and steps 7, 8
# and 10 unlock pairs of New World doors. The floor at (57, 63) sets 13; the battle gives 14 (a loss, back to 12).
module PokeAccess
  module RebornCresseliaQuest
    QUEST = 562
    WORLD = 831
    CASTLE = 832
    WORLD_STEPS = { 1 => [54, 55], 3 => [56, 57], 5 => [27], 7 => [19, 20, 26], 8 => [13, 14], 9 => [13, 14],
                    10 => [21, 22], 11 => [21, 22], 12 => [11, 12, 59, 60] }
    CASTLE_STEPS = { 7 => [7], 8 => [19], 9 => [21], 10 => [25], 11 => [13], 12 => [11, 14, 15] }
    LOCKED = { 13 => 8, 14 => 8, 19 => 7, 20 => 7, 21 => 10, 22 => 10 }

    # The quest's step.
    def self.step
      $game_variables[QUEST].to_i
    end

    # The hint of a step: what to do next, by where it lies.
    def self.hint(v)
      case v
      when 1, 3 then :rbj_cr_walk
      when 5 then :rbj_cr_orb_east
      when 7 then :rbj_cr_west
      when 8, 9 then :rbj_cr_middle
      when 10, 11 then :rbj_cr_north
      when 12 then :rbj_cr_end
      end
    end
  end
end

PokeAccess::Game.define("reborn") do
  cq = PokeAccess::RebornCresseliaQuest
  [[cq::WORLD, cq::WORLD_STEPS], [cq::CASTLE, cq::CASTLE_STEPS]].each do |map, steps|
    mechanic(:state, map, :part => :cresselia) do
      auto
      name(/energysphere/, :rbj_cr_orb)
      name(/^Shii/, :rbj_cr_shiinotic)
      if map == cq::WORLD
        name cq::LOCKED.keys, lambda { |ev| cq.step < cq::LOCKED[ev.id] ? :rbj_cr_locked : nil },
             :when => lambda { |ev| cq.step < cq::LOCKED[ev.id] }
      else
        name(/^BP/, :rbj_cr_chess)
      end
      steps.each do |v, ids|
        phase(lambda { PokeAccess::Puzzles.assist? && cq.step == v }, :quiet => true, :hint => cq.hint(v),
              :hidden => right_way(*ids))
      end
      active { PokeAccess::Puzzles.assist? && cq.step.between?(1, 13) }
      solved(nil, :quiet => true) { cq.step >= 14 }
    end
  end
end

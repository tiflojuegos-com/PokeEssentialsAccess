# The Cyclopean Cave off Route X (map 263), Vulson's errand (V106 at 2 once he asks for proof): of twelve fires drawn
# alike, only the different one of each step answers, EV12 (V106 from 2 to 3), then EV5 (3 to 4), then EV14, a fire
# that shows up in the middle at 4 and starts the Dusclops fights (up to 8, the end). EV1 puts V106 back to 2, even
# half way and after the fights. FIRES numbers them in reading order, row by row.
module PokeAccess
  module AfricanusCyclops
    MAP = 263
    QUEST = 106
    FIRES = { 9 => 1, 10 => 2, 8 => 3, 12 => 4, 7 => 5, 11 => 6, 6 => 7, 1 => 8, 5 => 9, 2 => 10, 4 => 11, 3 => 12 }
    MIDDLE = 14
    RESET = 1
    STEPS = [[2, 12], [3, 5], [4, 14], [5, 14], [6, 14], [7, 14]]
    DONE = 8

    # The quest's step.
    def self.step
      $game_variables[QUEST].to_i
    end

    # A fire's name by its number; with the assist, the one that puts the quest back to 2 stands out once past it.
    def self.label(ev)
      key = ev.id == RESET && PokeAccess::Puzzles.assist? && step > 2 ? :af_fire_reset : :af_fire
      [key, { :n => FIRES[ev.id] }]
    end
  end
end

PokeAccess::Game.define("africanus") do
  cave = PokeAccess::AfricanusCyclops
  mechanic(:state, cave::MAP) do
    auto
    name cave::FIRES.keys, lambda { |ev| cave.label(ev) }
    name cave::MIDDLE, :af_fire_middle
    cave::STEPS.each do |value, fire|
      phase lambda { cave.step == value }, :hidden => right_way(fire)
    end
    hint :af_fire_hint
    active { cave.step >= 2 && cave.step < cave::DONE }
    solved(nil) { cave.step >= cave::DONE }
  end
end

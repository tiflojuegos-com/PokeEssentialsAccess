# Befriending Radon in the Power Plant (map 789): variable 359 comes in at 9, and four strange machines that sparkle
# (events 27 to 30) and the first step into a forbidden hall (events 25 and 26, which spend each other) add one each. At
# 13 the office door (event 31) lets the player in by itself.
module PokeAccess
  module AshenPowerPlant
    MAP = 789
    MACHINES = [27, 28, 29, 30]
    ENTRY = 9
    OPEN = 13

    # The steps toward the office door taken so far, at most the four it needs.
    def self.taken
      [[$game_variables[359].to_i - ENTRY, 0].max, OPEN - ENTRY].min
    end

    # True while the office door waits.
    def self.waiting?
      v = $game_variables[359].to_i
      v >= ENTRY && v < OPEN
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  pp = PokeAccess::AshenPowerPlant
  mechanic(:state, pp::MAP, :part => :machines) do
    auto
    name pp::MACHINES, :afg_pp_machine, :when => lambda { |ev| !$game_self_switches[[pp::MAP, ev.id, "A"]] }
    count :afg_pp_taps, :value => lambda { pp.taken }, :of => pp::OPEN - pp::ENTRY, :assist => true
    hint :afg_pp_hint
    solved(nil, :quiet => true) { $game_variables[359].to_i >= pp::OPEN }
    active { pp.waiting? }
  end
end

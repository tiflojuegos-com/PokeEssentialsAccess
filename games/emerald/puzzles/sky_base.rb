# Sky Base (maps 566 and 567): seeds lying on the floor, each planted on its patch of soil, grow a vine to climb. On map
# 566 the seed at (21,53) goes to (10,46), the one at (28,36) to (12,27) and the one at (6,11) to (36,13); on map 567
# the one at (13,41) to (18,41), whose vine leads to the Roaring Moon. Each seed's switch is on once taken, its soil's
# once planted.
module PokeAccess
  module EmSkyBase
    STEPS = {
      566 => [[2, [21, 53], 514, 1, [10, 46], 515], [10, [28, 36], 516, 12, [12, 27], 517],
              [41, [6, 11], 518, 42, [36, 13], 519]],
      567 => [[14, [13, 41], 520, 12, [18, 41], 521]]
    }

    # The assist's line on map: the next seed to take or the soil to plant it on, and where; nil once all grow.
    def self.hint(map)
      step = STEPS[map].find { |_, _, _, _, _, planted| !$game_switches[planted] }
      return nil unless step
      _, seed_at, taken, _, soil_at, _ = step
      key, (x, y) = $game_switches[taken] ? [:em_sky_plant_hint, soil_at] : [:em_sky_seed_hint, seed_at]
      [key, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end
  end
end

PokeAccess::Game.define("emerald") do
  sky = PokeAccess::EmSkyBase
  sky::STEPS.each do |map, steps|
    mechanic(:state, map) do
      auto
      steps.each do |seed, _, taken, soil, _, planted|
        name seed, :em_sky_seed, :when => lambda { |_ev| !$game_switches[taken] }
        name soil, :em_sky_soil, :when => lambda { |_ev| $game_switches[taken] && !$game_switches[planted] }
        watch :switch => planted, :say => :em_sky_grown
      end
      phase lambda { PokeAccess::Puzzles.assist? && sky.hint(map) }, :quiet => true, :hint => lambda { sky.hint(map) }
      solved(nil, :quiet => true) { steps.all? { |_, _, _, _, _, planted| $game_switches[planted] } }
    end
  end
end

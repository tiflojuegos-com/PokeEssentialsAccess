# Heracross Woods in Aevium's past (map 244, variable 456 at 29): the red Heracross waits at one spot per step of
# variable 694 (0 to 6) and runs to another as the player steps on a no-graphic tile near it. Talking to it at 6 sets 7
# and it runs to the back of the forest, where the tiles at (18 to 20, 14) end the chase (456 to 30).
module PokeAccess
  module RejuvHeracross
    MAP = 244
    SPRITES = [4, 28, 34, 35, 14, 42, 47, 60]
    # Every tile with no graphic that moves the Heracross.
    SENSORS = [1, 2, 3, 5, 6, 7, 8, 9, 18, 19, 20, 23, 29, 30, 31, 32, 33, 36, 37, 38, 39, 40, 41, 44, 45, 46, 48, 49,
               50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 63, 64, 65, 72, 73, 74, 75, 76, 77]
    # The tiles that only ever take the chase back, or from 0 to 1 when 0 goes to 3.
    BACK = [8, 9, 18, 20, 23, 29, 30, 44, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 63, 64, 65]
    # The tiles to step on for each step of variable 694 and their label; at 6 the Heracross is talked to.
    NEXT = { 0 => [[77], :rj_heracross_next], 1 => [[36, 39], :rj_heracross_next], 2 => [[1], :rj_heracross_next],
             3 => [[19], :rj_heracross_next], 4 => [[31], :rj_heracross_next], 5 => [[45], :rj_heracross_next],
             6 => [[], nil], 7 => [[43], :rj_heracross_end] }

    # True while the chase runs.
    def self.live?
      $game_variables[456].to_i == 29
    end

    # The chase's step.
    def self.step
      $game_variables[694].to_i
    end

    # What is said as the Heracross runs, but as it runs off for good.
    def self.fled_line
      step == 7 ? nil : :rj_heracross_fled
    end

    # The assisted hint of the step.
    def self.hint
      return nil unless live?
      case step
      when 6 then :rj_heracross_hint_talk
      when 7 then :rj_heracross_hint_end
      else :rj_heracross_hint_tile
      end
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  chase = PokeAccess::RejuvHeracross
  mechanic(:state, chase::MAP, :part => :heracross) do
    auto
    name chase::SPRITES, :rj_heracross
    not_control chase::SENSORS
    watch :var => 694, :say => lambda { chase.live? ? chase.fled_line : nil }
    watch :event => 4, :say => lambda { chase.live? && chase.step == 0 ? :rj_heracross_fled : nil }
    avoid chase::BACK, :assist => true
    chase::NEXT.each do |value, (ids, label)|
      ids.each do |id|
        spot :event => id, :label => label, :assist => true, :onto => true,
             :when => lambda { chase.live? && chase.step == value }
      end
      phase(lambda { PokeAccess::Puzzles.assist? && chase.live? && chase.step == value }, :quiet => true,
            :hint => lambda { chase.hint })
    end
    active { chase.live? }
    solved(nil, :quiet => true) { $game_variables[456].to_i >= 30 }
  end
end

# Leopoli's Rhythm Gym. The Dance Room (map 222): a path of eighteen pads (events 10 and 13 to 29) where each one shows up,
# drawn, once the one before is stepped on (switches 394 to 410); the touch tiles with no sprite around them put every
# pad out (switch 394 and the rest off). The last pad sets switch 411 and the DJ fights. A new pad is in sight as it shows
# up, so where it lies is said with no assist. The Rock Room (map 277): the crowd (events 1 to 19) is pushed like boulders,
# and while switch 943 is on (the crowd's floor) the R key calls security, which puts the room back as it was.
module PokeAccess
  module XenoRhythmGym
    DANCE = 222
    ROCK = 277
    PADS = [10] + (13..29).to_a
    FIRST = 394
    DONE = 411
    STEPS = [[394, :dir_down], [395, :dir_right], [396, :dir_right], [397, :dir_up], [398, :dir_right],
             [399, :dir_down], [400, :dir_right], [401, :dir_right], [402, :dir_up], [403, :dir_up], [404, :dir_right],
             [405, :dir_right], [406, :dir_down], [407, :dir_right], [408, :dir_down], [409, :dir_down], [410, :dir_left]]
    CROWD = 1..19
    CROWD_FLOOR = 943

    # The line of the pad that has just shown up after the one that turned switch on, where it lies from that one.
    def self.next_pad(dir)
      [:xv_dance_next, { :dir => PokeAccess::I18n.t(dir) }]
    end

    # The info key's line: where the newest pad lies, or that the first one waits.
    def self.dance_line
      return nil if $game_switches[DONE]
      lit = STEPS.select { |sw, _dir| $game_switches[sw] }.last
      lit ? next_pad(lit[1]) : :xv_dance_first
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  rhythm = PokeAccess::XenoRhythmGym
  mechanic(:state, rhythm::DANCE) do
    auto
    name rhythm::PADS, :xv_dance_pad
    watch :switch => rhythm::FIRST, :label => :xv_dance_floor, :on => :xv_dance_on, :off => :xv_dance_off
    rhythm::STEPS.each { |sw, dir| watch :switch => sw, :say => lambda { rhythm.next_pad(dir) } }
    info { rhythm.dance_line }
    solved { $game_switches[rhythm::DONE] }
  end

  mechanic(:state, rhythm::ROCK) do
    auto
    name rhythm::CROWD, :xv_rock_crowd
    watch :switch => rhythm::CROWD_FLOOR, :say => :xv_rock_reset_key
    info { :xv_rock_reset_key }
    active { $game_switches[rhythm::CROWD_FLOOR] }
  end
end

# Marianette's second trial (The Three Trials, map 397, switch 669, variable 682): four coloured statues (events 48 to
# 51), moved a tile the way the player faces, go on the plates of their colour (events 43 to 46): 682 to 2. At 1,
# Tangrowth (event 24) catching up puts them back. Then Tangrowth on the white plate (event 55): 682 to 4, then 6.
module PokeAccess
  module RejuvTrials
    # [event, start, goal, legs as [direction, pushes], its label, its plate's label], in the order they are placed.
    STATUES = [
      [48, [78, 68], [64, 74], [[4, 14], [2, 6]], :rj_trials_statue_red, :rj_trials_plate_red],
      [50, [62, 67], [72, 81], [[6, 10], [2, 14]], :rj_trials_statue_yellow, :rj_trials_plate_yellow],
      [49, [63, 82], [72, 68], [[6, 4], [8, 14], [6, 5]], :rj_trials_statue_green, :rj_trials_plate_green],
      [51, [83, 82], [80, 74], [[4, 3], [8, 8]], :rj_trials_statue_blue, :rj_trials_plate_blue]
    ]
    PLATES = { 43 => :rj_trials_plate_red, 44 => :rj_trials_plate_yellow, 45 => :rj_trials_plate_blue,
               46 => :rj_trials_plate_green, 55 => :rj_trials_plate_white }
    ROOM = [59, 85, 63, 83]

    def self.stage
      $game_variables[682].to_i
    end

    # True while the trial runs and is not won.
    def self.live?
      $game_switches[669] && stage < 4 ? true : false
    end

    # True while the assist is on, the statues are being placed and this one is off its plate.
    def self.placing?(statue)
      PokeAccess::Puzzles.assist? && live? && stage == 1 && PokeAccess::RejuvPushLegs.at(statue[0]) != statue[2]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  trials = PokeAccess::RejuvTrials
  mechanic(:state, 397, :part => :statues) do
    auto
    trials::STATUES.each { |st| name st[0], st[4], :when => lambda { |_ev| trials.live? && trials.stage == 1 } }
    trials::PLATES.each { |id, label| name id, label, :when => lambda { |_ev| trials.live? } }
    arrival_hint lambda { trials.live? && trials.stage <= 1 ? :rj_trials_rule : nil }
    phase lambda { PokeAccess::Puzzles.assist? && trials.live? && trials.stage == 0 },
          :hint => :rj_trials_panel_hint, :hidden => right_way(54)
    trials::STATUES.each do |st|
      phase lambda { trials.placing?(st) },
            :hint => lambda { PokeAccess::RejuvPushLegs.hint(st, :rj_trials_reset_hint) },
            :track => { :event => st[0], :label => st[4], :goal => [st[2][0], st[2][1], st[2][0], st[2][1]],
                        :goal_label => st[5] }
    end
    phase lambda { PokeAccess::Puzzles.assist? && trials.live? && trials.stage >= 2 },
          :hint => :rj_trials_tangrowth_hint
    sent_back :rj_trials_time_up, :to => [14, 58], :from => trials::ROOM
    solved { trials.stage >= 4 }
  end
end

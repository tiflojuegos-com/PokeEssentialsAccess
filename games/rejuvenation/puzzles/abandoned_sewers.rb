# The Abandoned Sewers' generator (map 55): three graphic-less reset monitors, each asking to switch on: 1 (event 12)
# adds 10 to variable 31, 2 (event 11) adds 2, 3 (event 13) adds 6. At 18 the reset works (switch 501); a monitor's
# refusal puts every monitor off again.
module PokeAccess
  module RejuvSewers
    # Monitor number => [event, switch it sets].
    MONITORS = { 1 => [12, 952], 2 => [11, 953], 3 => [13, 951] }

    # True while monitor n is on.
    def self.on?(n)
      $game_switches[MONITORS[n][1]] ? true : false
    end

    # The monitor to use next: 2 if it went first (it has to go off again), else 3, 1 and 2 last.
    def self.next_monitor
      return 2 if on?(2)
      return 3 unless on?(3)
      return 1 unless on?(1)
      2
    end

    # True while the monitors answer and the reset is still to do.
    def self.live?
      $game_variables[659].to_i >= 16 && !$game_switches[501]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  sewers = PokeAccess::RejuvSewers
  mechanic(:state, 55, :part => :generator) do
    auto
    sewers::MONITORS.each do |n, (ev, _sw)|
      name ev, [:rj_sewer_monitor, { :n => n }]
      right_choice ev, :takes => lambda { sewers.next_monitor == n ? { :var => 31 } : nil }
    end
    phase lambda { PokeAccess::Puzzles.assist? && sewers.live? && sewers.on?(2) },
          :hint => :rj_sewer_undo, :hidden => right_way(11)
    [3, 1, 2].each do |n|
      phase lambda { PokeAccess::Puzzles.assist? && sewers.live? && !sewers.on?(2) && sewers.next_monitor == n },
            :hint => [:rj_sewer_next, { :n => n }], :hidden => right_way(sewers::MONITORS[n][0])
    end
    solved { $game_switches[501] }
  end
end

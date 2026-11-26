# The Darchlight Mirror machine of the Darchlight Labs (map 365): fragments (event 6) set switch 1031; the dispenser
# (event 2) takes them and starts a 30 second timer (variable 523 at 5). The monitor (event 21), used facing up, makes
# the mirror only while the timer reads 15: above that it does nothing, below it the machine resets.
module PokeAccess
  module RejuvDarchlightLabs
    # The whole seconds the game's timer has left, nil while it is stopped.
    def self.seconds
      sys = $game_system
      return nil unless sys && (sys.timer_working rescue false)
      units = (Object.const_get(:TIMER_UNITS) rescue nil) || (Graphics.frame_rate rescue 40)
      sys.timer.to_i / units.to_i
    end

    # True while the shard is in the machine.
    def self.heating?
      $game_variables[523].to_i == 5
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  labs = PokeAccess::RejuvDarchlightLabs
  mechanic(:state, 365, :part => :mirror) do
    auto
    name 6, :rj_darch_fragments, :when => lambda { |_ev| !$game_switches[1031] }
    name 2, :rj_darch_dispenser, :when => lambda { |_ev| $game_variables[523].to_i < 5 }
    name 21, :rj_darch_monitor, :when => lambda { |_ev| labs.heating? }
    phase lambda { PokeAccess::Puzzles.assist? && labs.heating? && labs.seconds == 15 }, :title => :rj_darch_now
    phase lambda { PokeAccess::Puzzles.assist? && labs.heating? }, :quiet => true, :hint => :rj_darch_hint
  end
end

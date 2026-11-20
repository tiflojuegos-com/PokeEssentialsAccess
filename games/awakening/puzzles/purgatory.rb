# The Gates of Hell's four lights (map 555), in the room's corners and drawn alike. The riddle of event 1 hides their
# order in its capitals: fire (39, 8), earth (7, 31), water (7, 8) and wind (39, 31). Each touch adds 1 to variable 385,
# and to variable 386 1, 2, 3 or 4 only as the next of that order, else it takes 1 off; at four touches the seal breaks
# (switch 710) when 386 reached 10, and the room starts over otherwise. The lights are named by their corner; with the
# puzzle assist, the next one to touch, or that the round is lost and ends with whatever touches are left.
module PokeAccess
  module AwakeningPurgatory
    # The lights in the riddle's order, as [event, name].
    ORDER = [[4, :awk_purg_light_ne], [3, :awk_purg_light_sw], [2, :awk_purg_light_nw], [5, :awk_purg_light_se]]
    # What variable 386 holds after each count of right touches.
    SCORE = [0, 1, 3, 6]

    # The step the round is at: the index of the light to touch next, :lost once a touch went wrong, nil when done.
    def self.step
      return nil if $game_switches[710]
      n = $game_variables[385].to_i
      return nil if n < 0 || n > 3
      $game_variables[386].to_i == SCORE[n] ? n : :lost
    end
  end
end

PokeAccess::Game.define("awakening") do
  purgatory = PokeAccess::AwakeningPurgatory
  mechanic(:state, 555) do
    auto
    purgatory::ORDER.each { |ev, label| name ev, label }
    purgatory::ORDER.each_with_index do |(_ev, label), k|
      phase lambda { PokeAccess::Puzzles.assist? && purgatory.step == k }, :quiet => true,
            :hint => lambda { [:awk_purg_next, { :name => PokeAccess::I18n.t(label) }] }
    end
    phase lambda { PokeAccess::Puzzles.assist? && purgatory.step == :lost }, :quiet => true, :hint => :awk_purg_lost
    solved { $game_switches[710] }
  end
end

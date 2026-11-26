# TargetBot's practice in Thistle Valley (map 691, from maps 684 or 744): twenty targets drawn as events, each broken at
# a touch and adding to variable 258, against the event timer the core reads. The count is the info key's while they
# stand (switch 290 "In Valley?" off); any other way in turns it on and leaves the twenty with no graphic (page 3).
module PokeAccess
  module AshenTargets
    MAP = 691
    VAR = 258
    TOTAL = 20
    IN_VALLEY = 290

    # Whether the target game is on: the targets drawn and some left.
    def self.live?
      !$game_switches[IN_VALLEY] && $game_variables[VAR].to_i < TOTAL
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  targets = PokeAccess::AshenTargets
  mechanic(:state, targets::MAP, :part => :targets) do
    auto
    count :afi_targets, :var => targets::VAR, :of => targets::TOTAL, :announce => false
    active { targets.live? }
  end
end

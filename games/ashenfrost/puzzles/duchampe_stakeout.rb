# Bouncer Stakeout in Duchampe Gardens (map 103): at variable 90 = 2 the Bouncer and Stantler (EV39, EV40) are gone, and
# the touch tile EV41 at (21,11), with no graphic, has Truffles follow the prints (90 to 3). The assist alone names it.
module PokeAccess
  module AshenStakeout
    MAP = 103
    TRAIL = 41
    STAGE = 90
    TRAILING = 2

    # Whether the prints wait to be followed.
    def self.waiting?
      $game_variables[STAGE].to_i == TRAILING
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  stakeout = PokeAccess::AshenStakeout
  mechanic(:state, stakeout::MAP, :part => :aff_stakeout) do
    auto
    spot :event => stakeout::TRAIL, :label => :aff_trail, :onto => true, :assist => true, :when => lambda { stakeout.waiting? }
    hint :aff_trail_hint
    active { PokeAccess::Puzzles.assist? && stakeout.waiting? }
    solved(nil, :quiet => true) { $game_variables[stakeout::STAGE].to_i > stakeout::TRAILING }
  end
end

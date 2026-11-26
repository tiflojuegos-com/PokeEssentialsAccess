# Ashen Frost's ballroom door on the Flores Mansion's ground floor (map 645, EV23): it opens with switch 259, which only
# the second tape sets, watched on the basement TV (map 650). The assist tells the way once the pool puzzle's ladder
# (switch 258) stands.
module PokeAccess
  module AshenBallroom
    MAP = 645
    LADDER = 258
    UNLOCKED = 259

    # Whether the ladder stands and the ballroom door is still shut.
    def self.waiting?
      $game_switches[LADDER] && !$game_switches[UNLOCKED] ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  ballroom = PokeAccess::AshenBallroom
  mechanic(:state, ballroom::MAP, :part => :afe_ballroom) do
    auto
    active { PokeAccess::Puzzles.assist? && ballroom.waiting? }
    phase lambda { ballroom.waiting? }, :hint => :afe_ballroom_hint
  end
end

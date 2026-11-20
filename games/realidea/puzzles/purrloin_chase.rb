# The Purrloin of Route 2 (map 8), while its quest runs (switch 82, until the bracelet is back, 80): spoken to from the
# tile by one of its corners it runs to another, and it is caught from the tile right of the north-west corner (33, 7)
# while switch 79 is on. Four piles of twigs (terrain 18) startle it: three set 79 off, the north-west one sets it on.
module PokeAccess
  module RealideaPurrloin
    MAP = 8
    CAT = 1
    QUIET_TWIGS = [13, 14, 15, 16]
    LOUD_TWIGS = [2, 3, 4, 9, 8, 10, 11, 12, 17, 19, 20, 21]
    TWIGS = QUIET_TWIGS.dup.concat(LOUD_TWIGS)
    # The side to speak to the cat from, by the corner it stands on, so that it runs towards the north-west one.
    SIDES = { [42, 14] => :rea_purrloin_from_left, [42, 7] => :rea_purrloin_from_below, [32, 14] => :rea_purrloin_from_right }
    CORNER = [32, 7]

    # True while the quest is on and the bracelet not yet back.
    def self.running?
      $game_switches[82] && !$game_switches[80] ? true : false
    end

    # The name of a pile of twigs; with the assist, the one that does not startle the cat is told apart.
    def self.twigs(ev)
      lambda { PokeAccess::Puzzles.assist? && QUIET_TWIGS.include?(ev.id) ? :rea_purrloin_twigs_quiet : :rea_purrloin_twigs }
    end

    # What the puzzle assist says: the quiet twigs while switch 79 is off, else the side to speak to the cat from.
    def self.hint
      return :rea_purrloin_hint_twigs unless $game_switches[79]
      cat = $game_map.events[CAT]
      return nil unless cat
      at = [cat.x, cat.y]
      return :rea_purrloin_hint_catch if at == CORNER
      SIDES[at] || :rea_purrloin_hint_corner
    end
  end
end

PokeAccess::Game.define("realidea") do
  cat = PokeAccess::RealideaPurrloin
  mechanic(:state, cat::MAP) do
    auto
    name cat::TWIGS, lambda { |ev| cat.twigs(ev) }, :grouped => true, :when => lambda { |_ev| cat.running? }
    avoid cat::TWIGS
    active { cat.running? && PokeAccess::Puzzles.assist? }
    solved { $game_switches[80] }
    hint lambda { cat.hint }
  end
end

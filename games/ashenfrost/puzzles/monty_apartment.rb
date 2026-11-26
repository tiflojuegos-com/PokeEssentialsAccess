# Monty's Apartment (map 214, Case Four): variable 59 counts what has been looked at, and the present (EV12, through
# EV13) waits for seven: the board (EV4, EV5, counted once), five sparkles (EV6 to EV10) and the bin with no sparkle
# (EV3). Monty's letter later sets the count to 8, so it is held at seven.
module PokeAccess
  module AshenMonty
    MAP = 214
    SEEN = 59
    TOTAL = 7
    BIN = 3

    # What has been looked at, held at the total.
    def self.seen
      [$game_variables[SEEN].to_i, TOTAL].min
    end

    # Whether the bin is still to look at.
    def self.bin_left?
      !$game_self_switches[[MAP, BIN, "A"]]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  monty = PokeAccess::AshenMonty
  mechanic(:state, monty::MAP, :part => :clues) do
    auto
    name [4, 5], :afh_monty_board, :grouped => true
    name monty::BIN, :afh_monty_bin, :assist => true, :when => lambda { |_ev| monty.bin_left? }
    count :afh_monty_count, :value => lambda { monty.seen }, :of => monty::TOTAL, :assist => true
    solved(nil, :quiet => true) { monty.seen >= monty::TOTAL }
  end
end

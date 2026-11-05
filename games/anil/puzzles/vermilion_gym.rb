# Vermilion's gym (map 56): an electric barrier before the leader goes off when the switches under two of fifteen bins are
# pressed, the bins in three rows of five. EV31 deals the first bin (V126) and one beside it (V128), numbered in reading
# order; V129 is the bin pressed last and V130 how far the search is: 1 after the first bin, 2 after the second. Pressing
# any other bin with the first found deals them again.
module PokeAccess
  module AnilBins
    MAP = 56
    BINS = 16..30
    FIRST_X = 4
    FIRST_Y = 14
    STEP = 3
    COLUMNS = 5

    # The bin's number in reading order, from 1: what V126, V128 and V129 hold for it.
    def self.number_of(ev)
      ((ev.y - FIRST_Y) / STEP) * COLUMNS + (ev.x - FIRST_X) / STEP + 1
    end

    # Whether the bin holds a switch now.
    def self.switch?(ev)
      [$game_variables[126], $game_variables[128]].include?(number_of(ev))
    end

    # The bin's name: its row and column; with the assist, also whether it holds a switch.
    def self.label(ev)
      n = number_of(ev) - 1
      key = PokeAccess::Puzzles.assist? && switch?(ev) ? :anil_bin_switch : :anil_bin
      [key, { :r => n / COLUMNS + 1, :c => n % COLUMNS + 1 }]
    end
  end
end

PokeAccess::Game.define("anil") do
  bins = PokeAccess::AnilBins
  mechanic(:state, bins::MAP) do
    auto
    name bins::BINS, lambda { |ev| bins.label(ev) }
    obstacle(/rayosBarrera/i, :label => :anil_bin_barrier)
    count :anil_bin_found, :var => 130, :of => 2
    solved(nil) { $game_variables[130].to_i >= 2 }
    arrival_hint :anil_bin_rule
  end
end

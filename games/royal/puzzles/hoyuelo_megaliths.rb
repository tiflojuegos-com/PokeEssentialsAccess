# Hoyuelo's megaliths (map 116): five stones with no sprite, named "Papelera" in the editor, each with a type engraved.
# Read Grass (EV73), Water (EV74) and Fire (EV76) in that order, V76 counting the first two, and the last one digs up an
# Expert Belt once (its self switch A); Flying (EV72) and Dark (EV75), or any stone out of order, put V76 back to 0.
module PokeAccess
  module RoyalMegaliths
    MAP = 116
    STONES = 72..76
    ORDER = { 73 => 1, 74 => 2, 76 => 3 }
    LAST = 76

    # A megalith's name; with the assist, the three of the order say their place in it.
    def self.label(ev)
      return :royal_megalith unless PokeAccess::Puzzles.assist? && ORDER[ev.id]
      [:royal_megalith_order, { :n => ORDER[ev.id] }]
    end
  end
end

PokeAccess::Game.define("royal") do
  stones = PokeAccess::RoyalMegaliths
  mechanic(:state, stones::MAP) do
    auto
    name stones::STONES, lambda { |ev| stones.label(ev) }
    hint :royal_megalith_hint
    solved(nil) { $game_self_switches[[stones::MAP, stones::LAST, "A"]] }
  end
end

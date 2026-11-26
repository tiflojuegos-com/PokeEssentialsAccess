# The blue lanterns of Northallow Grove (map 733): five with no graphic (events 36, 40, 44, 48 and 52), each adding one
# to variable 308 and fading back after a while (page 3). With all five lit, event 56 turns 308 to 6 and opens the
# portal (event 58). ORDER is a short round from the arrival, by the south-east, ending at the portal.
module PokeAccess
  module AshenBlueLanterns
    MAP = 733
    LANTERNS = [36, 40, 44, 48, 52]
    ORDER = [36, 40, 48, 52, 44]

    # Whether a lantern is lit now.
    def self.lit?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # The lanterns lit together, at most five.
    def self.count
      [$game_variables[308].to_i, 5].min
    end

    # True while the portal waits for the five.
    def self.open?
      $game_variables[308].to_i < 5
    end

    # The lantern of the round to light next, as [x, y]; nil once all are lit.
    def self.next_tile
      id = ORDER.find { |e| !lit?(e) }
      ev = id && ($game_map.events[id] rescue nil)
      ev ? [ev.x, ev.y] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  bl = PokeAccess::AshenBlueLanterns
  mechanic(:state, bl::MAP, :part => :blue_lanterns) do
    auto
    name bl::LANTERNS, :afg_nl_lantern, :when => lambda { |ev| bl.open? && !bl.lit?(ev.id) }
    count :afg_nl_lit, :value => lambda { bl.count }, :of => 5, :reset => false
    phase lambda { PokeAccess::Puzzles.assist? && bl.open? }, :hint => :afg_nl_hint,
                                                              :spots => [{ :at => lambda { bl.next_tile }, :label => :afg_nl_next }]
    phase lambda { bl.open? }
    solved(nil, :quiet => true) { !bl.open? }
  end
end

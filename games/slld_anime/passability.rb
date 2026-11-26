# Anime Chronicles' player passability is Advanced Items' Game_Map#playerPassable? (02_Terrain Tag Plus.rb), which reads
# the map's tiles, tileset, events and the player's state; Following Pokemon EX only stops other events. While Budcheep
# flies over Serpentine City (map 15, switch 445) the player has through on, which the probe lends off (SlldFlight).
module PokeAccess
  # Budcheep's flight: the Birdkeeper (event 83) and common event 23 toggle the player's through with switch 445, and
  # event 87 sends the player back from columns 14 and 50 and rows 4 and 35. While the mod asks, a step is open only
  # into the box between them.
  module SlldFlight
    MAP = 15
    SWITCH = 445
    COLS = 15..49
    ROWS = 5..34

    # True while the player flies as Budcheep.
    def self.on?
      ($game_switches[SWITCH] && $game_map && $game_map.map_id == MAP) ? true : false
    end

    # True when a step from (x, y) toward d ends inside the box.
    def self.open?(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      dd && COLS.include?(x + dd[0]) && ROWS.include?(y + dd[1]) ? true : false
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  flight = PokeAccess::SlldFlight
  probe = PokeAccess::World::Probe
  probe.mode_reader { flight.on? }
  plain_passability
  around("Game_Player", :passable?) do |_pl, nxt, args|
    probe.quiet? && flight.on? ? flight.open?(args[0], args[1], args[2]) : nxt.call
  end
end

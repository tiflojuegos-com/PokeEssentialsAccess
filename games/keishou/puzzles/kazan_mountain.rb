# Kazan Mountain (maps 123, 126, 127, 128 and 130): a step budget like a safari's. VolcanoState holds the steps left, set from
# var 67 by the events that enter each area; the pause menu shows them and the game sends the player back when they run out.
# Its boulder sockets, read by parallel sensors, are named on each map, the golden rocks counted as they break, and the
# cracked ice of map 127 named tile by tile, with the fall to map 130 told. With the puzzle assist the routes over the
# ice keep to the way with the fewest whole tiles, the one its hint gives; a cracked tile, a transfer, they never cross.
module PokeAccess
  module KeishouVolcano
    LOW = 15
    MAPS = [123, 126, 127, 128, 130]

    # True while a volcano run is on.
    def self.running?
      (pbInVolcano? rescue false) ? true : false
    end

    # The steps left.
    def self.steps
      pbVolcanoState.stepsV.to_i
    end

    # The info key's line: the steps left, and with the assist a warning when they are few.
    def self.line
      line = PokeAccess::I18n.t(:ks_volcano_steps, :n => steps)
      return line unless PokeAccess::Puzzles.assist? && steps <= LOW
      PokeAccess.sentences([line, PokeAccess::I18n.t(:ks_volcano_low)])
    end

    # The cracked ice before the north stair of map 127: each tile holds one step, its self switch A on once cracked, and a
    # step on a cracked one drops the player to map 130 (the landings in ICE_LANDINGS) with every tile whole again.
    ICE = [14] + (25..34).to_a
    ICE_LANDINGS = [11, 16, 9, 16]
    # The presses of more a whole ice tile counts as for the assisted routes: more than the two the hint's way north
    # takes over the shortest one, which crosses one tile more.
    ICE_COST = 4

    # The name of a tile of the ice field, whole or cracked.
    def self.ice_name(ev)
      $game_self_switches[[127, ev.id, "A"]] ? :ks_o_ice_cracked : :ks_o_ice_thin
    end

    # The id of the ice tile on (x, y) of map 127, or nil.
    def self.ice_at(x, y)
      ICE.find { |id| (ev = $game_map.events[id]) && ev.x == x && ev.y == y }
    end

    # The presses of more a step onto (x, y) costs: ICE_COST on a whole ice tile, nil elsewhere.
    def self.ice_cost(x, y)
      id = ice_at(x, y)
      id && !$game_self_switches[[127, id, "A"]] ? ICE_COST : nil
    end

    # Boulder sockets each read by a sensor, as map => [[sensor, x, y], ...]: the sensor's self switch A is on once the
    # boulder rests there. On 127 either of the sensors 19 and 21 takes the socket (38, 15) and sets the other.
    SOCKETS = {
      123 => [[5, 13, 21], [6, 12, 41], [7, 32, 42]],
      126 => [[22, 23, 34]],
      127 => [[19, 38, 15], [22, 33, 10], [24, 13, 19], [78, 34, 41]],
      128 => [[7, 23, 45]]
    }
    # The groups of three golden rocks whose last break opens a cold spring, as map => the variables that count them.
    GOLD_ROCKS = { 126 => [50], 127 => [51, 52] }
  end
end

PokeAccess::Game.define("keishou") do
  volcano = PokeAccess::KeishouVolcano
  mechanic(:state, volcano::MAPS) do
    auto
    active { PokeAccess::KeishouVolcano.running? }
    info { PokeAccess::KeishouVolcano.line }
    arrival_hint :ks_volcano_rule, :once => true
  end

  volcano::SOCKETS.each do |map, sockets|
    mechanic(:state, map, :part => :rocks) do
      auto
      sockets.each do |sensor, x, y|
        spot :at => [x, y], :label => :ks_o_boulder_goal, :onto => true, :when => lambda { !$game_self_switches[[map, sensor, "A"]] }
      end
      (volcano::GOLD_ROCKS[map] || []).each { |var| count :ks_o_gold_rocks, :var => var, :of => 3 }
      active { false }
    end
  end

  ice = { :maps => [127], :tiles => lambda { |x, y| volcano.ice_at(x, y) ? true : false }, :assist => true }
  tile_cost(ice) { |x, y| volcano.ice_cost(x, y) }
  by_ice = at(18, 34, 8, 24)
  mechanic(:state, 127, :part => :ice) do
    auto
    name volcano::ICE, lambda { |ev| PokeAccess::KeishouVolcano.ice_name(ev) }
    volcano::ICE.each { |id| watch :self => [id, "A"], :say => :ks_o_ice_cracks }
    arrival_hint lambda { by_ice.call ? :ks_o_ice_rule : nil }, :once => true
    hint :ks_o_ice_hint
    active { by_ice.call }
  end

  mechanic(:state, 130, :part => :ice) do
    auto
    sent_back :ks_o_ice_fall, :maps => [127], :to => volcano::ICE_LANDINGS
  end
end

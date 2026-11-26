# Ashen Frost's rooms of ice tiles stepped on once: Amontillado Cave (map 559, variable 170) and Mordecai's Tunnel (map
# 581, variable 186). A first step cracks a tile (self switch A); a step on a cracked one resets the room through its
# control event (38, 68). The assist follows an order of ORDERS that covers every tile.
module PokeAccess
  module AshenIceTiles
    # Per map: the variable, tile ids, control event, landing, the box (x0, x1, y0, y1) where the rule is said, :via
    # (the floor tile an order steps over) and :orders.
    ROOMS = {
      559 => {
        :var => 170, :total => 37, :ids => (1..37).to_a, :control => 38, :landing => [12, 16], :box => [6, 15, 8, 16],
        :orders => [
          [[8, 14], [8, 13], [8, 12], [8, 11], [8, 10], [9, 10], [10, 10], [11, 10], [12, 10], [13, 10], [14, 10], [15, 10],
           [15, 11], [15, 12], [14, 12], [13, 12], [13, 11], [12, 11], [11, 11], [10, 11], [9, 11], [9, 12], [10, 12],
           [11, 12], [11, 13], [10, 13], [9, 13], [9, 14], [10, 14], [11, 14], [12, 14], [13, 14], [13, 13], [14, 13],
           [15, 13], [15, 14], [14, 14]],
          [[10, 14], [9, 14], [8, 14], [8, 13], [8, 12], [8, 11], [8, 10], [9, 10], [10, 10], [11, 10], [12, 10], [13, 10],
           [14, 10], [15, 10], [15, 11], [15, 12], [14, 12], [13, 12], [13, 11], [12, 11], [11, 11], [10, 11], [9, 11],
           [9, 12], [9, 13], [10, 13], [10, 12], [11, 12], [11, 13], [11, 14], [12, 14], [13, 14], [13, 13], [14, 13],
           [15, 13], [15, 14], [14, 14]],
          [[12, 14], [11, 14], [11, 13], [11, 12], [11, 11], [12, 11], [13, 11], [13, 12], [14, 12], [14, 13], [13, 13],
           [13, 14], [14, 14], [15, 14], [15, 13], [15, 12], [15, 11], [15, 10], [14, 10], [13, 10], [12, 10], [11, 10],
           [10, 10], [9, 10], [8, 10], [8, 11], [9, 11], [10, 11], [10, 12], [9, 12], [8, 12], [8, 13], [8, 14], [9, 14],
           [9, 13], [10, 13], [10, 14]],
          [[14, 14], [15, 14], [15, 13], [15, 12], [15, 11], [15, 10], [14, 10], [13, 10], [12, 10], [11, 10], [10, 10],
           [9, 10], [8, 10], [8, 11], [9, 11], [10, 11], [11, 11], [12, 11], [13, 11], [13, 12], [14, 12], [14, 13],
           [13, 13], [13, 14], [12, 14], [11, 14], [11, 13], [11, 12], [10, 12], [9, 12], [8, 12], [8, 13], [8, 14],
           [9, 14], [9, 13], [10, 13], [10, 14]]
        ]
      },
      581 => {
        :var => 186, :total => 58, :ids => (10..67).to_a, :control => 68, :landing => [9, 28], :box => [6, 13, 29, 39],
        :via => { [13, 38] => [13, 39] },
        :orders => [
          [[7, 30], [7, 31], [7, 32], [6, 32], [6, 33], [6, 34], [7, 34], [7, 33], [8, 33], [8, 34], [8, 35], [7, 35],
           [7, 36], [7, 37], [7, 38], [8, 38], [8, 39], [9, 39], [9, 38], [9, 37], [8, 37], [8, 36], [9, 36], [9, 35],
           [9, 34], [9, 33], [9, 32], [9, 31], [8, 31], [8, 30], [9, 30], [10, 30], [11, 30], [11, 31], [10, 31],
           [10, 32], [11, 32], [11, 33], [10, 33], [10, 34], [10, 35], [10, 36], [10, 37], [10, 38], [10, 39], [11, 39],
           [11, 38], [12, 38], [12, 39], [13, 38], [13, 37], [12, 37], [12, 36], [11, 36], [11, 35], [11, 34], [12, 34],
           [12, 35]]
        ]
      }
    }

    # Whether the room's rock has moved: every tile cracked, which the control event seals with its self switch A.
    def self.done?(map)
      room = ROOMS[map]
      $game_variables[room[:var]].to_i >= room[:total] || $game_self_switches[[map, room[:control], "A"]] ? true : false
    end

    # The tiles of the room cracked now, as [x, y].
    def self.cracked(map)
      ROOMS[map][:ids].map do |id|
        ev = $game_map.events[id]
        ev && $game_self_switches[[map, id, "A"]] ? [ev.x, ev.y] : nil
      end.compact
    end

    # The tile to step on next along an order the cracked tiles begin, or nil when none fits.
    def self.next_tile(map)
      done = cracked(map).sort
      ROOMS[map][:orders].each do |order|
        return order[done.size] if order[0, done.size].sort == done
      end
      nil
    end

    # The assist's line: where the next tile lies, by way of the floor tile an order steps over, or how to start over.
    def self.hint(map)
      tile = next_tile(map)
      return :afh_ice_restart unless tile
      via = (ROOMS[map][:via] || {})[tile]
      return [:afh_ice_via, { :first => offset(via), :then => offset(tile, via) }] if via && via != player
      [:afh_ice_next, { :place => offset(tile) }]
    end

    # The player's tile.
    def self.player
      [$game_player.x, $game_player.y]
    end

    # Where a tile lies from another, the player's by default, in words.
    def self.offset(tile, from = player)
      phrase = PokeAccess::Puzzles.offset_phrase(tile[0] - from[0], tile[1] - from[1])
      phrase.empty? ? PokeAccess::I18n.t(:afh_ice_here) : phrase
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  ice = PokeAccess::AshenIceTiles
  ice::ROOMS.each do |map, room|
    mechanic(:grid, map, :part => :ice_tiles) do
      auto
      tiles room[:ids], :self => "A", :label => :afh_ice_tile, :count => :afh_ice_count,
                        :words => { true => :afh_ice_cracked, false => :afh_ice_whole }
      solved { ice.done?(map) }
    end

    mechanic(:state, map, :part => :ice_order) do
      auto
      near = at(*room[:box])
      phase lambda { near.call && !ice.done?(map) }, :title => :afh_ice_rule, :hint => lambda { ice.hint(map) }
      phase lambda { PokeAccess::Puzzles.assist? && !ice.done?(map) }, :quiet => true, :hint => lambda { ice.hint(map) }
      sent_back :afh_ice_reset, :to => room[:landing], :events => room[:ids] + [room[:control]]
      solved { ice.done?(map) }
    end
  end
end

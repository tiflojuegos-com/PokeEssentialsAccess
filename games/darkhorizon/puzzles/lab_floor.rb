# Shadow Lab's floor of 53 hidden tiles (map 99, the corridor at x 67 to 77, y 12 to 20). Each tile (events 62, 65, 67 to 113 and
# 115 to 118) lights on its first step and adds to variable 28; a lit one sends the player back to (67, 15) and puts the count
# to 0, and so does the start tile (event 66, at (67, 16)) with the count above 0, with no move. At 53 the laser (event 61)
# goes. The route is searched from where the player stands over the tiles still dark.
module PokeAccess
  module DHTileFloor
    MAP = 99
    TILES = [62, 65] + (67..113).to_a + (115..118).to_a
    START = [67, 16]
    BACK = [67, 15]
    BOX = [67, 77, 12, 21]
    STEPS = [[0, -1, :dh_o_dir_up], [0, 1, :dh_o_dir_down], [-1, 0, :dh_o_dir_left], [1, 0, :dh_o_dir_right]]

    # Why the count fell: a repeated tile when the player stands at the corridor's entrance, else a restart from the start tile.
    def self.reset_label
      [$game_player.x, $game_player.y] == BACK ? :dh_o_tiles_back : :dh_o_tiles_reset
    end

    # The tile events' places, as {[x, y] => id}.
    def self.cells
      TILES.inject({}) do |all, id|
        ev = $game_map.events[id]
        all[[ev.x, ev.y]] = id if ev
        all
      end
    end

    # True when the tile's event has been stepped on.
    def self.lit?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # The tiles not yet lit, as {[x, y] => true}.
    def self.dark
      cells.inject({}) do |all, (xy, id)|
        all[xy] = true unless lit?(id)
        all
      end
    end

    # The places next to a spot.
    def self.around(xy)
      STEPS.map { |dx, dy, _key| [xy[0] + dx, xy[1] + dy] }
    end

    # True when every dark tile can still be reached from c through dark tiles.
    def self.joined?(c, dark)
      seen = {}
      queue = around(c).select { |n| dark[n] }
      queue.each { |n| seen[n] = true }
      until queue.empty?
        nxt = queue.shift
        around(nxt).each do |n|
          next if !dark[n] || seen[n]
          seen[n] = true
          queue.push(n)
        end
      end
      seen.length == dark.length
    end

    # The dark tiles that would have one way in or out when the player stands on c.
    def self.ends(c, dark)
      dark.keys.select { |n| (around(n).select { |m| dark[m] || m == c }).length <= 1 }.length
    end

    # The tiles to step on, in order, to light all the dark ones from pos; nil when no walk does it.
    def self.route(pos, dark)
      return [] if dark.empty?
      options = around(pos).select { |n| dark[n] }
      options = options.sort_by { |n| around(n).select { |m| dark[m] }.length }
      options.each do |c|
        dark.delete(c)
        rest = joined?(c, dark) && ends(c, dark) <= 1 ? route(c, dark) : nil
        dark[c] = true
        return [c] + rest if rest
      end
      nil
    end

    # The key of the step from a to b.
    def self.direction(a, b)
      STEPS.find { |dx, dy, _key| a[0] + dx == b[0] && a[1] + dy == b[1] }[2]
    end

    # The directions, as words, of the lit tiles next to a spot.
    def self.lit_around(xy)
      places = cells
      STEPS.select { |dx, dy, _key| (id = places[[xy[0] + dx, xy[1] + dy]]) && lit?(id) }.map { |_dx, _dy, key| PokeAccess::I18n.t(key) }
    end

    # What the info key says of the tiles around the player: which sides have a lit one.
    def self.near_line
      found = lit_around([$game_player.x, $game_player.y])
      return PokeAccess::I18n.t(:dh_o_tiles_near_none) if found.empty?
      PokeAccess::I18n.t(:dh_o_tiles_near, :dirs => found.join(", "))
    end

    # True once the player has stood in the corridor during this visit to the map, so its rule is said once per visit.
    def self.visited?(inside)
      events = $game_map.events
      unless @visit.equal?(events)
        @visit = events
        @inside = false
      end
      @inside ||= inside
    end

    # True when the player is on the way in: the start tile or one already lit.
    def self.on_floor?(xy)
      xy == START || (cells[xy] && lit?(cells[xy]))
    end

    # The hint: the next step of a route over what is dark, or where to go when the player is off the tiles.
    def self.hint
      t = PokeAccess::I18n
      pos = [$game_player.x, $game_player.y]
      dark = dark()
      return t.t(:dh_o_tiles_start) if !on_floor?(pos) && dark.length == TILES.length
      return t.t(:dh_o_tiles_off) unless on_floor?(pos)
      steps = route(pos, dark)
      return t.t(:dh_o_tiles_stuck) unless steps
      t.t(:dh_o_tiles_next, :dir => t.t(direction(pos, steps.first)), :left => steps.length)
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  mechanic(:state, PokeAccess::DHTileFloor::MAP, :part => :tiles) do
    auto
    not_control PokeAccess::DHTileFloor::TILES + [66]
    name 66, :dh_o_tiles_start_name
    name 61, :dh_o_laser, :when => lambda { |_ev| !$game_switches[146] }
    count :dh_o_tiles_count, :var => 28, :of => PokeAccess::DHTileFloor::TILES.length, :reset => lambda { PokeAccess::DHTileFloor.reset_label }
    corridor = at(*PokeAccess::DHTileFloor::BOX)
    phase lambda { PokeAccess::DHTileFloor.visited?(corridor.call) && !$game_switches[146] }, :title => :dh_o_tiles_rule,
          :hint => lambda { PokeAccess::DHTileFloor.hint }
    solved { $game_switches[146] }
  end

  mechanic(:state, PokeAccess::DHTileFloor::MAP, :part => :near) do
    auto
    corridor = at(*PokeAccess::DHTileFloor::BOX)
    info { PokeAccess::DHTileFloor.near_line }
    active { corridor.call && !$game_switches[146] }
  end
end

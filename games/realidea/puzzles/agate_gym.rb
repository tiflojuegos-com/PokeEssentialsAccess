# The gym of Agate City (maps 118, 120, 121 and 123): the white floor (terrain 24) of each room turns black as it is
# stepped on, and the room is done by stepping on every white tile once; any step off the floor, or on a black tile, resets
# the room, but for the step after the last white tile, which finishes it. Variable 67 counts the black tiles and the door
# of the room opens (its self switch A) when it is done. ROUTES holds, per room, its door and one walk over all its white
# tiles found by search: its first tile, its steps (U, D, L, R) and the number of white tiles, the one the game checks.
module PokeAccess
  module RealideaAgate
    VAR = 67
    # The terrain tag of the white floor, and the tile a black one wears.
    WHITE = 24
    BLACK_TILE = 392
    # How many legs of the route the assist says at a time.
    SAID = 6
    ROUTES = {
      118 => { :door => 4, :start => [10, 14], :total => 55, :steps => "RRRUULUURUULLDDDDDLUUUUULLDRDDDDDLULUURULLUULDDDDDDRUU" },
      120 => { :door => 5, :start => [9, 14], :total => 52, :steps => "RRRRULLURUUUULDDDLUUULDDDDDLDLLUUULURULURRRDDLDRDLD" },
      121 => { :door => 5, :start => [9, 14], :total => 63, :steps => "RRRRUUUUUULDDDDDLUUUUULDDDDDLUUUUULDDDDDDLUUUUUULLDRDLDRDDDLUU" },
      123 => { :door => 4, :start => [11, 16], :total => 106,
               :steps => "RRRURDRRUUUUUUUULDDDDDLDLUURULULDDDDLDLUURUULDLUURURRRRULLLLLLDDDDDRDDLULUUUUUULLLDDRRDLDRDDDLUULDDDRRRRR" }
    }
    MOVES = { "U" => [0, -1], "D" => [0, 1], "L" => [-1, 0], "R" => [1, 0] }
    WORDS = { "U" => :dir_up, "D" => :dir_down, "L" => :dir_left, "R" => :dir_right }
    STATES = { :white => :rea_agate_white, :black => :rea_agate_black, :out => :rea_agate_out }

    # The tiles of a room route, in the order they are stepped on.
    def self.tiles(route)
      x, y = route[:start]
      out = [[x, y]]
      route[:steps].split("").each do |c|
        x += MOVES[c][0]
        y += MOVES[c][1]
        out.push([x, y])
      end
      out
    end

    # Steps grouped by direction: [[letter, how many in a row], ...].
    def self.legs(steps)
      out = []
      steps.split("").each do |c|
        if out.empty? || out[out.length - 1][0] != c
          out.push([c, 1])
        else
          out[out.length - 1][1] += 1
        end
      end
      out
    end

    # True once the door of a room has opened: the room is done.
    def self.open?(map)
      route = ROUTES[map]
      route && $game_self_switches[[map, route[:door], "A"]] ? true : false
    end

    # The tiles wearing the black tile, as {[x, y] => true}.
    def self.blacks
      out = {}
      $game_map.events.values.each { |ev| out[[ev.x, ev.y]] = true if ev.tile_id.to_i == BLACK_TILE }
      out
    end

    # What lies on a tile: white or black floor, or out of the white floor.
    def self.state(x, y, black_tiles)
      return :out unless PokeAccess::World::Engine.terrain_tag(x, y) == WHITE
      black_tiles[[x, y]] ? :black : :white
    end

    # How many white tiles are left to step on, read tile by tile.
    def self.whites_left(black_tiles)
      count = 0
      (0...$game_map.width).each do |x|
        (0...$game_map.height).each { |y| count += 1 if state(x, y, black_tiles) == :white }
      end
      count
    end

    # What the info key says: what lies to each side of the player and how many white tiles are left.
    def self.around
      black_tiles = blacks
      sides = PokeAccess::Puzzles::SIDES.map do |dx, dy, key|
        word = STATES[state($game_player.x + dx, $game_player.y + dy, black_tiles)]
        "#{PokeAccess::I18n.t(key)}: #{PokeAccess::I18n.t(word)}"
      end
      PokeAccess::I18n.t(:rea_agate_around, :sides => sides.join(", "), :n => whites_left(black_tiles))
    end

    # With the assist: where to begin while the room is untouched, else the next legs from the tile the player stands on,
    # else that the route is complete; nothing once the room is done.
    def self.hint
      map = $game_map.map_id
      route = ROUTES[map]
      return "" if route.nil? || open?(map)
      black = $game_variables[VAR].to_i
      return PokeAccess::I18n.t(:rea_agate_done) if black >= route[:total]
      here = [$game_player.x, $game_player.y]
      at = tiles(route).index(here)
      if black > 0 && at == black - 1
        said = legs(route[:steps][at..-1])[0, SAID].map { |c, n| "#{n} #{PokeAccess::I18n.t(WORDS[c])}" }
        return PokeAccess::I18n.t(:rea_agate_next, :legs => said.join(", "))
      end
      where = PokeAccess::Puzzles.offset_phrase(route[:start][0] - here[0], route[:start][1] - here[1])
      PokeAccess::I18n.t(:rea_agate_start, :where => where)
    end
  end
end

PokeAccess::Game.define("realidea") do
  PokeAccess::RealideaAgate::ROUTES.each_key do |map|
    mechanic(:state, map) do
      auto
      info { PokeAccess::RealideaAgate.around }
      arrival_hint :rea_agate_rule, :once => true
      hint lambda { PokeAccess::RealideaAgate.hint }
      solved { PokeAccess::RealideaAgate.open?(map) }
    end
  end
end

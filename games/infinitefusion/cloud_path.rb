# Mt. Moon Summit's cloud path (map 827, on Monday mornings: switch 1018), the way up to the harpist of Meloetta's band.
# A cloud (an event drawn with a cloud tile) gives way 36 game seconds, about half a real second, after it is stepped
# on, and whoever still stands on it falls back to the start (switch 1017, (38,30)); bumping into a spring (common
# event 90, or a jump of the player's own) jumps the player two tiles. On the start the rule is said once; each step
# says what lies on each side, or with the puzzle assist the next move of the shortest way up, the whole way at the
# start; ground away from the clouds says nothing, and the harpist's ledge says the end. Nothing is said while the
# player falls (common event 91 drops them four tiles); the fall is said in place of the teleport line.
module PokeAccess
  module IFCloudPath
    MAP = 827
    PATH = 1018
    FALLING = 1017
    START = [38, 30]
    GOAL = [27, 17]
    AREA = [18, 14, 42, 34]
    SPRING = 391
    SPRING_EVENT = 90
    CLOUDS = 8580..8639
    DIRS = [[8, 0, -1, :dir_up], [6, 1, 0, :dir_right], [2, 0, 1, :dir_down], [4, -1, 0, :dir_left]]

    @state = nil

    # Per-frame entry point: on each new tile of the path, its line.
    def self.poll
      return (@state = nil) unless $game_map && $game_map.map_id == MAP && $game_switches[PATH]
      @state ||= { :tile => nil, :told => false, :route => nil }
      return if $game_switches[FALLING]
      tile = [$game_player.x, $game_player.y]
      return if tile == @state[:tile]
      @state[:tile] = tile
      return unless inside?(tile[0], tile[1])
      index_events
      return at_start if tile == START
      return PokeAccess.speak(PokeAccess::I18n.t(:if_cloud_top), true) if tile == GOAL
      step(tile) if on_path?(tile) || on_route?(tile)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True for a tile of the cloud path's area.
    def self.inside?(x, y)
      x >= AREA[0] && y >= AREA[1] && x <= AREA[2] && y <= AREA[3]
    end

    # True on a cloud or beside a cloud or a spring: the tiles of the path, where each step is said.
    def self.on_path?(tile)
      return true if cloud?(tile[0], tile[1])
      DIRS.any? { |_d, dx, dy, _w| cloud?(tile[0] + dx, tile[1] + dy) || !jumps(tile[0] + dx, tile[1] + dy).empty? }
    end

    # True with the assist on a tile the way up kept for the player starts a move from.
    def self.on_route?(tile)
      way = @state[:route]
      PokeAccess::Puzzles.assist? && way && way.any? { |from, _d, _j| from == tile } ? true : false
    end

    # The map's events by their tile, taken once per new tile.
    def self.index_events
      @at = {}
      $game_map.events.each_value { |ev| @at[[ev.x, ev.y]] = ev }
    end

    # True for a cloud: an event drawn with a cloud tile that the player walks onto.
    def self.cloud?(x, y)
      ev = @at[[x, y]]
      ev && CLOUDS.include?(ev.tile_id.to_i) && ev.through ? true : false
    end

    # The jumps a spring at a tile gives the player (offsets from the player), empty for any other tile.
    def self.jumps(x, y)
      ev = @at[[x, y]]
      return [] unless ev && ev.tile_id.to_i == SPRING && !ev.through
      list = PokeAccess.ivar(ev, :@list)
      return [] unless list.is_a?(Array)
      out = []
      list.each do |c|
        p = (c.parameters rescue nil) || []
        out.concat([[0, -2], [2, 0], [0, 2], [-2, 0]]) if c.code == 117 && p[0] == SPRING_EVENT
        next unless c.code == 209 && p[0] == -1
        ((p[1].list rescue nil) || []).each { |m| out.push([m.parameters[0], m.parameters[1]]) if m.code == 14 }
      end
      out.uniq
    end

    # The moves from a tile as [x, y, direction, jump?]: a step onto any tile the player can walk to, or a jump over a
    # spring that throws that way onto a tile the player can land on.
    def self.moves(x, y)
      out = []
      DIRS.each do |d, dx, dy, _w|
        nx = x + dx
        ny = y + dy
        next unless inside?(nx, ny)
        if !jumps(nx, ny).empty?
          lx = x + 2 * dx
          ly = y + 2 * dy
          out.push([lx, ly, d, true]) if jumps(nx, ny).include?([2 * dx, 2 * dy]) && $game_player.passable?(lx, ly, 0)
        elsif $game_player.passable?(x, y, d)
          out.push([nx, ny, d, false])
        end
      end
      out
    end

    # The shortest way from a tile to the harpist's ledge as [direction, jump?] moves, or nil when there is none.
    def self.route(from)
      prev = { from => nil }
      queue = [from]
      until queue.empty?
        cur = queue.shift
        return unwind(prev, cur) if cur == GOAL
        moves(cur[0], cur[1]).each do |nx, ny, d, jump|
          key = [nx, ny]
          next if prev.key?(key)
          prev[key] = [cur, d, jump]
          queue.push(key)
        end
      end
      nil
    end

    # The moves that led to tile, first to last, with the tile each starts from.
    def self.unwind(prev, tile)
      out = []
      while (link = prev[tile])
        out.unshift([link[0], link[1], link[2]])
        tile = link[0]
      end
      out
    end

    # A move as said: a direction, or a jump that way.
    def self.move_word(d, jump)
      word = PokeAccess::I18n.t(DIRS.find { |dd, _x, _y, _w| dd == d }[3])
      jump ? PokeAccess::I18n.t(:if_cloud_jump, :dir => word) : word
    end

    # The whole way as runs: steps the same way counted, each jump on its own.
    def self.route_words(moves)
      runs = []
      moves.each do |_from, d, jump|
        last = runs[-1]
        if !jump && last && !last[2] && last[0] == d
          last[1] += 1
        else
          runs.push([d, 1, jump])
        end
      end
      words = runs.map do |d, n, jump|
        jump ? move_word(d, true) : PokeAccess::I18n.t(:if_cloud_walk, :dir => move_word(d, false), :n => n)
      end
      words.join(", ")
    end

    # The start: the rule once a visit, and with the assist the whole way up.
    def self.at_start
      parts = []
      parts.push(PokeAccess::I18n.t(:if_cloud_rule)) unless @state[:told]
      @state[:told] = true
      if PokeAccess::Puzzles.assist?
        @state[:route] = route(START)
        parts.push(PokeAccess::I18n.t(:if_cloud_route, :steps => route_words(@state[:route]))) if @state[:route]
      end
      PokeAccess.speak(PokeAccess.sentences(parts), false) unless parts.empty?
    end

    # A step on the path: with the assist the next move (the way kept while the player follows it), else each side.
    def self.step(tile)
      return PokeAccess.speak(sides(tile), true) unless PokeAccess::Puzzles.assist?
      way = @state[:route]
      way = @state[:route] = route(tile) unless way && way.any? { |from, _d, _j| from == tile }
      return unless way
      nxt = way.find { |from, _d, _j| from == tile }
      PokeAccess.speak(move_word(nxt[1], nxt[2]), true) if nxt
    end

    # What lies on each side of a tile: a cloud, a spring or plain ground, the sides the player cannot take left out.
    def self.sides(tile)
      parts = []
      DIRS.each do |d, dx, dy, w|
        x = tile[0] + dx
        y = tile[1] + dy
        what = if cloud?(x, y) then :if_cloud_cloud
               elsif !jumps(x, y).empty? then :if_cloud_spring
               elsif $game_player.passable?(tile[0], tile[1], d) then :if_cloud_floor
               end
        next unless what
        parts.push(PokeAccess::I18n.t(:if_cloud_side, :dir => PokeAccess::I18n.t(w), :what => PokeAccess::I18n.t(what)))
      end
      parts.join(", ")
    end

    # The fall's line for a teleport back to the start while falling, or nil.
    def self.fall_line(from, to)
      return nil unless from[2] == MAP && to == [START[0], START[1], MAP] && $game_switches[FALLING]
      PokeAccess::I18n.t(:if_cloud_fell)
    end
  end
end

PokeAccess::Locator.teleport_cause("if_cloud_path") { |from, to| PokeAccess::IFCloudPath.fall_line(from, to) }

PokeAccess::Game.define("infinitefusion") do
  poll_each_frame { PokeAccess::IFCloudPath.poll }
end

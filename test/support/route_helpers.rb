# Shared route spec helpers, loaded by the runner with the other support files.

# Route builders and brute-force oracles for the route tests.
module RouteHelpers
  # The route on foot to act on (x, y), or to stand on it with onto, as the planner walks it (Routes::Planner.walk); nil
  # for none.
  def walk_route(x, y, onto = false)
    PokeAccess::Routes::Planner.walk(x, y, onto).route
  end

  # Whether the regions on foot (Routes::Regions) tell the player can get to (x,y).
  def reached?(x, y)
    PokeAccess::Routes::Regions.foot.status([[x, y]])[0] == :yes
  end

  # A route replayed from (x,y) at bridge level lvl as the guide replays it (Routes::Moves.trace): one Step per press.
  def traced(x, y, lvl, path)
    PokeAccess::Routes::Moves.trace(x, y, lvl, path, PokeAccess::Pathfinder.replay_mode)
  end

  # A traced route (traced) as one [x, y, level] per Step, the shape the route specs pin.
  def spots(steps)
    steps.map { |s| [s.x, s.y, s.level] }
  end

  # The turns of a route of key presses: each press in another direction than the one before it.
  def route_turns(path)
    (1...path.length).count { |i| path[i] != path[i - 1] }
  end

  # The best [presses, turns] to each tile from the player by brute force: a Dijkstra over (tile, last direction) with the
  # style's order (the shortest: presses then turns; balanced: presses plus turns, then turns; the straightest: turns
  # then presses), over the same moves the search makes. { [x, y] => [presses, turns] }.
  def brute_best(style, mode)
    pf = PokeAccess::Pathfinder
    mv = PokeAccess::Routes::Moves
    key = lambda do |p, t|
      case style
      when :balanced then [p + t, t]
      when :straightest then [t, p]
      else [p, t]
      end
    end
    best = {}
    pf.searching do
      lvl = pf.bridge_level
      start = [$game_player.x, $game_player.y, nil]
      dist = { start => [0, 0] }
      open = [start]
      done = {}
      until open.empty?
        s = open.min_by { |st| key.call(*dist[st]) }
        open.delete(s)
        next if done[s]
        done[s] = true
        p, t = dist[s]
        tile = [s[0], s[1]]
        best[tile] = [p, t] if best[tile].nil? || (key.call(p, t) <=> key.call(*best[tile])) < 0
        PokeAccess::Routes::DIRS.each do |dir|
          n = mv.step(s[0], s[1], lvl, dir, mode)
          next if n.nil?
          ns = [n.x, n.y, dir[2]]
          np = p + n.presses
          nt = t + ((s[2] && s[2] != dir[2]) ? 1 : 0)
          old = dist[ns]
          next unless old.nil? || (key.call(np, nt) <=> key.call(*old)) < 0
          dist[ns] = [np, nt]
          open.push(ns)
        end
      end
    end
    best
  end

  # A grid with walls, ledges, ice (unless ice is false) and in-map warp pads at random, its player at the top left: the
  # first pad in the far corner, back to the top left; the others anywhere, to anywhere.
  def random_route_grid(seed, w, h, ice = true, pads = 1)
    World.clear_events
    $game_map.clear_ledges
    srand(seed)
    rows = (0...h).map { |y| (0...w).map { |x| (x == 0 || y == 0 || x == w - 1 || y == h - 1) ? "#" : (rand(5) == 0 ? "#" : ".") }.join }
    rows[1][1, 1] = "@"
    rows[1][2, 1] = "."
    rows[2][1, 1] = "."
    $game_map.load_grid(rows)
    ledges = []
    3.times do
      x = 2 + rand(w - 4)
      y = 2 + rand(h - 4)
      ledges.push([x, y, [2, 4, 6, 8][rand(4)]]) if rows[y][x, 1] == "."
    end
    ledges.each { |x, y, d| $game_map.place_ledge(x, y, d) }
    2.times do
      x = 1 + rand(w - 2)
      y = 1 + rand(h - 2)
      $game_map.set_terrain(x, y, 12) if rows[y][x, 1] == "." && !(x == 1 && y == 1)
    end if ice
    pads.times do |i|
      wx = i == 0 ? w - 2 : 1 + rand(w - 2)
      wy = i == 0 ? h - 2 : 1 + rand(h - 2)
      to = i == 0 ? [1, 2] : [1 + rand(w - 2), 1 + rand(h - 2)]
      next unless rows[wy][wx, 1] == "." && !(wx == 1 && wy == 1)
      World.touch(:id => 60 + i, :x => wx, :y => wy, :list => [TestCmd.new(201, [0, $game_map.map_id, to[0], to[1]])])
    end
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # The fewest transfers to another spot of the map on the way from the player to each tile they can reach, by brute
  # force: a breadth-first walk over the tiles with the moves of mode, a transfer counting one and any other move none.
  # { [x, y] => rooms }.
  def brute_rooms(mode)
    pf = PokeAccess::Pathfinder
    mv = PokeAccess::Routes::Moves
    rooms = {}
    pf.searching do
      lvl = pf.bridge_level
      start = [$game_player.x, $game_player.y]
      rooms[start] = 0
      cur = [start]
      d = 0
      until cur.empty?
        nxt = []
        i = 0
        while i < cur.length
          s = cur[i]
          i += 1
          next unless rooms[s] == d
          PokeAccess::Routes::DIRS.each do |dir|
            n = mv.step(s[0], s[1], lvl, dir, mode)
            next if n.nil?
            t = [n.x, n.y]
            nd = d + (n.warp ? 1 : 0)
            next if rooms[t] && rooms[t] <= nd
            rooms[t] = nd
            (nd == d ? cur : nxt).push(t)
          end
        end
        cur = nxt
        d += 1
      end
    end
    rooms
  end
end

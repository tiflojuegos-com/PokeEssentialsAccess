module PokeAccess
  # Pathfinder, the searches: A* over the moves move_target composes (binary heap, manhattan heuristic, ties to
  # fewer turns) with the frontier the path_algorithm setting picks, and the reachability flood over the same
  # moves.
  module Pathfinder
    # The search algorithms the route key can choose; all share the neighbour expansion and turn
    # tiebreak and differ only in the frontier.
    ALGORITHMS = [:astar, :weighted, :greedy, :dijkstra, :bfs, :dfs, :jps, :hpa]

    # The search algorithm from config (default :astar; an unknown value falls back to it).
    def self.path_algorithm
      a = (PokeAccess::Config.path_algorithm rescue nil)
      a = a.to_sym if a.respond_to?(:to_sym) && !a.to_s.empty?
      ALGORITHMS.include?(a) ? a : :astar
    end

    # The [g-weight, h-weight] of a heap algorithm's priority f = gw*g + hw*h (unused for bfs and dfs). Doubled so
    # weighted's 1.5x heuristic stays an integer ([2, 3]): a float weight would break the integer ordering.
    def self.algo_weights(algo)
      case algo
      when :weighted then [2, 3]
      when :greedy   then [0, 2]
      when :dijkstra then [2, 0]
      else [2, 2]
      end
    end

    # The arrival test every search shares: on the target or orthogonally adjacent, as a target usually stands on a
    # tile the player cannot enter.
    def self.target_reached?(x, y, tx, ty); (x - tx).abs + (y - ty).abs <= 1; end

    # Orders two frontier nodes [f, turns, ...] by priority f, then by fewer turns.
    def self.heap_less(a, b); a[0] < b[0] || (a[0] == b[0] && a[1] < b[1]); end

    # Pushes a node onto the binary min-heap and sifts it up.
    def self.heap_push(heap, item)
      heap.push(item); i = heap.size - 1
      while i > 0
        p = (i - 1) / 2
        break if heap_less(heap[p], heap[i])
        heap[p], heap[i] = heap[i], heap[p]; i = p
      end
    end

    # Pops the smallest node off the binary min-heap and sifts the hole down.
    def self.heap_pop(heap)
      top = heap[0]; last = heap.pop
      unless heap.empty?
        heap[0] = last; i = 0; n = heap.size
        loop do
          l = 2 * i + 1; r = 2 * i + 2; s = i
          s = l if l < n && heap_less(heap[l], heap[s])
          s = r if r < n && heap_less(heap[r], heap[s])
          break if s == i
          heap[i], heap[s] = heap[s], heap[i]; i = s
        end
      end
      top
    end

    # Walks the came-from chain back from a state key to the start, returning the step directions, one per
    # key press. Each link is [parent key, direction] or [parent key, direction, presses] for a run.
    def self.build_route(came, k)
      path = []
      while (p = came[k])
        (p[2] || 1).times { path.unshift(p[1]) }
        k = p[0]
      end
      path
    end

    # The search, with the configured algorithm over move_target's moves (ties to fewer turns); allow_ledge permits
    # ledge hops, and JPS or HPA* only run for a plain route over a uniform grid (uniform_grid?).
    # param exact the route must end on (tx,ty), not beside it, and no partial route is offered
    def self.find_path_to(tx, ty, allow_ledge, exact = false)
      px = $game_player.x; py = $game_player.y
      return note_cut if (px - tx).abs + (py - ty).abs > reach
      straight = (PokeAccess::Config.straight_routes rescue false)
      edge_relax = (PokeAccess::Config.edge_relax rescue false)
      algo = path_algorithm
      if !allow_ledge && !exact && (algo == :jps || algo == :hpa) && uniform_grid?
        sr = (algo == :jps) ? jps_search(tx, ty) : hpa_search(tx, ty)
        return sr if sr.is_a?(Array)
      end
      gw, hw = algo_weights(algo)
      heaped = algo != :bfs && algo != :dfs
      heap = []; queue = []
      push = heaped ? lambda { |item| heap_push(heap, item) } : lambda { |item| queue.push(item) }
      pop = heaped ? lambda { heap_pop(heap) } : (algo == :dfs ? lambda { queue.pop } : lambda { queue.shift })
      empty = heaped ? lambda { heap.empty? } : lambda { queue.empty? }
      l0 = bridge_level
      start = skey(px, py, l0)
      g = { start => 0 }
      turns = { start => 0 }
      came = {}; closed = {}; iter = 0
      deadline = search_deadline
      bestk = start; bestd = (px - tx).abs + (py - ty).abs
      push.call([hw * ((px - tx).abs + (py - ty).abs), 0, px, py, 0, l0])
      until empty.call
        iter += 1
        break if over_budget?(iter, deadline)
        cur = pop.call
        cx = cur[2]; cy = cur[3]; cd = cur[4]; cl = cur[5]
        ck = skey(cx, cy, cl)
        next if closed[ck]
        closed[ck] = true
        md = (cx - tx).abs + (cy - ty).abs
        if md < bestd; bestd = md; bestk = ck; end
        return build_route(came, ck) if exact ? (md == 0) : target_reached?(cx, cy, tx, ty)
        use_level(cl)
        DIRS.each do |dir|
          d = dir[2]
          nbr = move_target(cx, cy, dir, allow_ledge, edge_relax, cl)
          next if nbr.nil?
          nx = nbr.x; ny = nbr.y; nl = nbr.level; presses = nbr.presses; gate = nbr.gate
          nk = skey(nx, ny, nl)
          next if closed[nk]
          turned = (cd != 0 && cd != d)
          ng = g[ck] + presses + ((straight && turned) ? 1 : 0) + (gate ? GATE_COST : 0)
          nturns = turns[ck] + (turned ? 1 : 0)
          better = heaped ? (g[nk].nil? || ng < g[nk] || (ng == g[nk] && nturns < turns[nk])) : g[nk].nil?
          if better
            g[nk] = ng; turns[nk] = nturns; came[nk] = [ck, d, presses]
            push.call([gw * ng + hw * ((nx - tx).abs + (ny - ty).abs), nturns, nx, ny, d, nl])
          end
        end
      end
      return build_route(came, bestk) if !exact && bestd <= 2 && bestk != start
      nil
    end

    # Every tile the player can reach, by one BFS over find_path's moves within reach and a node cap: [set, complete],
    # the set mapping pkey => true (either bridge level counts).
    # param water also surf (water_step); a tile's value is then true on foot, else [shore x, y, facing] of its launch
    def self.flood(water = false)
      set = {}
      return [set, false] unless $game_player && $game_map
      px = $game_player.x; py = $game_player.y
      l0 = bridge_level
      set[pkey(px, py)] = true
      seen = { skey(px, py, l0) => true }
      queue = [[px, py, l0, true]]; head = 0; iter = 0
      rch = reach
      cap = water ? 20000 : 10000
      deadline = search_deadline
      full = true
      while head < queue.length
        iter += 1
        if iter > cap || (deadline && over_budget?(iter, deadline)); full = false; break; end
        cx, cy, cl, how = queue[head]; head += 1
        use_level(cl)
        wet = water && surf_water?(cx, cy)
        DIRS.each do |dir|
          nbr = wet ? nil : move_target(cx, cy, dir, true, false, cl)
          nbr = water_step(cx, cy, dir, cl, wet) if nbr.nil? && water
          next if nbr.nil?
          nx = nbr.x; ny = nbr.y; nl = nbr.level
          next if (nx - px).abs + (ny - py).abs > rch
          sk = skey(nx, ny, nl)
          next if seen[sk]
          seen[sk] = true
          tag = (how == true && water && !wet && surf_water?(nx, ny)) ? [cx, cy, dir[2]] : how
          k = pkey(nx, ny)
          set[k] = tag unless set[k]
          queue.push([nx, ny, nl, tag])
        end
      end
      [set, full]
    end

    # The reachable-tiles set (flood), cached per player tile; partway up a side staircase the last one stands, as the
    # stair answers for every tile there.
    def self.reachable_set
      key = [($game_player.x rescue 0), ($game_player.y rescue 0), ($game_map.map_id rescue 0)]
      return (@rs || {}) if on_stair?
      if @rs_key != key
        @rs_key = key
        @rs, @rs_full = with_level_kept { PokeAccess::Terrain.memoizing(held_terrain) { flood(false) } }
      end
      @rs
    rescue StandardError
      {}
    end

    # Whether the last flood ran to completion: absence from a truncated one proves nothing, so ask before hiding.
    def self.reachable_set_complete?
      reachable_set
      @rs_full ? true : false
    rescue StandardError
      false
    end
  end
end

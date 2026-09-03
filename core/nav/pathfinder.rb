module PokeAccess
  # A* pathfinder over walkable tiles (binary heap, manhattan heuristic), with ledge hops, ice slides,
  # selectable JPS/HPA* variants, and a reachability flood.
  module Pathfinder
    # Tile-coordinate packing stride: a tile packs as x*PKEY_STRIDE+y into one Integer hash key (HPA* reuses
    # the same stride to pack cluster ids). Map dimensions stay well under it.
    PKEY_STRIDE = 100000

    # Packs a tile coordinate into a single hash key.
    def self.pkey(x, y); x * PKEY_STRIDE + y; end

    # The four orthogonal steps as [dx, dy, rpg direction code], shared by the search and the flood.
    DIRS = [[0, -1, 8], [0, 1, 2], [-1, 0, 4], [1, 0, 6]]
    # Only run the full reachability flood for targets at least this far (manhattan); nearer ones are
    # cheap for A* to resolve directly, so the flood would be wasted work.
    FLOOD_MIN = 24

    @pcache = {}
    @pcache_state = nil

    # Passability of a one-step move from (cx,cy) in direction d, optionally memoised per map and vehicle
    # state (route_cache) so the engine's costly passable? is not repeated across the flood, A* and guide
    # refreshes. The cache does NOT track moving events, so it is an opt-in toggle the player can turn off.
    def self.passable_at?(cx, cy, d)
      return ($game_player.passable?(cx, cy, d) rescue false) unless (PokeAccess::Config.route_cache rescue false)
      st = [($game_map.map_id rescue 0), ($PokemonGlobal.surfing rescue false), ($PokemonGlobal.diving rescue false)]
      if @pcache_state != st; @pcache_state = st; @pcache = {}; end
      k = pkey(cx, cy) * 16 + d
      v = @pcache[k]
      return v unless v.nil?
      @pcache[k] = ($game_player.passable?(cx, cy, d) rescue false)
    rescue StandardError
      ($game_player.passable?(cx, cy, d) rescue false)
    end

    # Drops the memoised passability and reachable-set caches, and the HPA* abstract graph with them, so the
    # next route is computed against current map state. Called when a map event finishes, since a switch
    # flip or a moved event may have changed what is passable. Throttled to once every couple of seconds: a
    # cutscene fires many event-ends in a row and a cold re-flood is costly, more so on a game whose
    # passable? is slow. param force bypasses the throttle, for a caller that KNOWS a door just opened
    def self.invalidate_cache(force = false)
      now = (PokeAccess.clock rescue 0)
      return if !force && @last_invalidate && (now - @last_invalidate) < 2.0
      @last_invalidate = now
      @pcache = {}
      @pcache_state = nil
      @rs_key = nil
      @hpa = nil
      @hpa_sig = nil
      @surf_key = nil
      @surf_route = nil
      @slide_key = nil
    end

    # The farthest a target can be (manhattan tiles) for find_path and the flood to consider it,
    # user-tunable: a diamond around the player whose value is the straight (cardinal) reach.
    def self.reach; (PokeAccess::Config.route_reach rescue 128).to_i; end

    # How often (in expanded nodes) the time-budget search checks the clock. Checking every node would pay
    # the monotonic-clock call too often; every BUDGET_CHECK nodes keeps the overhead negligible.
    BUDGET_CHECK = 256

    # The deadline (a clock value) every search in the CURRENT operation shares, or nil when the auto/time
    # mode is off, which bounds the search by node count (astar_max) instead.
    #
    # Shared, because one find_path runs up to three searches -- the reachability probe, the plain route,
    # then the route allowing ledges -- and a clock per search would spend the player's budget three times
    # over. Running out on the first pass returns nil, and nil is exactly what fires the next pass.
    def self.search_deadline
      return @budget_until if @budget_until
      fresh_deadline
    end

    # A brand-new deadline, ignoring any in scope. Only with_budget and search_deadline should call this.
    def self.fresh_deadline
      return nil unless (PokeAccess::Config.route_auto rescue false)
      ms = (PokeAccess::Config.route_budget_ms rescue 8).to_i
      (PokeAccess.clock rescue 0.0) + (ms / 1000.0)
    end

    # Runs a block with ONE deadline covering everything inside it, so route_budget_ms means what the option
    # says. Nesting keeps the OUTER deadline (an inner search must not award itself a fresh budget), and the
    # previous value is always restored, so a search that throws never leaves a stale deadline behind to cut
    # the next one short.
    def self.with_budget
      outer = @budget_until
      @budget_until = outer || fresh_deadline
      yield
    ensure
      @budget_until = outer
    end

    # True once a search must stop: in time mode when the deadline passed (checked every BUDGET_CHECK nodes),
    # otherwise when the node count exceeds astar_max.
    def self.over_budget?(iter, deadline)
      if deadline
        return false unless (iter & (BUDGET_CHECK - 1)) == 0
        (PokeAccess.clock rescue 0.0) > deadline
      else
        iter > PokeAccess::Config.astar_max
      end
    end

    # The landing tile of a ledge hop from (cx,cy) one step in direction d, or nil when there is no ledge
    # that way. The game hops two tiles toward any faced ledge unconditionally, so this does the same,
    # requiring only a real standable landing; one-way behaviour comes from the map (you reach a ledge
    # only from its high side). Lets the search cross ledges the player hops over but cannot walk through.
    def self.ledge_jump(cx, cy, dx, dy, d)
      nx = cx + dx; ny = cy + dy
      return nil unless PokeAccess::Terrain.ledge_at?(nx, ny)
      return nil unless ledge_dir_ok?(nx, ny, d)
      lx = cx + 2 * dx; ly = cy + 2 * dy
      return nil unless ($game_map.valid?(lx, ly) rescue false)
      return nil unless [2, 4, 6, 8].any? { |dd| ($game_player.passable?(lx, ly, dd) rescue false) }
      [lx, ly]
    rescue StandardError
      nil
    end

    # Jump direction => the tileset-passage bit of the side OPPOSITE the jump.
    LEDGE_OPP_BIT = { 2 => 0x08, 8 => 0x01, 4 => 0x04, 6 => 0x02 }

    # True if the ledge at (x,y) may be hopped in direction d. A ledge is one-way, so the hop is allowed
    # when the side opposite the jump is open. Permissive (true) when the passage can't be read or the
    # directions setting is off, so nothing is wrongly blocked.
    def self.ledge_dir_ok?(x, y, d)
      return true unless (PokeAccess::Config.ledge_directions rescue true)
      ob = LEDGE_OPP_BIT[d]
      return true unless ob
      p = ledge_passage(x, y)
      return true if p.nil?
      (p & ob) == 0
    rescue StandardError
      true
    end

    # The tileset passage byte of the ledge tile at (x,y) (the top layer whose terrain is a ledge), or
    # nil when the passage/terrain tables are unavailable (a non-RMXP engine).
    def self.ledge_passage(x, y)
      passages = $game_map.instance_variable_get(:@passages)
      tags = $game_map.instance_variable_get(:@terrain_tags)
      return nil unless passages && tags
      [2, 1, 0].each do |i|
        tid = ($game_map.data[x, y, i] rescue 0)
        next if tid.nil? || tid == 0
        return passages[tid] if tags[tid] == 1
      end
      nil
    rescue StandardError
      nil
    end

    # Move-route command code => tile delta, for decoding how far a slide carries the player.
    MOVE_DELTA = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1],
                   5 => [-1, 1], 6 => [1, 1], 7 => [-1, -1], 8 => [1, -1] }

    # A slide event's [trigger-direction, dest_x, dest_y], or nil. A slide ("minihueco") is a sprite-less
    # touch event that, when stepped onto facing a set direction, force-moves the player across a gap (a
    # Set Move Route on the player); the player feels it as walking. The destination is the event tile
    # plus the move route's net displacement.
    def self.slide_info(ev)
      trig = PokeAccess.ivar(ev, :@trigger)
      return nil unless trig == 1 || trig == 2
      return nil unless ev.character_name.to_s.empty?
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      facing = nil; mr = nil
      list.each do |c|
        code = (c.code rescue 0)
        facing = (c.parameters[2] rescue nil) if code == 111 && (c.parameters[0] rescue nil) == 6 && (c.parameters[1] rescue nil) == -1
        mr = c if code == 209 && (c.parameters[0].to_i rescue nil) == -1
      end
      return nil unless mr && facing
      steps = (mr.parameters[1].list.map { |mc| mc.code } rescue [])
      dx = 0; dy = 0
      steps.each { |sc| d = MOVE_DELTA[sc]; (dx += d[0]; dy += d[1]) if d }
      return nil if dx == 0 && dy == 0
      [facing, ev.x + dx, ev.y + dy]
    rescue StandardError
      nil
    end

    # Per-map index of slide tiles: pkey => { trigger-direction => [dest_x, dest_y] }, cached so events
    # are scanned once per map. Lets the search "ride" a slide instead of stopping at the gap it crosses.
    def self.slide_index
      key = ($game_map.map_id rescue 0)
      return @slide_idx if @slide_key == key && @slide_idx
      @slide_key = key
      idx = {}
      ($game_map.events.values rescue []).each do |ev|
        si = slide_info(ev)
        next unless si
        (idx[pkey(ev.x, ev.y)] ||= {})[si[0]] = [si[1], si[2]]
      end
      @slide_idx = idx
    rescue StandardError
      {}
    end

    # A route to a tile adjacent to the target. Prefers a pure walking/slide route (ledge hops are
    # awkward and often one-way for a blind player) and only allows ledge hops when no walking route exists.
    def self.find_path(tx, ty)
      with_budget do
        with_bridges do
          px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
          far = (px - tx).abs + (py - ty).abs > FLOOD_MIN
          next nil if far && blocked_target?(tx, ty)
          find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
        end
      end
    end

    # Runs the search with on-bridge passability forced, so it can cross a bridge the player is about to
    # step onto (off a bridge the engine reports its tiles impassable). The bridge's own passage bits
    # block the water sides, so it never routes into water; state is restored after.
    def self.with_bridges
      pg = $PokemonGlobal
      forced = false
      if pg && (pg.respond_to?(:bridge=) rescue false) && (pg.bridge rescue 1) == 0
        (pg.bridge = 2; forced = true) rescue nil
      end
      yield
    ensure
      (pg.bridge = 0 if forced) rescue nil
    end

    # Offsets within manhattan distance 2 of a tile (matches find_path_to's "get within 2" partial route).
    NEAR2 = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1],
             [2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]

    # Fast reject for a clearly unreachable target, so the guide does not run a full A* every refresh
    # while pointing somewhere unwalkable (a 1 fps freeze a tester hit). Uses the cached flood;
    # conservative: never rejects when edge-relax is on or the flood is truncated/unavailable.
    def self.blocked_target?(tx, ty)
      return false if (PokeAccess::Config.edge_relax rescue false)
      s = reachable_set
      return false if s.nil? || s.empty?
      return false unless @rs_full
      !NEAR2.any? { |dx, dy| s[pkey(tx + dx, ty + dy)] }
    rescue StandardError
      false
    end

    # The search algorithms the route key can choose; all share the neighbour expansion and turn
    # tiebreak and differ only in the frontier.
    ALGORITHMS = [:astar, :weighted, :greedy, :dijkstra, :bfs, :dfs, :jps, :hpa]

    # The search algorithm from config (default :astar; an unknown value falls back to it).
    def self.path_algorithm
      a = (PokeAccess::Config.path_algorithm rescue nil)
      a = a.to_sym if a.respond_to?(:to_sym)
      ALGORITHMS.include?(a) ? a : :astar
    end

    # The [g-weight, h-weight] of a heap algorithm's priority f = gw*g + hw*h: astar weights both equally,
    # weighted leans on the heuristic, greedy drops g, dijkstra drops h. Unused for bfs/dfs (queue-ordered).
    # The weights are DOUBLED ([2,2] rather than [1,1]) so weighted's [2,3] expresses 1.5x the heuristic in
    # pure integers -- do not "simplify" to [1,1]/[1,1.5]: a float weight would break the integer ordering.
    def self.algo_weights(algo)
      case algo
      when :weighted then [2, 3]
      when :greedy   then [0, 2]
      when :dijkstra then [2, 0]
      else [2, 2]
      end
    end

    # True if a tile is on the outer border of the map (where connection/exit tiles live).
    def self.border_tile?(x, y)
      return false unless $game_map
      x <= 0 || y <= 0 || x >= $game_map.width - 1 || y >= $game_map.height - 1
    rescue StandardError
      false
    end

    # The arrival test every search shares: a route succeeds once it stands ON the target or ORTHOGONALLY
    # ADJACENT to it, since the typical target (an NPC, sign or item) occupies a tile the player cannot enter.
    # A*, JPS and HPA* all end on this same criterion so none demands entering an unwalkable goal tile.
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

    # Walks the came-from chain back from a tile key to the start, returning the step directions.
    def self.build_route(came, k)
      path = []
      while came[k]; p = came[k]; path.unshift(p[2]); k = pkey(p[0], p[1]); end
      path
    end

    # Resolves a step from (cx,cy) in a direction to the neighbour the search may enter, or nil when blocked.
    # A ledge tile is never a standable node -- crossing it is only ever the two-tile hop, gated by
    # allow_ledge -- so it is caught before the passability test: v21/v22 and the gen-6 games make a ledge
    # PASSABLE from the high side and decide the jump inside their own "can move" branch, where a plain
    # passability check would walk into it as a dead end. Then a normal passable step (ice tiles ride their
    # slide), else (edge_relax) a passable border tile, else the ledge hop for an engine whose ledge reads
    # impassable. Both ledge paths go through ledge_jump, so both honour the ledge_directions setting.
    def self.step_target(cx, cy, dir, allow_ledge, edge_relax)
      dx, dy, d = dir
      nx = cx + dx; ny = cy + dy
      if (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
        return allow_ledge ? ledge_jump(cx, cy, dx, dy, d) : nil
      end
      if passable_at?(cx, cy, d)
        return ice_slide(nx, ny, dx, dy, d) if PokeAccess::Terrain.ice_at?(nx, ny)
        return [nx, ny]
      end
      return [nx, ny] if edge_relax && border_tile?(nx, ny) && ($game_map.passable?(nx, ny, 0) rescue false)
      allow_ledge ? ledge_jump(cx, cy, dx, dy, d) : nil
    end

    # Follows an ice slide from (x,y): on ice the player keeps sliding the same way until the tile is no
    # longer ice or the next step is blocked, so the search lands where the slide stops (one key press
    # carries the player across the run). The entry tile is a validated passable ice tile; guarded against a loop.
    def self.ice_slide(x, y, dx, dy, d)
      guard = 0
      while PokeAccess::Terrain.ice_at?(x, y) && guard < 200
        guard += 1
        break unless passable_at?(x, y, d)
        x += dx; y += dy
      end
      [x, y]
    end

    # The search. allow_ledge enables ledge hops (used only by the second pass). Heap algorithms compare
    # f = gw*g + hw*h; bfs/dfs use a plain queue/stack; ties break toward fewer turns; passability is the
    # game's own, so it never routes through walls; edge tolerance optionally relaxes the map border.
    def self.find_path_to(tx, ty, allow_ledge)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      straight = (PokeAccess::Config.straight_routes rescue false)
      edge_relax = (PokeAccess::Config.edge_relax rescue false)
      algo = path_algorithm
      if !allow_ledge && (algo == :jps || algo == :hpa)
        sr = (algo == :jps) ? jps_search(tx, ty) : hpa_search(tx, ty)
        return sr if sr.is_a?(Array)
      end
      gw, hw = algo_weights(algo)
      heaped = algo != :bfs && algo != :dfs
      heap = []; queue = []
      push = heaped ? lambda { |item| heap_push(heap, item) } : lambda { |item| queue.push(item) }
      pop = heaped ? lambda { heap_pop(heap) } : (algo == :dfs ? lambda { queue.pop } : lambda { queue.shift })
      empty = heaped ? lambda { heap.empty? } : lambda { queue.empty? }
      g = { pkey(px, py) => 0 }
      turns = { pkey(px, py) => 0 }
      came = {}; closed = {}; iter = 0
      deadline = search_deadline
      bestk = pkey(px, py); bestd = (px - tx).abs + (py - ty).abs
      push.call([hw * ((px - tx).abs + (py - ty).abs), 0, px, py, 0])
      until empty.call
        iter += 1
        break if over_budget?(iter, deadline)
        cur = pop.call
        cx = cur[2]; cy = cur[3]; cd = cur[4]
        ck = pkey(cx, cy)
        next if closed[ck]
        closed[ck] = true
        md = (cx - tx).abs + (cy - ty).abs
        if md < bestd; bestd = md; bestk = ck; end
        return build_route(came, ck) if target_reached?(cx, cy, tx, ty)
        DIRS.each do |dir|
          d = dir[2]
          nbr = step_target(cx, cy, dir, allow_ledge, edge_relax)
          next if nbr.nil?
          nx, ny = nbr
          si = slide_index[pkey(nx, ny)]
          nx, ny = si[d] if si && si[d]
          nk = pkey(nx, ny)
          next if closed[nk]
          turned = (cd != 0 && cd != d)
          ng = g[ck] + 1 + ((straight && turned) ? 1 : 0)
          nturns = turns[ck] + (turned ? 1 : 0)
          better = heaped ? (g[nk].nil? || ng < g[nk] || (ng == g[nk] && nturns < turns[nk])) : g[nk].nil?
          if better
            g[nk] = ng; turns[nk] = nturns; came[nk] = [cx, cy, d]
            push.call([gw * ng + hw * ((nx - tx).abs + (ny - ty).abs), nturns, nx, ny, d])
          end
        end
      end
      return build_route(came, bestk) if bestd <= 2 && bestk != pkey(px, py)
      nil
    end

    # Jump point search: an A* whose successors are "jump points" (the next turning/goal tile in a
    # direction), so long straight corridors cost one expansion. Optimal on a uniform 4-connected grid;
    # ice/slide tiles break that, so it sets @jps_fallback and the caller drops to plain A*. A ledge does the
    # same for the same reason: the engine leaves it PASSABLE from the high side and the real step covers two
    # tiles, so on JPS's uniform grid it is crossed like flat ground -- the guide cane walks the blind player
    # over a one-way jump unannounced and the step counter lies. It exits through :fallback to the usual A*,
    # which does know how to jump it. Returns the route, nil (out of reach), or :fallback.
    def self.jps_search(tx, ty)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      @jps_tx = tx; @jps_ty = ty; @jps_fallback = false
      @jps_steps = 0; @jps_budget = [(PokeAccess::Config.astar_max rescue 2500).to_i * 8, 20000].max
      heap = []; g = { pkey(px, py) => 0 }; came = {}; closed = {}; iter = 0
      deadline = search_deadline
      bestk = pkey(px, py); bestd = (px - tx).abs + (py - ty).abs
      heap_push(heap, [bestd, 0, px, py, 0])
      until heap.empty?
        iter += 1
        return :fallback if @jps_fallback
        break if over_budget?(iter, deadline)
        cur = heap_pop(heap); cx = cur[2]; cy = cur[3]; ck = pkey(cx, cy)
        next if closed[ck]
        closed[ck] = true
        md = (cx - tx).abs + (cy - ty).abs
        if md < bestd; bestd = md; bestk = ck; end
        return jps_route(came, ck) if target_reached?(cx, cy, tx, ty)
        DIRS.each do |dir|
          dx = dir[0]; dy = dir[1]; d = dir[2]
          jp = jps_jump(cx, cy, dx, dy, d)
          return :fallback if @jps_fallback
          next if jp.nil?
          jx = jp[0]; jy = jp[1]; jk = pkey(jx, jy)
          next if closed[jk]
          ng = g[ck] + (jx - cx).abs + (jy - cy).abs
          if g[jk].nil? || ng < g[jk]
            g[jk] = ng; came[jk] = [cx, cy, d, jx, jy]
            heap_push(heap, [ng + (jx - tx).abs + (jy - ty).abs, 0, jx, jy, d])
          end
        end
      end
      return :fallback if @jps_fallback
      return jps_route(came, bestk) if bestd <= 2 && bestk != pkey(px, py)
      nil
    end

    # Scans from (x,y) in one direction for the next jump point: the goal-adjacent tile, a tile with a
    # forced neighbour, or (4-connected completeness) a tile from which a perpendicular scan reaches a
    # jump point. Returns [x,y] or nil (a wall/ledge ends the scan). Ice/slide tiles, an exceeded step
    # budget, or recursion past the depth cap all set @jps_fallback so the caller reverts to plain A*.
    def self.jps_jump(x, y, dx, dy, d, depth = 0)
      if depth > 80
        @jps_fallback = true; return nil
      end
      loop do
        @jps_steps += 1
        if @jps_steps > @jps_budget
          @jps_fallback = true; return nil
        end
        return nil unless passable_at?(x, y, d)
        nx = x + dx; ny = y + dy
        if (PokeAccess::Terrain.ice_at?(nx, ny) rescue false) || slide_index[pkey(nx, ny)] ||
           (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
          @jps_fallback = true; return nil
        end
        return [nx, ny] if target_reached?(nx, ny, @jps_tx, @jps_ty)
        perps = (dx != 0) ? [8, 2] : [4, 6]
        return [nx, ny] if perps.any? { |p| !passable_at?(x, y, p) && passable_at?(nx, ny, p) }
        if dx != 0
          return [nx, ny] if !jps_jump(nx, ny, 0, -1, 8, depth + 1).nil? || !jps_jump(nx, ny, 0, 1, 2, depth + 1).nil?
        else
          return [nx, ny] if !jps_jump(nx, ny, -1, 0, 4, depth + 1).nil? || !jps_jump(nx, ny, 1, 0, 6, depth + 1).nil?
        end
        return nil if @jps_fallback
        x = nx; y = ny
      end
    end

    # Rebuilds the step route from a JPS came-from chain, expanding each jump back into individual tile
    # steps (a jump of n tiles in direction d becomes d repeated n times).
    def self.jps_route(came, k)
      path = []
      while (c = came[k])
        cx = c[0]; cy = c[1]; d = c[2]; jx = c[3]; jy = c[4]
        ((jx - cx).abs + (jy - cy).abs).times { path.unshift(d) }
        k = pkey(cx, cy)
      end
      path
    end

    # Hierarchical pathfinding (HPA*). The side length, in tiles, of a cluster: the map is tiled into
    # squares this big, portals cut at the openings between neighbours, and the abstract graph routes
    # cluster-to-cluster.
    HPA_CLUSTER = 10

    # Bounded low-level A* between two EXACT tiles, within an optional [x0,y0,x1,y1] box and node cap;
    # returns [step-directions, cost] or nil. Ice/slide tiles are treated as walls, so any path needing
    # them fails here and the caller reverts to plain A*. Weights abstract edges and refines abstract hops.
    # A ledge is discarded as a tile, like ice and the sliders: crossing it is a two-tile jump in one direction
    # and here it would count as an ordinary step both ways. With no local route the abstract hop is not
    # refined, and hpa_search returns :fallback to the usual A*, which does know how to jump it.
    def self.hpa_low(sx, sy, gx, gy, maxnodes, x0 = nil, y0 = nil, x1 = nil, y1 = nil)
      return [[], 0] if sx == gx && sy == gy
      heap = []; g = { pkey(sx, sy) => 0 }; came = {}; closed = {}; iter = 0
      heap_push(heap, [(sx - gx).abs + (sy - gy).abs, 0, sx, sy, 0])
      until heap.empty?
        iter += 1
        return nil if iter > maxnodes
        cur = heap_pop(heap); cx = cur[2]; cy = cur[3]; ck = pkey(cx, cy)
        next if closed[ck]
        closed[ck] = true
        return [build_route(came, ck), g[ck]] if cx == gx && cy == gy
        DIRS.each do |dir|
          dx = dir[0]; dy = dir[1]; d = dir[2]
          next unless passable_at?(cx, cy, d)
          nx = cx + dx; ny = cy + dy
          next if x0 && (nx < x0 || ny < y0 || nx > x1 || ny > y1)
          next if (PokeAccess::Terrain.ice_at?(nx, ny) rescue false) || slide_index[pkey(nx, ny)] ||
                  (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
          nk = pkey(nx, ny)
          next if closed[nk]
          ng = g[ck] + 1
          if g[nk].nil? || ng < g[nk]
            g[nk] = ng; came[nk] = [cx, cy, d]
            heap_push(heap, [ng + (nx - gx).abs + (ny - gy).abs, 0, nx, ny, d])
          end
        end
      end
      nil
    end

    # The abstract graph for the current map: portal nodes at the openings between adjacent clusters,
    # with inter-cluster edges (cost 1) and intra-cluster edges (a bounded local A* per portal pair).
    # Cached per [map, surfing, diving]. Returns the graph hash or nil.
    def self.hpa_graph
      sig = [($game_map.map_id rescue 0), ($PokemonGlobal.surfing rescue false), ($PokemonGlobal.diving rescue false)]
      return @hpa if @hpa_sig == sig && @hpa
      @hpa_sig = sig; @hpa = nil
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return nil if w < 2 || h < 2
      c = HPA_CLUSTER
      adj = {}
      byc = {}
      addnode = lambda do |x, y|
        k = pkey(x, y); cid = (x / c) * PKEY_STRIDE + (y / c)
        lst = (byc[cid] ||= [])
        lst << k unless lst.include?(k)
        k
      end
      link = lambda { |a, b, cost| (adj[a] ||= []) << [b, cost]; (adj[b] ||= []) << [a, cost] }
      bx = c - 1
      while bx < w - 1
        cr = 0
        while cr * c < h
          ylo = cr * c; yhi = [cr * c + c - 1, h - 1].min; by = ylo
          while by <= yhi
            if passable_at?(bx, by, 6)
              run0 = by; by += 1
              by += 1 while by <= yhi && passable_at?(bx, by, 6)
              my = (run0 + by - 1) / 2
              link.call(addnode.call(bx, my), addnode.call(bx + 1, my), 1)
            else
              by += 1
            end
          end
          cr += 1
        end
        bx += c
      end
      by = c - 1
      while by < h - 1
        cc = 0
        while cc * c < w
          xlo = cc * c; xhi = [cc * c + c - 1, w - 1].min; bx = xlo
          while bx <= xhi
            if passable_at?(bx, by, 2)
              run0 = bx; bx += 1
              bx += 1 while bx <= xhi && passable_at?(bx, by, 2)
              mx = (run0 + bx - 1) / 2
              link.call(addnode.call(mx, by), addnode.call(mx, by + 1), 1)
            else
              bx += 1
            end
          end
          cc += 1
        end
        by += c
      end
      byc.each do |cid, nlist|
        cc = cid / PKEY_STRIDE; cr = cid % PKEY_STRIDE
        box = [cc * c, cr * c, [cc * c + c - 1, w - 1].min, [cr * c + c - 1, h - 1].min]
        i = 0
        while i < nlist.length
          j = i + 1
          while j < nlist.length
            a = nlist[i]; b = nlist[j]
            r = hpa_low(a / PKEY_STRIDE, a % PKEY_STRIDE, b / PKEY_STRIDE, b % PKEY_STRIDE, c * c * 2, box[0], box[1], box[2], box[3])
            link.call(a, b, r[1]) if r
            j += 1
          end
          i += 1
        end
      end
      @hpa = { :adj => adj, :byc => byc, :c => c, :w => w, :h => h }
    rescue StandardError
      @hpa = nil
    end

    # The bounding box of the two clusters containing a and b, clamped to the map, so the refining A* for
    # an abstract hop stays local.
    def self.pair_box(ax, ay, bx, by, c, w, h)
      [[(ax / c) * c, (bx / c) * c].min, [(ay / c) * c, (by / c) * c].min,
       [[(ax / c) * c + c - 1, (bx / c) * c + c - 1].max, w - 1].min,
       [[(ay / c) * c + c - 1, (by / c) * c + c - 1].max, h - 1].min]
    end

    # The tiles at which an HPA* route may ARRIVE: the target itself plus its orthogonal neighbours, kept
    # only when a tile is standable (some neighbour can step INTO it, the same passable_at? the search uses).
    # This is the graph-side form of target_reached?: a solid target (NPC/sign/item) drops out and its
    # walkable neighbours remain, so the hierarchy routes adjacent instead of demanding the unenterable tile.
    def self.hpa_arrivals(tx, ty)
      cells = [[tx, ty]]
      DIRS.each { |dx, dy, _d| cells << [tx + dx, ty + dy] }
      cells.select do |cx, cy|
        next false unless ($game_map.valid?(cx, cy) rescue false)
        DIRS.any? { |dx, dy, d| passable_at?(cx - dx, cy - dy, d) }
      end
    end

    # The abstract search's synthetic goal sink: a sentinel key no real tile can pack to (packed tiles are
    # non-negative), linked at zero cost from every arrival tile so A* selects the cheapest one to reach.
    HPA_SINK = -1

    # Hierarchical search: connect start and every arrival tile (target or a walkable neighbour) to their
    # clusters' portals, A* over the abstract graph to a synthetic sink linked from each arrival, then refine
    # each real abstract hop back into tile steps with a live local A*. Because every hop is re-solved against
    # current passability, a stale cached graph can only cause :fallback, never a wrong route. Returns the
    # route, nil (out of reach), :fallback (use plain A*), or [] (already adjacent). Neighbour lists are merged
    # with dup.concat, never Array#+: a fangame script patch redefines Array#+ as an in-place mutator (seen
    # in the wild) that would leak the temporary edges into the cached graph.
    def self.hpa_search(tx, ty)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      return [] if target_reached?(px, py, tx, ty)
      gr = hpa_graph
      return :fallback unless gr
      c = gr[:c]; w = gr[:w]; h = gr[:h]; adj = gr[:adj]; byc = gr[:byc]
      start = pkey(px, py)
      arrivals = hpa_arrivals(tx, ty)
      return :fallback if arrivals.empty?
      temp = Hash.new { |hh, k| hh[k] = [] }
      connect = lambda do |sx, sy, sk|
        box = [(sx / c) * c, (sy / c) * c, [(sx / c) * c + c - 1, w - 1].min, [(sy / c) * c + c - 1, h - 1].min]
        (byc[(sx / c) * PKEY_STRIDE + (sy / c)] || []).each do |nk|
          r = hpa_low(sx, sy, nk / PKEY_STRIDE, nk % PKEY_STRIDE, c * c * 2, box[0], box[1], box[2], box[3])
          (temp[sk] << [nk, r[1]]; temp[nk] << [sk, r[1]]) if r
        end
      end
      connect.call(px, py, start)
      arrivals.each do |ax, ay|
        ak = pkey(ax, ay)
        connect.call(ax, ay, ak)
        temp[ak] << [HPA_SINK, 0]
        if (px / c) == (ax / c) && (py / c) == (ay / c)
          box = [(px / c) * c, (py / c) * c, [(px / c) * c + c - 1, w - 1].min, [(py / c) * c + c - 1, h - 1].min]
          r = hpa_low(px, py, ax, ay, c * c * 2, box[0], box[1], box[2], box[3])
          temp[start] << [ak, r[1]] if r
        end
      end
      openh = []; gg = { start => 0 }; cf = {}; cl = {}; it = 0
      deadline = search_deadline
      heap_push(openh, [(px - tx).abs + (py - ty).abs, 0, start])
      found = false
      until openh.empty?
        it += 1
        break if it > 20000 || (deadline && over_budget?(it, deadline))
        n = heap_pop(openh)[2]
        next if cl[n]
        cl[n] = true
        if n == HPA_SINK; found = true; break; end
        (adj[n] || []).dup.concat(temp[n]).each do |e|
          m = e[0]; ng = gg[n] + e[1]
          if gg[m].nil? || ng < gg[m]
            gg[m] = ng; cf[m] = n
            hh = (m == HPA_SINK) ? 0 : (m / PKEY_STRIDE - tx).abs + (m % PKEY_STRIDE - ty).abs
            heap_push(openh, [ng + hh, 0, m])
          end
        end
      end
      return :fallback unless found
      seq = []; k = cf[HPA_SINK]
      while k; seq.unshift(k); k = cf[k]; end
      return [] if seq.length <= 1
      route = []; i = 0
      while i < seq.length - 1
        a = seq[i]; b = seq[i + 1]
        ax = a / PKEY_STRIDE; ay = a % PKEY_STRIDE; bx = b / PKEY_STRIDE; by = b % PKEY_STRIDE
        box = pair_box(ax, ay, bx, by, c, w, h)
        r = hpa_low(ax, ay, bx, by, (box[2] - box[0] + 1) * (box[3] - box[1] + 1) * 2 + 8, box[0], box[1], box[2], box[3])
        return :fallback unless r
        route.concat(r[0]); i += 1
      end
      route.empty? ? :fallback : route
    rescue StandardError
      :fallback
    end

    # Every tile the player can walk to from here, as a pkey => true set, via one BFS flood using
    # find_path's passability. Replaces a full A* per target for the hide-unreachable filter (which made
    # changing category take seconds on big maps). Bounded to the find_path range and a hard node cap.
    def self.reachable_tiles
      set = {}
      return set unless $game_player && $game_map
      px = $game_player.x; py = $game_player.y
      set[pkey(px, py)] = true
      queue = [[px, py]]; head = 0; iter = 0
      rch = reach
      deadline = search_deadline
      @rs_full = true
      while head < queue.length
        iter += 1
        if iter > 10000 || (deadline && over_budget?(iter, deadline)); @rs_full = false; break; end
        cur = queue[head]; head += 1
        cx = cur[0]; cy = cur[1]
        DIRS.each do |dir|
          d = dir[2]
          nbr = step_target(cx, cy, dir, true, false)
          next if nbr.nil?
          nx, ny = nbr
          si = slide_index[pkey(nx, ny)]
          nx, ny = si[d] if si && si[d]
          next if (nx - px).abs + (ny - py).abs > rch
          nk = pkey(nx, ny)
          next if set[nk]
          set[nk] = true; queue.push([nx, ny])
        end
      end
      set
    end

    # The reachable-tiles set, cached per player tile so the flood runs once per move and is shared by the
    # locator's hide-unreachable filter and the positional audio's line-of-sight test.
    def self.reachable_set
      key = [($game_player.x rescue 0), ($game_player.y rescue 0), ($game_map.map_id rescue 0)]
      if @rs_key != key
        @rs_key = key
        @rs = with_bridges { reachable_tiles }
      end
      @rs
    rescue StandardError
      {}
    end

    # Whether the last flood ran to completion. A flood that hit the node cap or the frame budget covers
    # only part of the map, so absence from it is not evidence of unreachability -- every consumer that
    # would HIDE something has to ask this first.
    def self.reachable_set_complete?
      reachable_set
      @rs_full ? true : false
    rescue StandardError
      false
    end

    # True if any tile orthogonally adjacent to (x,y) is surfable water (a shore tile).
    def self.beside_surfable?(x, y)
      DIRS.any? { |d| PokeAccess::Terrain.surfable_at?(x + d[0], y + d[1]) }
    rescue StandardError
      false
    end

    # When find_path cannot reach a target on foot (it may be across water), a route to the reachable
    # shore tile nearest the target -- where to start surfing from -- so the guide leads to the water's
    # edge. Once surfing, normal find_path routes across the water. Cached; nil when no reachable shore.
    def self.surf_launch(tx, ty)
      k = [($game_player.x rescue -1), ($game_player.y rescue -1), ($game_map.map_id rescue -1), tx, ty]
      return @surf_route if @surf_key == k
      @surf_key = k
      @surf_route = compute_surf_launch(tx, ty)
    rescue StandardError
      nil
    end

    # The uncached shore search: scans the reachable tiles for the one beside surfable water nearest the
    # target and routes to it. Cached by surf_launch because that scan is the cost behind a guide freeze
    # when pointing across water.
    def self.compute_surf_launch(tx, ty)
      set = (reachable_set rescue {})
      return nil if set.empty?
      best = nil; bestd = nil
      set.each_key do |k|
        x = k / PKEY_STRIDE; y = k % PKEY_STRIDE
        next unless beside_surfable?(x, y)
        d = (x - tx).abs + (y - ty).abs
        if bestd.nil? || d < bestd; bestd = d; best = [x, y]; end
      end
      return nil unless best
      find_path(best[0], best[1])
    rescue StandardError
      nil
    end

    # Turns a list of step directions into a spoken route (e.g. "3 up, 2 left").
    def self.path_to_text(path)
      return PokeAccess::I18n.t(:loc_no_route) if path.nil?
      return PokeAccess::I18n.t(:loc_next_to) if path.empty?
      names = { 8 => PokeAccess::I18n.t(:dir_up), 2 => PokeAccess::I18n.t(:dir_down),
                4 => PokeAccess::I18n.t(:dir_left), 6 => PokeAccess::I18n.t(:dir_right) }
      parts = []; cur = path[0]; count = 0
      path.each do |d|
        if d == cur then count += 1
        else parts.push("#{count} #{names[cur]}"); cur = d; count = 1 end
      end
      parts.push("#{count} #{names[cur]}")
      parts.join(", ")
    end
  end
end

# Drop the passability grid and route caches on map change or load (Caches.reset_all): they are keyed to
# the current map, so a new map must not see the old grid. force = true bypasses the local invalidation
# throttle.
PokeAccess::Caches.register(:pathfinder) { PokeAccess::Pathfinder.invalidate_cache(true) }

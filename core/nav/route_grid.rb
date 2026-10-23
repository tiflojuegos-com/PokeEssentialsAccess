module PokeAccess
  # Pathfinder, hierarchical A* (HPA*) over a uniform grid: it only holds where every move is one tile
  # (Routes::Moves.uniform?), and a route that needs ice or a ledge falls back to plain A*.
  module Pathfinder
    # The directions of hpa_low's route, walked back from tile key k along its came-from links [parent key, direction].
    def self.hpa_route(came, k)
      path = Route.new
      while (c = came[k])
        path.unshift(c[1])
        k = c[0]
      end
      path
    end

    # HPA*: the side, in tiles, of the square clusters the map is cut into, with portals at the openings between them,
    # unless Config.hpa_cluster sets another.
    HPA_CLUSTER = 10
    # What a map frame may spend building the HPA* graph, in ms (hpa_tick).
    HPA_SLICE_MS = 2

    @hpa = nil
    @hpa_states = 0

    # The side of HPA*'s clusters in tiles: Config.hpa_cluster, else HPA_CLUSTER.
    def self.hpa_cluster
      c = (PokeAccess::Config.hpa_cluster rescue HPA_CLUSTER).to_i
      c >= 2 ? c : HPA_CLUSTER
    end

    # The states HPA*'s local searches have walked, all told: what building the graph spends by effort.
    def self.hpa_states; @hpa_states; end

    # Bounded A* between two exact tiles in an optional [x0,y0,x1,y1] box under a node cap: [directions, cost] or nil,
    # the states it walks counted in hpa_states. Ice and ledges count as walls, so a route that needs them ends in
    # hpa_search's :fallback to plain A*.
    def self.hpa_low(sx, sy, gx, gy, maxnodes, x0 = nil, y0 = nil, x1 = nil, y1 = nil)
      return [[], 0] if sx == gx && sy == gy
      heap = []; g = { Routes.pkey(sx, sy) => 0 }; came = {}; closed = {}; iter = 0
      heap_push(heap, [(sx - gx).abs + (sy - gy).abs, 0, sx, sy, 0])
      until heap.empty?
        iter += 1
        return nil if iter > maxnodes
        cur = heap_pop(heap); cx = cur[2]; cy = cur[3]; ck = Routes.pkey(cx, cy)
        next if closed[ck]
        closed[ck] = true
        return [hpa_route(came, ck), g[ck]] if cx == gx && cy == gy
        Routes::DIRS.each do |dir|
          dx = dir[0]; dy = dir[1]; d = dir[2]
          next unless PokeAccess::World::Probe.step?(cx, cy, d)
          nx = cx + dx; ny = cy + dy
          next if x0 && (nx < x0 || ny < y0 || nx > x1 || ny > y1)
          next if PokeAccess::World::Terrain.ice?(nx, ny) || PokeAccess::World::Terrain.ledge?(nx, ny)
          nk = Routes.pkey(nx, ny)
          next if closed[nk]
          ng = g[ck] + 1
          if g[nk].nil? || ng < g[nk]
            g[nk] = ng; came[nk] = [ck, d]
            heap_push(heap, [ng + (nx - gx).abs + (ny - gy).abs, 0, nx, ny, d])
          end
        end
      end
      nil
    ensure
      @hpa_states += iter.to_i
    end

    # The current map's HPA* graph once whole, built within what the question may spend (hpa_allowance); nil while a
    # cluster is left to build (the question then runs plain A*) or on a map under 2x2. Kept per map, probe mode and
    # cluster side; a change rebuilds the clusters it touches (hpa_touch, hpa_check_tiles).
    def self.hpa_graph
      gr = hpa_current
      return nil unless gr
      a = hpa_allowance
      hpa_build(gr, a[0], a[1])
      hpa_ready?(gr) ? gr : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      @hpa = nil
    end

    # The graph for the map, probe mode and cluster side as they stand, begun afresh with every cluster to build when
    # any changed: the map's size, the portal nodes by cluster (:byc) and their links (:adj), the clusters left in order
    # (:todo, :queued) and the one being built (:work), and what each built cluster's tiles (:tiles) and the tileset's
    # tables (:tileset) were. Nil on a map under 2x2.
    def self.hpa_current
      c = hpa_cluster
      sig = [vehicle_state, c]
      return @hpa if @hpa && @hpa[:sig] == sig
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return @hpa = nil if w < 2 || h < 2
      todo = []
      queued = {}
      (0...((w + c - 1) / c)).each do |cc|
        (0...((h + c - 1) / c)).each { |cr| todo.push(Routes.pkey(cc, cr)) }
      end
      todo.each { |cid| queued[cid] = true }
      @hpa = { :sig => sig, :c => c, :w => w, :h => h, :adj => {}, :byc => {}, :todo => todo, :queued => queued,
               :work => nil, :tiles => {}, :tileset => hpa_tileset, :tiles_due => false }
    end

    # What a question may spend building the graph, as [states, deadline], nil for no bound: half its budget, the rest
    # left to the search that answers while the graph is not whole; by effort half the states a search may take
    # (astar_max, the rest through Limits#less), under a time limit half the budget from now; with no limit, all of it.
    def self.hpa_allowance
      cf = PokeAccess::Config
      case limits.mode
      when :time then [nil, PokeAccess.clock + (cf.route_budget_ms rescue 12).to_i / 2000.0]
      when :none then [nil, nil]
      else [(cf.astar_max rescue 2500).to_i / 2, nil]
      end
    end

    # True once every cluster of the graph is built and its tiles compared since they last changed.
    def self.hpa_ready?(gr); gr[:work].nil? && gr[:todo].empty? && !gr[:tiles_due]; end

    # Builds on a piece at a time (hpa_step) until the graph is whole, max states are walked or the deadline, or the
    # search's own, has passed, the tiles compared before the next piece whenever they changed; never while the
    # probe's answers are unstable or events are lent through, which no graph may keep. The states walked.
    def self.hpa_build(gr, max, deadline)
      probe = PokeAccess::World::Probe
      return 0 if hpa_ready?(gr) || probe.lending? || !probe.stable?
      lim = limits
      s0 = hpa_states
      until hpa_ready?(gr)
        n = hpa_states - s0
        break if (max && n >= max) || (deadline && PokeAccess.clock > deadline) || lim.time_spent?
        gr[:tiles_due] ? hpa_check_tiles(gr) : hpa_step(gr)
      end
      hpa_states - s0
    end

    # One piece of the building: the next cluster opened (hpa_open), one pair of its nodes linked by the presses
    # between them inside it (hpa_low), or, every pair done, the cluster put into the graph (hpa_close).
    def self.hpa_step(gr)
      w = gr[:work]
      unless w
        cid = gr[:todo].shift
        gr[:queued].delete(cid)
        gr[:work] = hpa_open(gr, cid)
        return
      end
      nodes = w[:nodes]
      if w[:j] >= nodes.length
        w[:i] += 1
        w[:j] = w[:i] + 1
        return hpa_close(gr, w) if w[:j] >= nodes.length
      end
      st = Routes::PKEY_STRIDE; box = w[:box]; a = nodes[w[:i]]; b = nodes[w[:j]]
      r = hpa_low(a / st, a % st, b / st, b % st, gr[:c] * gr[:c] * 2, box[0], box[1], box[2], box[3])
      (w[:links][a] << [b, r[1]]; w[:links][b] << [a, r[1]]) if r
      w[:j] += 1
    end

    # The work of building cluster cid: its box, its nodes (the middle of each opening on its four sides, on its side)
    # linked across at one press, the next pair of them to link, and its tiles and the ring its openings read as they
    # stand (hpa_tiles over hpa_ring).
    def self.hpa_open(gr, cid)
      box = hpa_box(gr, cid)
      x0, y0, x1, y1 = box
      nodes = []
      links = {}
      add = lambda do |own, across|
        k = Routes.pkey(own[0], own[1])
        nodes.push(k) unless links[k]
        (links[k] ||= []) << [Routes.pkey(across[0], across[1]), 1]
      end
      hpa_openings(x1, y0, 0, 1, y1 - y0 + 1, 6).each { |x, y| add.call([x, y], [x + 1, y]) } if x1 < gr[:w] - 1
      hpa_openings(x0 - 1, y0, 0, 1, y1 - y0 + 1, 6).each { |x, y| add.call([x + 1, y], [x, y]) } if x0 > 0
      hpa_openings(x0, y1, 1, 0, x1 - x0 + 1, 2).each { |x, y| add.call([x, y], [x, y + 1]) } if y1 < gr[:h] - 1
      hpa_openings(x0, y0 - 1, 1, 0, x1 - x0 + 1, 2).each { |x, y| add.call([x, y + 1], [x, y]) } if y0 > 0
      { :cid => cid, :box => box, :nodes => nodes, :links => links, :i => 0, :j => 1,
        :tiles => hpa_tiles(hpa_ring(gr, box)) }
    end

    # Box [x0, y0, x1, y1] grown by one tile each way, clamped to the map: what a cluster's openings read besides its
    # own tiles, the first row or column of each cluster beside it.
    def self.hpa_ring(gr, box)
      [[box[0] - 1, 0].max, [box[1] - 1, 0].max, [box[2] + 1, gr[:w] - 1].min, [box[3] + 1, gr[:h] - 1].min]
    end

    # The openings across one side of a cluster, asked from (x,y) on along n tiles of (dx,dy) by a step toward d out of
    # each: the middle tile of each run of open steps, as [x, y].
    def self.hpa_openings(x, y, dx, dy, n, d)
      out = []
      i = 0
      while i < n
        if PokeAccess::World::Probe.step?(x + i * dx, y + i * dy, d)
          run0 = i; i += 1
          i += 1 while i < n && PokeAccess::World::Probe.step?(x + i * dx, y + i * dy, d)
          m = (run0 + i - 1) / 2
          out.push([x + m * dx, y + m * dy])
        else
          i += 1
        end
      end
      out
    end

    # Puts a built cluster into the graph: its nodes and their links in place of those it had, and its tiles as they
    # were.
    def self.hpa_close(gr, w)
      cid = w[:cid]
      (gr[:byc][cid] || []).each { |k| gr[:adj].delete(k) }
      if w[:nodes].empty? then gr[:byc].delete(cid) else gr[:byc][cid] = w[:nodes] end
      w[:links].each { |k, edges| gr[:adj][k] = edges }
      gr[:tiles][cid] = w[:tiles]
      gr[:work] = nil
    end

    # The tiles cluster cid spans, as [x0, y0, x1, y1] clamped to the map.
    def self.hpa_box(gr, cid)
      c = gr[:c]; st = Routes::PKEY_STRIDE
      x0 = (cid / st) * c; y0 = (cid % st) * c
      [x0, y0, [x0 + c - 1, gr[:w] - 1].min, [y0 + c - 1, gr[:h] - 1].min]
    end

    # Puts cluster cid back among those to build, the work on it dropped if it was being built.
    def self.hpa_requeue(gr, cid)
      gr[:work] = nil if gr[:work] && gr[:work][:cid] == cid
      return if gr[:queued][cid]
      gr[:queued][cid] = true
      gr[:todo].push(cid)
    end

    # Builds again the clusters whose links a change over tiles may have changed: each tile's own and those of the
    # tiles beside it, across a side where the openings lie.
    def self.hpa_touch(tiles, gr = @hpa)
      return unless gr
      c = gr[:c]; w = gr[:w]; h = gr[:h]
      tiles.each do |x, y|
        [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          nx = x + dx; ny = y + dy
          hpa_requeue(gr, Routes.pkey(nx / c, ny / c)) if nx >= 0 && ny >= 0 && nx < w && ny < h
        end
      end
    end

    # Has the graph compare its clusters' tiles before it is used again: the map's tiles changed somewhere.
    def self.hpa_tiles_due!; @hpa[:tiles_due] = true if @hpa; end

    # Compares each built cluster's tiles and ring (hpa_ring) with what they were when it was built and builds again the
    # clusters around each tile that differs (hpa_touch), a cluster not built yet among them; every cluster when the
    # tileset's tables changed. The cluster being built starts over.
    def self.hpa_check_tiles(gr)
      gr[:tiles_due] = false
      hpa_requeue(gr, gr[:work][:cid]) if gr[:work]
      ts = hpa_tileset
      unless ts == gr[:tileset]
        gr[:tileset] = ts
        gr[:tiles].keys.each { |cid| hpa_requeue(gr, cid) }
        return
      end
      gr[:tiles].keys.each do |cid|
        box = hpa_ring(gr, hpa_box(gr, cid))
        was = gr[:tiles][cid]
        now = hpa_tiles(box)
        next if !now.nil? && now == was
        bw = box[2] - box[0] + 1
        changed = []
        ((box[3] - box[1] + 1) * bw).times do |i|
          changed.push([box[0] + i % bw, box[1] + i / bw]) unless now && was && now[i] == was[i]
        end
        hpa_touch(changed, gr)
      end
    end

    # The tiles of box [x0, y0, x1, y1] as they stand, row by row: each one's tile ids on the map's layers; nil
    # without the map's data.
    def self.hpa_tiles(box)
      d = ($game_map.data rescue nil)
      return nil if d.nil?
      zs = d.respond_to?(:zsize) ? d.zsize : 3
      out = []
      box[1].upto(box[3]) do |y|
        box[0].upto(box[2]) do |x|
          t = []
          zs.times { |z| t.push(d[x, y, z]) }
          out.push(t)
        end
      end
      out
    end

    # The tileset's tables a step's answer reads (passages, priorities, terrain tags), dumped; nil if they cannot be.
    def self.hpa_tileset
      m = $game_map
      ep = PokeAccess::World::Epoch
      Marshal.dump([ep.table(m, :passages), ep.table(m, :priorities), ep.table(m, :terrain_tags)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Drops the graph: a reset, a new map, or an event's end where the passability is not plain.
    def self.hpa_forget; @hpa = nil; end

    # One map frame's building of the graph, HPA_SLICE_MS of it, while HPA* is chosen and the map's moves are plain
    # steps of one tile a press (Routes::Moves.uniform?, speed 1), as the planner asks it then; nothing once the graph
    # is whole.
    def self.hpa_tick
      return unless path_algorithm == :hpa && $game_player && Routes::Moves.uniform? &&
                    Routes::Moves.speed(moves_mode(true, (PokeAccess::Config.edge_relax rescue false))) == 1
      gr = hpa_current
      return if gr.nil? || hpa_ready?(gr)
      with_level_kept do
        gr = hpa_current
        hpa_build(gr, nil, PokeAccess.clock + HPA_SLICE_MS / 1000.0) if gr
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # The bounding box of the two clusters containing a and b, clamped to the map, so the refining A* for
    # an abstract hop stays local.
    def self.pair_box(ax, ay, bx, by, c, w, h)
      [[(ax / c) * c, (bx / c) * c].min, [(ay / c) * c, (by / c) * c].min,
       [[(ax / c) * c + c - 1, (bx / c) * c + c - 1].max, w - 1].min,
       [[(ay / c) * c + c - 1, (by / c) * c + c - 1].max, h - 1].min]
    end

    # The tiles an HPA* route may arrive at: those the target is acted on from (reach_tiles) that a step can enter.
    def self.hpa_arrivals(tx, ty)
      reach_tiles(tx, ty).select do |cx, cy|
        next false unless ($game_map.valid?(cx, cy) rescue false)
        Routes::DIRS.any? { |dx, dy, d| PokeAccess::World::Probe.step?(cx - dx, cy - dy, d) }
      end
    end

    # The abstract search's synthetic goal sink: a sentinel key no real tile can pack to (packed tiles are
    # non-negative), linked at zero cost from every arrival tile so A* selects the cheapest one to reach.
    HPA_SINK = -1

    # HPA* search: start and arrivals joined to their clusters' portals, A* to HPA_SINK guided by Routes::Goal#bound,
    # each hop refined by a live local A*, temporary edges kept off the cached graph. The route, nil out of reach,
    # :fallback for plain A* (the graph not whole yet, among other reasons), or [] when adjacent.
    def self.hpa_search(tx, ty)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      return [] if reach_tiles(tx, ty).include?([px, py])
      gr = hpa_graph
      return :fallback unless gr
      c = gr[:c]; w = gr[:w]; h = gr[:h]; adj = gr[:adj]; byc = gr[:byc]
      st = Routes::PKEY_STRIDE
      start = Routes.pkey(px, py)
      arrivals = hpa_arrivals(tx, ty)
      return :fallback if arrivals.empty?
      goal = Routes::Goal.new(arrivals, tx, ty)
      temp = Hash.new { |hh, k| hh[k] = [] }
      connect = lambda do |sx, sy, sk|
        box = [(sx / c) * c, (sy / c) * c, [(sx / c) * c + c - 1, w - 1].min, [(sy / c) * c + c - 1, h - 1].min]
        (byc[(sx / c) * st + (sy / c)] || []).each do |nk|
          r = hpa_low(sx, sy, nk / st, nk % st, c * c * 2, box[0], box[1], box[2], box[3])
          (temp[sk] << [nk, r[1]]; temp[nk] << [sk, r[1]]) if r
        end
      end
      connect.call(px, py, start)
      arrivals.each do |ax, ay|
        ak = Routes.pkey(ax, ay)
        connect.call(ax, ay, ak)
        temp[ak] << [HPA_SINK, 0]
        if (px / c) == (ax / c) && (py / c) == (ay / c)
          box = [(px / c) * c, (py / c) * c, [(px / c) * c + c - 1, w - 1].min, [(py / c) * c + c - 1, h - 1].min]
          r = hpa_low(px, py, ax, ay, c * c * 2, box[0], box[1], box[2], box[3])
          temp[start] << [ak, r[1]] if r
        end
      end
      openh = []; gg = { start => 0 }; cf = {}; cl = {}; it = 0
      limits = self.limits
      heap_push(openh, [goal.bound(px, py), 0, start])
      found = false
      until openh.empty?
        it += 1
        break if it > 20000 || (limits.mode == :time && limits.spent?(it))
        n = heap_pop(openh)[2]
        next if cl[n]
        cl[n] = true
        if n == HPA_SINK; found = true; break; end
        (adj[n] || []).dup.concat(temp[n]).each do |e|
          m = e[0]; ng = gg[n] + e[1]
          if gg[m].nil? || ng < gg[m]
            gg[m] = ng; cf[m] = n
            hh = (m == HPA_SINK) ? 0 : goal.bound(m / st, m % st)
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
        ax = a / st; ay = a % st; bx = b / st; by = b % st
        box = pair_box(ax, ay, bx, by, c, w, h)
        r = hpa_low(ax, ay, bx, by, (box[2] - box[0] + 1) * (box[3] - box[1] + 1) * 2 + 8, box[0], box[1], box[2], box[3])
        return :fallback unless r
        route.concat(r[0]); i += 1
      end
      route.empty? ? :fallback : route
    rescue StandardError => e
      PokeAccess.swallowed(e)
      :fallback
    end
  end
end

# New tiles have the HPA* graph compare its clusters' tiles, a reset drops it, and a change to an event builds again
# the clusters around the tiles it left or reached, as the probe forgets its answers there.
PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Pathfinder.hpa_tiles_due! }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Pathfinder.hpa_forget }
PokeAccess::World::Events.on_change { |tiles, _r, _how| PokeAccess::Pathfinder.hpa_touch(tiles) }

module PokeAccess
  # Pathfinder, the uniform-grid searches: jump point search and hierarchical A* (HPA*). They only hold where every
  # move is one tile (uniform_grid?), and a scan that meets ice or a ledge falls back to plain A*.
  module Pathfinder
    # What the scans of one jump point search share: the target, the scan steps taken against their budget, and
    # whether a scan met what JPS cannot express (the search then falls back to plain A*).
    JpsScan = Struct.new(:tx, :ty, :steps, :budget, :fallback)

    # Jump point search: an A* over jump points (the next turning or goal tile in a direction), for a uniform grid:
    # the route, nil out of reach, or :fallback for plain A* on ice or a ledge (passable, but a two-tile step).
    def self.jps_search(tx, ty)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      s = JpsScan.new(tx, ty, 0, [(PokeAccess::Config.astar_max rescue 2500).to_i * 8, 20000].max, false)
      heap = []; g = { pkey(px, py) => 0 }; came = {}; closed = {}; iter = 0
      deadline = search_deadline
      bestk = pkey(px, py); bestd = (px - tx).abs + (py - ty).abs
      heap_push(heap, [bestd, 0, px, py, 0])
      until heap.empty?
        iter += 1
        return :fallback if s.fallback
        break if over_budget?(iter, deadline)
        cur = heap_pop(heap); cx = cur[2]; cy = cur[3]; ck = pkey(cx, cy)
        next if closed[ck]
        closed[ck] = true
        md = (cx - tx).abs + (cy - ty).abs
        if md < bestd; bestd = md; bestk = ck; end
        return jps_route(came, ck) if target_reached?(cx, cy, tx, ty)
        DIRS.each do |dir|
          dx = dir[0]; dy = dir[1]; d = dir[2]
          jp = jps_jump(s, cx, cy, dx, dy, d)
          return :fallback if s.fallback
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
      return :fallback if s.fallback
      return jps_route(came, bestk) if bestd <= 2 && bestk != pkey(px, py)
      nil
    end

    # The next jump point from (x,y) in one direction (a goal tile, a forced neighbour, or where a perpendicular scan
    # finds one): [x,y], or nil at a wall; ice, a ledge, the step budget or the depth cap set s.fallback.
    def self.jps_jump(s, x, y, dx, dy, d, depth = 0)
      if depth > 80
        s.fallback = true; return nil
      end
      loop do
        s.steps += 1
        if s.steps > s.budget
          s.fallback = true; return nil
        end
        return nil unless passable_at?(x, y, d)
        nx = x + dx; ny = y + dy
        if (PokeAccess::Terrain.ice_at?(nx, ny) rescue false) || (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
          s.fallback = true; return nil
        end
        return [nx, ny] if target_reached?(nx, ny, s.tx, s.ty)
        perps = (dx != 0) ? [8, 2] : [4, 6]
        return [nx, ny] if perps.any? { |p| !passable_at?(x, y, p) && passable_at?(nx, ny, p) }
        if dx != 0
          return [nx, ny] if !jps_jump(s, nx, ny, 0, -1, 8, depth + 1).nil? || !jps_jump(s, nx, ny, 0, 1, 2, depth + 1).nil?
        else
          return [nx, ny] if !jps_jump(s, nx, ny, -1, 0, 4, depth + 1).nil? || !jps_jump(s, nx, ny, 1, 0, 6, depth + 1).nil?
        end
        return nil if s.fallback
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

    # HPA*: the side, in tiles, of the square clusters the map is cut into, with portals at the openings between them.
    HPA_CLUSTER = 10

    # Bounded A* between two exact tiles in an optional [x0,y0,x1,y1] box under a node cap: [directions, cost] or nil.
    # Ice and ledges count as walls, so a route that needs them ends in hpa_search's :fallback to plain A*.
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
          next if (PokeAccess::Terrain.ice_at?(nx, ny) rescue false) || (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
          nk = pkey(nx, ny)
          next if closed[nk]
          ng = g[ck] + 1
          if g[nk].nil? || ng < g[nk]
            g[nk] = ng; came[nk] = [ck, d]
            heap_push(heap, [ng + (nx - gx).abs + (ny - gy).abs, 0, nx, ny, d])
          end
        end
      end
      nil
    end

    # The current map's abstract graph, or nil: portals across clusters linked at cost 1, those within one by a
    # bounded local A*; cached per [map, surfing, diving].
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

    # The tiles an HPA* route may arrive at: the target and its orthogonal neighbours, those a step can enter (the
    # graph-side form of target_reached?).
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

    # Hierarchical search: start and arrivals joined to their clusters' portals, A* to HPA_SINK, each hop refined by a
    # live local A*. The route, nil out of reach, :fallback for plain A*, or [] when adjacent; neighbour lists are
    # merged on a dup, so a search's temporary edges stay out of the cached graph.
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
  end
end

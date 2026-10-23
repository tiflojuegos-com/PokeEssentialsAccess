module PokeAccess
  module Routes
    # What a search may end on: the tiles that count as getting there (on either bridge level), the least Manhattan
    # distance to them, and the tile the route is for.
    class Goal
      attr_reader :tiles, :tx, :ty

      # Acting on (tx,ty): on it, beside it, or across a counter from it (Pathfinder.reach_tiles).
      def self.near(tx, ty); new(PokeAccess::Pathfinder.reach_tiles(tx, ty), tx, ty); end

      # Standing on (tx,ty) itself: a shore to push off from, a spot to dive at.
      def self.onto(tx, ty); new([[tx, ty]], tx, ty); end

      # Standing on any of tiles, for the target at (tx,ty): the tiles a one-sided doorway is walked into from.
      def initialize(tiles, tx, ty)
        @tiles = tiles
        @tx = tx
        @ty = ty
        @hit = {}
        tiles.each { |x, y| @hit[Routes.pkey(x, y)] = true }
        @ring = tiles.include?([tx, ty]) && tiles.all? { |x, y| (x - tx).abs + (y - ty).abs <= 1 }
        @slack = tiles.length > 1 ? 1 : 0
      end

      # True when (x,y) is one of the goal's tiles; the boulders a push search moved (moved) do not matter to it.
      def hit?(x, y, _moved = nil); @hit.key?(Routes.pkey(x, y)); end

      # The least Manhattan distance from (x,y) to the goal's tiles: one less than to the target when they are the
      # target and tiles beside it, else the nearest of them.
      def bound(x, y, _moved = nil)
        if @ring
          d = (@tx - x).abs + (@ty - y).abs
          return d > @slack ? d - @slack : 0
        end
        best = nil
        @tiles.each do |gx, gy|
          d = (gx - x).abs + (gy - y).abs
          best = d if best.nil? || d < best
        end
        best
      end

      # The Manhattan distance from (x,y) to the target tile: the estimate the searches had before the exact one.
      def reach(x, y); (@tx - x).abs + (@ty - y).abs; end
    end

    # How a route is priced, as one Integer the frontier orders by: its presses (an assisted step adds GATE_COST, see
    # route_gates) and its turns, weighed by the route style: the shortest (the fewest presses, then the fewest turns),
    # balanced (a turn costs a press, then the fewest turns) or the straightest (the fewest turns, then presses).
    class CostModel
      K = 4096
      STYLES = [:shortest, :balanced, :straightest]
      attr_reader :style

      def initialize(style); @style = STYLES.include?(style) ? style : :shortest; end

      # The cost of a move of presses presses, turned from the way the route came or not, through a gate or not.
      def step(presses, turned, gated)
        p = gated ? presses + PokeAccess::Pathfinder::GATE_COST : presses
        t = turned ? 1 : 0
        case @style
        when :balanced then (p + t) * K + t
        when :straightest then t * K + p
        else p * K + t
        end
      end

      # The least cost of a route of at least presses presses: the search's estimate, in cost.
      def least(presses); @style == :straightest ? presses : presses * K; end

      # What a turn costs: a state on a tile that costs this much more than one already closed there can never do better
      # (dominance).
      def turn_unit
        case @style
        when :balanced then K + 1
        when :straightest then K
        else 1
        end
      end
    end

    # A search's answer: :found with its route (a Pathfinder::Route of key presses) and what it costs (CostModel),
    # :exhausted when no route exists within the moves, or :cut when the budget ran out first; expanded counts the tiles
    # it examined, and algo names what answered (a frontier of Pathfinder::ALGORITHMS, or :flood for the flood's own way).
    SearchResult = Struct.new(:status, :route, :expanded, :algo, :cost)

    # What one run of Search fills, kept by a Flood to answer from and to go on from: the least cost of each state, its
    # link back, the states closed, per tile the least cost and the state that has it, the budget it runs under, and
    # the frontier it stopped at.
    Tables = Struct.new(:least, :came, :closed, :settled, :first, :limits, :heap)

    # A lower bound, in presses, from a tile to a goal on a map where a press may cover more than one tile: the plain
    # one (Moves::Strides), or the least through chains of the touch events' shortcuts (Moves.shortcuts, a Dijkstra over
    # their landings). It never overstates and falls by at most a press's worth a press, so A* over it stays exact.
    class Bound
      # The most work (shortcuts times their landings) a bound is built with; past it a search goes without one.
      WORK = 4096

      # The bound to goal with strides on plain moves and shortcuts [from x, from y, presses, landing x, y], or nil
      # when they are too many (WORK). A shortcut that covers no more ground than its presses could walk never lowers
      # the bound, and is left out.
      def self.for(goal, strides, cuts)
        gain = cuts.select { |c| strides.presses(c[3] - c[0], c[4] - c[1]) > c[2] }
        lands = gain.map { |c| [c[3], c[4]] }.uniq
        gain.length * lands.length > WORK ? nil : new(goal, strides, gain, lands)
      end

      # A bound from shortcuts that each gain ground, and their landings, as Bound.for gives them; none for the plain
      # one alone.
      def initialize(goal, strides, cuts = [], lands = [])
        @goal = goal
        @strides = strides
        @seen = {}
        rest = landings(cuts, lands)
        via = cuts.map { |c| [c[0], c[1], c[2] + rest[[c[3], c[4]]]] }
        @via = via.sort_by { |v| v[2] }
      end

      # The bound at (x,y), kept once worked out.
      def at(x, y)
        k = Routes.pkey(x, y)
        v = @seen[k]
        return v if v
        best = plain(x, y)
        @via.each do |fx, fy, rest|
          break if rest >= best
          d = @strides.presses(fx - x, fy - y) + rest
          best = d if d < best
        end
        @seen[k] = best
      end

      # The fewest presses from (x,y) to a tile of the goal by the strides alone.
      def plain(x, y)
        best = nil
        @goal.tiles.each do |gx, gy|
          d = @strides.presses(gx - x, gy - y)
          best = d if best.nil? || d < best
        end
        best
      end

      # The bound from each landing: the plain one, or on through shortcuts, settled nearest first; a landing settled
      # passes its bound to the shortcuts that land there, and they to the landings still open.
      def landings(cuts, lands)
        h = {}
        lands.each { |l| h[l] = plain(l[0], l[1]) }
        into = {}
        cuts.each { |c| (into[[c[3], c[4]]] ||= []).push(c) }
        open = lands.dup
        until open.empty?
          i = 0
          (1...open.length).each { |j| i = j if h[open[j]] < h[open[i]] }
          l = open.delete_at(i)
          (into[l] || []).each do |c|
            via = c[2] + h[l]
            open.each do |o|
              v = @strides.presses(c[0] - o[0], c[1] - o[1]) + via
              h[o] = v if v < h[o]
            end
          end
        end
        h
      end
    end

    # One best-first search over the moves of Moves, from the player's tile and bridge level to a goal, priced by a
    # CostModel, with the frontier the algorithm names (a heap weighted by Pathfinder.algo_weights, a queue for
    # breadth-first, a stack for depth-first) and an admissible estimate (Moves.strides, Bound).
    module Search
      # The route to goal with the moves of mode in the route style, searched with algo, as a SearchResult. The
      # straightest is kept within 5/4 of the shortest plus 4 presses; past that, the balanced one stands in for it.
      def self.route(goal, mode, algo)
        style = (PokeAccess::Config.route_style rescue :shortest)
        est = bound_for(goal, mode)
        r = best(goal, CostModel.new(style), mode, algo, est)
        return r unless style == :straightest && r.status == :found
        len = r.route.length
        return r if len * 4 <= 5 * (lower(goal, est) || 0) + 16
        short = best(goal, CostModel.new(:shortest), mode, algo, est)
        return r if short.status != :found || len * 4 <= 5 * short.route.length + 16
        best(goal, CostModel.new(:balanced), mode, algo, est)
      end

      # One A* toward goal in the route style, past the regions router and the kept floods: for a search that keeps
      # tiles off (Moves.with_closed), which those never saw.
      def self.fresh(goal, mode)
        style = (PokeAccess::Config.route_style rescue :shortest)
        run(goal, CostModel.new(style), mode, :astar, bound_for(goal, mode))
      end

      # One search with the estimate est, answered first by the regions router (when chosen) or a kept flood; when the
      # budget cuts it, by walked_on, a new flood or a :reach search; under a deadline, quick_first instead.
      def self.best(goal, cost, mode, algo, est)
        routed = algo == :regions ? Regions.searched(goal, cost, mode, est) : nil
        return routed if routed
        kept = Flood.kept(cost, mode)
        known = kept && kept.route_to(goal)
        return known if known
        return quick_first(goal, cost, mode, algo, est) if PokeAccess::Pathfinder.limits.mode == :time
        r = run(goal, cost, mode, algo, est)
        return r unless r.status == :cut
        again = walked_on(goal, cost, mode, algo, est)
        unless again
          f = Flood.for(cost, mode)
          again = f && f.route_to(goal)
          again ||= run(goal, cost, mode, algo, :reach) if steered?(algo)
        end
        return r unless again
        again.expanded += r.expanded
        again
      end

      # True for an algorithm whose frontier the estimate orders, so a search again with :reach may go elsewhere;
      # Dijkstra weighs it at nothing, and breadth- and depth-first take no priorities.
      def self.steered?(algo)
        algo != :bfs && algo != :dfs && PokeAccess::Pathfinder.algo_weights(algo)[1] > 0
      end

      # With the regions router chosen, its route after a search cut short, the regions on foot walked on first
      # (Regions#renew); nil while they cannot tell.
      def self.walked_on(goal, cost, mode, algo, est)
        return nil unless algo == :regions && mode == Moves::LEDGE
        Regions.foot.renew
        Regions.searched(goal, cost, mode, est)
      end

      # Under a deadline: the search of before with all the time there is, so no route it finds is lost, then with the
      # time left the one with est, kept to routes that cost no more (its cap); the better that finished.
      def self.quick_first(goal, cost, mode, algo, est)
        quick = run(goal, cost, mode, algo, :reach)
        return quick unless quick.status == :found
        exact = run(goal, cost, mode, algo, est, quick.cost)
        found = exact.status == :found ? exact : quick
        found.expanded = quick.expanded + exact.expanded
        found
      end

      # The fewest presses the route from the player can take, as the estimate est (bound_for) says; nil when there is
      # no telling.
      def self.lower(goal, est)
        return nil unless est
        px = $game_player.x; py = $game_player.y
        est.is_a?(Bound) ? est.at(px, py) : (goal.bound(px, py) + est - 1) / est
      end

      # The estimate a search toward goal with mode takes: 1 where a press covers one tile whichever way, a Bound by
      # the map's strides where a ledge hop covers two, and through the shortcuts on a map whose touch events move the
      # player; nil where there is no telling (on a map with bridges or too many shortcuts, too).
      def self.bound_for(goal, mode)
        strides = Moves.strides(mode)
        return nil unless strides
        unless Moves.relocating?
          return strides.plain? ? 1 : Bound.new(goal, strides)
        end
        lvl = PokeAccess::Pathfinder.bridge_level
        return nil if Moves.crowded?(lvl, mode)
        cuts = Moves.shortcuts(lvl, mode)
        return nil unless cuts
        bound = Bound.for(goal, strides, cuts)
        Moves.crowd!(lvl, mode) unless bound
        bound
      end

      # One search with the estimate est: the most tiles a press may cover, a Bound, nil for none or :reach (quick, not
      # admissible); ties go to the costlier and the budget counts tiles. Routes past cap are dropped; with no goal it
      # floods to :exhausted or the budget, t kept to go on from; with :jps (shortest style, on foot), jump points.
      def self.run(goal, cost, mode, algo, est, cap = nil, t = nil)
        pf = PokeAccess::Pathfinder
        mv = Moves
        px = $game_player.x; py = $game_player.y
        l0 = pf.bridge_level
        gw, hw = pf.algo_weights(algo)
        heaped = algo != :bfs && algo != :dfs
        jumps = algo == :jps && goal && cost.style == :shortest && (mode & (Moves::ASSIST | Moves::SURF_PLAN)) == 0
        scan = jumps ? Jumps.budget(pf.limits) : nil
        name = jumps ? :jps : ((algo == :jps || algo == :hpa || algo == :regions) ? :astar : algo)
        unit = cost.turn_unit
        start = pf.skey(px, py, l0) * 5 + 4
        t ||= Tables.new({}, {}, {}, {}, nil, pf.limits)
        least = t.least
        fresh = least.empty?
        least[start] = 0
        came = t.came
        closed = t.closed
        settled = t.settled
        first_of = t.first
        heap = (t.heap ||= [])
        queue = []
        head = 0
        if fresh
          item = [hw * estimate(goal, cost, est, px, py), 0, px, py, l0, start]
          heaped ? pf.heap_push(heap, item) : queue.push(item)
        end
        limits = t.limits
        iter = 0
        loop do
          break if heaped ? heap.empty? : head >= queue.length
          cur = if heaped then pf.heap_pop(heap)
                elsif algo == :dfs then queue.pop
                else
                  head += 1
                  queue[head - 1]
                end
          g = -cur[1]; cx = cur[2]; cy = cur[3]; cl = cur[4]; cs = cur[5]
          next if closed[cs] || g > least[cs]
          tile = cs / 5
          s = settled[tile]
          next if s && g >= s + unit
          closed[cs] = true
          first = s.nil? || g < s
          if first
            iter += 1
            if limits.spent?(iter)
              closed.delete(cs)
              pf.heap_push(heap, cur) if heaped
              return SearchResult.new(:cut, nil, iter, name)
            end
            settled[tile] = g
            first_of[tile] = cs if first_of
          end
          return SearchResult.new(:found, path_to(came, cs), iter, name, g) if goal && goal.hit?(cx, cy)
          pf.use_level(cl)
          from = cs % 5
          if jumps
            ways = Jumps.ways(cx, cy, from, mode)
            k = 0
            while k < ways.length
              i = ways[k]
              k += 1
              dir = DIRS[i]
              f = mv.fast(cx, cy, dir, mode)
              next if f.nil?
              if f == true
                j = Jumps.jump(cx, cy, i, mode, goal, scan)
                if j == :over
                  limits.cut!
                  return SearchResult.new(:cut, nil, iter, name)
                end
                next if j.nil?
                nx = j[0]; ny = j[1]; nl = cl; presses = j[2]; gate = nil; warp = false; arrive = i
              else
                n = mv.step(cx, cy, cl, dir, mode)
                next if n.nil?
                nx = n.x; ny = n.y; nl = n.level; presses = n.presses; gate = n.gate; warp = n.warp; arrive = 4
              end
              nt = pf.skey(nx, ny, nl)
              ns = nt * 5 + arrive
              next if closed[ns]
              ng = g + cost.step(presses, from != 4 && from != i, gate)
              s2 = settled[nt]
              next if s2 && ng >= s2 + unit
              old = least[ns]
              next unless old.nil? || ng < old
              h = estimate(goal, cost, est, nx, ny)
              next if cap && ng + h > cap
              least[ns] = ng
              came[ns] = [cs, dir[2], presses, warp]
              pf.heap_push(heap, [gw * ng + hw * h, -ng, nx, ny, nl, ns])
            end
            next
          end
          i = first ? 0 : from
          last = first ? 4 : from + 1
          while i < last
            dir = DIRS[i]
            i += 1
            f = mv.fast(cx, cy, dir, mode)
            next if f.nil?
            if f == true
              nx = cx + dir[0]; ny = cy + dir[1]; nl = cl; presses = 1; gate = nil; warp = false
            else
              n = mv.step(cx, cy, cl, dir, mode)
              next if n.nil?
              nx = n.x; ny = n.y; nl = n.level; presses = n.presses; gate = n.gate; warp = n.warp
            end
            nt = pf.skey(nx, ny, nl)
            ns = nt * 5 + i - 1
            next if closed[ns]
            ng = g + cost.step(presses, from != 4 && from != i - 1, gate)
            s2 = settled[nt]
            next if s2 && ng >= s2 + unit
            old = least[ns]
            next unless old.nil? || (heaped && ng < old)
            h = estimate(goal, cost, est, nx, ny)
            next if cap && ng + h > cap
            least[ns] = ng
            came[ns] = [cs, dir[2], presses, warp]
            item = [gw * ng + hw * h, -ng, nx, ny, nl, ns]
            heaped ? pf.heap_push(heap, item) : queue.push(item)
          end
        end
        SearchResult.new(:exhausted, nil, iter, name)
      end

      # The estimate at (x,y) in cost (see run).
      def self.estimate(goal, cost, est, x, y)
        return cost.least(goal.reach(x, y)) if est == :reach
        return 0 if est.nil?
        return cost.least(est.at(x, y)) if est.is_a?(Bound)
        cost.least((goal.bound(x, y) + est - 1) / est)
      end

      # The key presses of the search's route to state s, with the transfers on the way as its rooms and warps.
      def self.path_to(came, s)
        path = PokeAccess::Pathfinder::Route.new
        tails = []
        while (link = came[s])
          p, d, presses, warp = link
          tails.push(path.length) if warp
          presses.times { path.unshift(d) }
          s = p
        end
        path.rooms = tails.length
        path.warps = tails.reverse.map { |tail| path.length - tail - 1 }
        path
      end
    end
  end
end

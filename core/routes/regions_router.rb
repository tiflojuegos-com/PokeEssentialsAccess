module PokeAccess
  module Routes
    # The regions as a router (path_algorithm :regions, the default): once every state is walked, an A* over the moves
    # the walk kept, priced by the route style as the search prices its own, without asking the engine. The same moves
    # give the fewest presses from the player to any tile (presses_to), which the locator orders by, and what the search
    # that moves boulders starts from: the presses from any tile to its goal (presses_back) and how far boulders that
    # can move let the player get (past_boulders).
    class Regions
      # The index in DIRS of each direction.
      DIR_INDEX = DIRS.inject({}) { |h, s| h[s[2]] = DIRS.index(s); h }
      NONE = [].freeze

      # The route to goal by cost and est, as a SearchResult replayed to check it ends on goal; nil, for the search to
      # answer, when the router cannot tell or its route ends elsewhere (a walking NPC the regions let through).
      def self.searched(goal, cost, mode, est)
        return nil unless mode == Moves::LEDGE
        r = foot.route(goal, est, cost)
        return nil unless r
        route, taken, g = r
        return SearchResult.new(:exhausted, nil, taken, :regions) if route == :none
        pf = PokeAccess::Pathfinder
        last = Moves.trace($game_player.x, $game_player.y, pf.bridge_level, route, pf.replay_mode).last
        ends = route.empty? || (last && goal.hit?(last.x, last.y))
        ends ? SearchResult.new(:found, route, taken, :regions, g) : nil
      end

      # The route from the player's state to goal by cost and est, as [route, states taken, cost], route :none when
      # there is none; nil when the regions cannot tell. Its states close and prune as Search.run's, so costs match.
      def route(goal, est, cost)
        return nil if @dropped || !done? || $game_player.nil?
        pf = PokeAccess::Pathfinder
        src = @id[pf.skey($game_player.x, $game_player.y, pf.bridge_level)]
        return nil unless src
        out = moves_out
        unit = cost.turn_unit
        start = src * 5 + 4
        least = { start => 0 }
        came = {}
        closed = {}
        settled = {}
        heap = []
        taken = 0
        pf.heap_push(heap, [cost.least(presses_left(goal, est, src)), 0, start])
        until heap.empty?
          cur = pf.heap_pop(heap)
          g = -cur[1]
          s = cur[2]
          next if closed[s] || g > least[s]
          i = s / 5
          seen = settled[i]
          next if seen && g >= seen + unit
          closed[s] = true
          first = seen.nil? || g < seen
          if first
            taken += 1
            settled[i] = g
          end
          t = @keys[i] >> 1
          x = t / PKEY_STRIDE
          y = t % PKEY_STRIDE
          return [path_back(came, s), taken, g] if goal.hit?(x, y)
          from = s % 5
          specials = out[i]
          k = 0
          last = specials ? 4 + specials.length : 4
          while k < last
            if k < 4
              b = k
              k += 1
              next if (@mask[i] & (1 << b)) == 0 || !(first || b == from)
              j = @step[i * 4 + b]
              presses = 1
              warp = false
            else
              j, b, presses, warp = specials[k - 4]
              k += 1
              next unless first || b == from
            end
            ns = j * 5 + b
            next if closed[ns]
            ng = g + cost.step(presses, from != 4 && from != b, false)
            s2 = settled[j]
            next if s2 && ng >= s2 + unit
            old = least[ns]
            next unless old.nil? || ng < old
            least[ns] = ng
            came[ns] = [s, b, presses, warp]
            pf.heap_push(heap, [ng + cost.least(presses_left(goal, est, j)), -ng, ns])
          end
        end
        [:none, taken, nil]
      end

      # The fewest presses from the player's state to any of tiles (on either bridge level) by the walk's moves; nil
      # where the walk reached none of them, or while the regions cannot tell (see presses_from_player).
      def presses_to(tiles)
        return Regions.for(@variant).presses_to(tiles) if @dropped
        best = presses_from_player
        return nil unless best
        states_on(tiles).map { |i| best[i] }.compact.min
      end

      # The fewest presses from the player's state to each state the walk reached, by state index (nil if unreached),
      # after walking on within the allowance, kept while the walk and the player's state stand; nil if it cannot tell.
      def presses_from_player
        src = root
        return nil unless src
        ask unless done?
        return nil unless done?
        key = [@version, src]
        return @dist if @dist_key == key
        @dist_key = key
        @dist = spread(links(false), [src], {}, 0)
      end

      # The fewest presses from each state the walk reached to any of tiles, by state key, along its moves taken backward;
      # stepping onto a tile of dear costs price more. A state with no way there is FAR once a whole walk tells so
      # (sure_no?), else left out. nil while the regions cannot tell.
      def presses_back(tiles, dear, price)
        return Regions.for(@variant).presses_back(tiles, dear, price) if @dropped
        return nil unless root
        ask unless done?
        return nil unless done?
        none = sure_no? ? FAR : nil
        best = spread(links(true), states_on(tiles), dear, price)
        out = {}
        best.each_index do |i|
          d = best[i] || none
          out[@keys[i]] = d if d
        end
        out
      end

      # Goes from the player's state along the walk's moves, the boulders of rocks (by tile key) walls but for those in
      # open: nil once on one of tiles, else the boulders it saw could move, by tile key. The block says whether boulder
      # rock moves from (x,y) along dir; with grow, one that does joins open and the way goes on past it.
      def past_boulders(tiles, rocks, open, grow)
        pf = PokeAccess::Pathfinder
        goals = {}
        states_on(tiles).each { |i| goals[i] = true }
        sides = boulder_sides(rocks)
        specials = moves_out
        src = root
        seen = { src => true }
        stack = [src]
        bumped = {}
        movable = {}
        until stack.empty?
          i = stack.pop
          return nil if goals[i]
          t = @keys[i] >> 1
          shut = 0
          (sides[t] || NONE).each do |rock, way|
            next if open[rock]
            shut |= 1 << way
            (bumped[rock] ||= []).push(i)
            next if movable[rock] || !block_given?
            pf.use_level(@levels[i])
            next unless yield(rock, t / PKEY_STRIDE, t % PKEY_STRIDE, DIRS[way])
            movable[rock] = true
            next unless grow
            open[rock] = true
            stack.concat(bumped[rock])
          end
          b = 0
          while b < 4
            if (@mask[i] & (1 << b)) != 0 && (shut & (1 << b)) == 0
              j = @step[i * 4 + b]
              unless seen[j]
                seen[j] = true
                stack.push(j)
              end
            end
            b += 1
          end
          (specials[i] || NONE).each do |to, way, _presses, _warp|
            next if seen[to] || (shut & (1 << way)) != 0
            tile = @keys[to] >> 1
            next if rocks[tile] && !open[tile]
            seen[to] = true
            stack.push(to)
          end
        end
        movable
      end

      # The tile beside each of the boulders of rocks and the way to it from there: tile key => [[boulder's key, index in
      # DIRS], ...].
      def boulder_sides(rocks)
        out = {}
        rocks.each_key do |rock|
          x = rock / PKEY_STRIDE
          y = rock % PKEY_STRIDE
          DIRS.each_index { |b| (out[Routes.pkey(x - DIRS[b][0], y - DIRS[b][1])] ||= []).push([rock, b]) }
        end
        out
      end

      # The states the walk reached on tiles (on either bridge level), as indices.
      def states_on(tiles)
        pf = PokeAccess::Pathfinder
        out = []
        tiles.each do |x, y|
          [0, 1].each do |l|
            i = @id[pf.skey(x, y, l)]
            out.push(i) if i
          end
        end
        out
      end

      # The fewest presses along links from the states of first to each state, by state index (nil if unreached); going
      # on from a state on a tile of dear costs price more.
      def spread(links, first, dear, price)
        best = Array.new(@keys.length)
        first.each { |i| best[i] = 0 }
        buckets = [first]
        d = 0
        while d < buckets.length
          list = buckets[d]
          k = 0
          while list && k < list.length
            i = list[k]
            k += 1
            next unless best[i] == d
            adj = links[i]
            next unless adj
            base = dear[@keys[i] >> 1] ? d + price : d
            e = 0
            while e < adj.length
              j = adj[e]
              nd = base + adj[e + 1]
              e += 2
              next unless best[j].nil? || nd < best[j]
              best[j] = nd
              (buckets[nd] ||= []).push(j)
            end
          end
          d += 1
        end
        best
      end

      # The moves by state index as [state, presses, ...]: those out of each state, or with back those into it; kept
      # while the walk stands.
      def links(back)
        unless @links_version == @version
          @links_version = @version
          @links = {}
        end
        @links[back] ||= begin
          out = Array.new(@keys.length)
          @keys.each_index do |i|
            b = 0
            while b < 4
              if (@mask[i] & (1 << b)) != 0
                j = @step[i * 4 + b]
                (out[back ? j : i] ||= []).push(back ? i : j, 1)
              end
              b += 1
            end
          end
          m = @moves
          k = 0
          while k < m.length
            (out[back ? m[k + 1] : m[k]] ||= []).push(back ? m[k] : m[k + 1], m[k + 3])
            k += 5
          end
          out
        end
      end

      # The fewest presses from state i to goal the estimate allows (0 with none).
      def presses_left(goal, est, i)
        return 0 if est.nil?
        t = @keys[i] >> 1
        x = t / PKEY_STRIDE
        y = t % PKEY_STRIDE
        est.is_a?(Bound) ? est.at(x, y) : (goal.bound(x, y) + est - 1) / est
      end

      # The moves other than plain steps, by the state they leave: i => [[to, index in DIRS, presses, transfer], ...],
      # kept while the walk stands.
      def moves_out
        return @moves_out if @moves_out_version == @version
        out = {}
        m = @moves
        k = 0
        while k < m.length
          (out[m[k]] ||= []).push([m[k + 1], DIR_INDEX[m[k + 2]], m[k + 3], m[k + 4] == 1])
          k += 5
        end
        @moves_out_version = @version
        @moves_out = out
      end

      # The key presses back to state s along came, with the transfers on the way as its rooms and warps.
      def path_back(came, s)
        path = PokeAccess::Pathfinder::Route.new
        tails = []
        while (link = came[s])
          tails.push(path.length) if link[3]
          link[2].times { path.unshift(DIRS[link[1]][2]) }
          s = link[0]
        end
        path.rooms = tails.length
        path.warps = tails.reverse.map { |tail| path.length - tail - 1 }
        path
      end
    end
  end
end

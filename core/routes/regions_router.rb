module PokeAccess
  module Routes
    # The regions as a router (path_algorithm :regions, the default): once every state is walked, an A* over the moves
    # the walk kept, priced by the route style as the search prices its own, without asking the engine. The same moves
    # give the fewest presses from the player to any tile (presses_to), which the locator orders by.
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
        pf = PokeAccess::Pathfinder
        out = nil
        tiles.each do |x, y|
          [0, 1].each do |l|
            i = @id[pf.skey(x, y, l)]
            d = i && best[i]
            out = d if d && (out.nil? || d < out)
          end
        end
        out
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
        out = moves_out
        step = @step
        mask = @mask
        best = Array.new(@keys.length)
        best[src] = 0
        buckets = [[src]]
        d = 0
        while d < buckets.length
          list = buckets[d]
          k = 0
          while list && k < list.length
            i = list[k]
            k += 1
            next unless best[i] == d
            m = mask[i]
            b = 0
            while b < 4
              if (m & (1 << b)) != 0
                j = step[i * 4 + b]
                if best[j].nil? || d + 1 < best[j]
                  best[j] = d + 1
                  (buckets[d + 1] ||= []).push(j)
                end
              end
              b += 1
            end
            (out[i] || NONE).each do |j, _b, presses, _warp|
              nd = d + presses
              next unless best[j].nil? || nd < best[j]
              best[j] = nd
              (buckets[nd] ||= []).push(j)
            end
          end
          d += 1
        end
        @dist_key = key
        @dist = best
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

module PokeAccess
  module Routes
    # Where a way across water leaves the ground walked on foot: one search from the player with surfing allowed
    # (Moves::SURF_PLAN), priced in the route style, toward the tiles a surf ends on, and on its way the last tile
    # walked before the water.
    module Launch
      # The states one question's search may take in effort mode.
      NODES = 20000

      # [x, y, facing] of the last tile walked on the cheapest way to goal, where it takes to water (the block tells a
      # walked tile); nil when it crosses no water or none is found within NODES (effort mode) or the deadline.
      def self.toward(goal, cost, include_field = false, &walked)
        mode = Moves::LEDGE | Moves::SURF_PLAN
        PokeAccess::Pathfinder.searching do |op|
          lim = op.mode == :effort ? Limits.new(:effort, NODES, 0) : op
          t = Tables.new({}, {}, {}, {}, {}, lim)
          r = Search.run(goal, cost, mode, :astar, Search.bound_for(goal, mode), nil, t)
          op.cut! if r.status == :cut && !lim.equal?(op)
          s = r.status == :found ? reached(t, goal) : nil
          s ? push_off(t, s, include_field, &walked) : nil
        end
      end

      # The first state of the one goal tile the search settled (on either bridge level), else the state that ends on a
      # move onto its entry (Search.entered), or nil.
      def self.reached(t, goal)
        pf = PokeAccess::Pathfinder
        goal.tiles.each do |x, y|
          pf::LEVELS.each do |l|
            next unless goal.floor_ok?(l)
            k = pf.skey(x, y, l)
            return t.first[k] if t.settled[k]
          end
        end
        es = goal.entry && Search.entry_state(goal.entry)
        es && t.came[es] ? es : nil
      end

      # First push-off from reachable shore, or a waterfall climb earlier in the route when returning field actions.
      # A push-off stays [x, y, facing]; a climb adds :waterfall.
      def self.push_off(t, s, include_field)
        links = []
        while (link = t.came[s])
          links.push([link[0], s, link[1]])
          s = link[0]
        end
        links.reverse_each do |p, c, d|
          px, py = tile_of(p)
          cx, cy = tile_of(c)
          return [px, py, d] if yield(px, py) && !yield(cx, cy) && Moves.surf_water?(cx, cy)
          if include_field && d == 8 && px == cx && cy < py - 1 && Moves.surf_water?(px, py) &&
             Moves.waterfall_ascent(px, py - 1) == [cx, cy]
            return [px, py, d, :waterfall]
          end
        end
        nil
      end

      # The [x, y] of a search state (Search.run: the tile's state key times 5 and the way it was arrived from), or of the
      # tile a route's last move steps onto (Search.entry_state).
      def self.tile_of(s)
        k = s < 0 ? -1 - s : s / 5 / 4
        [k / PKEY_STRIDE, k % PKEY_STRIDE]
      end
    end
  end
end

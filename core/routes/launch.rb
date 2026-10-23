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
      def self.toward(goal, cost, &walked)
        mode = Moves::LEDGE | Moves::SURF_PLAN
        PokeAccess::Pathfinder.searching do |op|
          lim = op.mode == :effort ? Limits.new(:effort, NODES, 0) : op
          t = Tables.new({}, {}, {}, {}, {}, lim)
          r = Search.run(goal, cost, mode, :astar, Search.bound_for(goal, mode), nil, t)
          op.cut! if r.status == :cut && !lim.equal?(op)
          s = r.status == :found ? reached(t, goal.tiles) : nil
          s ? push_off(t, s, &walked) : nil
        end
      end

      # The first state of the one goal tile the search settled (on either bridge level), or nil.
      def self.reached(t, tiles)
        pf = PokeAccess::Pathfinder
        tiles.each do |x, y|
          [0, 1].each do |l|
            k = pf.skey(x, y, l)
            return t.first[k] if t.settled[k]
          end
        end
        nil
      end

      # The first move on the way to state s from a tile walked to into water not walked to, as [x, y, facing], or nil.
      def self.push_off(t, s)
        links = []
        while (link = t.came[s])
          links.push([link[0], s, link[1]])
          s = link[0]
        end
        links.reverse_each do |p, c, d|
          px, py = tile_of(p)
          cx, cy = tile_of(c)
          return [px, py, d] if yield(px, py) && !yield(cx, cy) && Moves.surf_water?(cx, cy)
        end
        nil
      end

      # The [x, y] of a search state (Search.run: the tile's state key times 5 and the way it was arrived from).
      def self.tile_of(s)
        k = s / 5 / 2
        [k / PKEY_STRIDE, k % PKEY_STRIDE]
      end
    end
  end
end

module PokeAccess
  module Routes
    # Every state the player can reach, flooded with no goal from where they stand (Search.run as a Dijkstra): the
    # least cost and way to each tile, answering a search its budget cut (Search.best). Each ask floods on for one more
    # budget; the last SIZE are kept while the player's tile and level, vehicle, events and settings stand.
    class Flood
      NODES = 10000
      SIZE = 4

      @kept = []

      # Drops the floods kept.
      def self.forget; @kept = []; end

      # The flood kept for the player as they stand, priced by cost (a CostModel) with the moves of mode, or nil.
      def self.kept(cost, mode)
        hit = @kept.assoc(key_for(cost, mode))
        hit && hit[1]
      end

      # The flood for the player as they stand (cost, moves of mode), a kept one advanced one more budget or a new one;
      # nil while the probe is unstable (partway up a side stair) or past the operation's deadline.
      def self.for(cost, mode)
        PokeAccess::Pathfinder.searching do |lim|
          next nil if !PokeAccess::World::Probe.stable? || lim.time_spent?
          key = key_for(cost, mode)
          hit = @kept.assoc(key)
          if hit
            hit[1].advance
            next hit[1]
          end
          f = new(cost, mode)
          @kept.push([key, f])
          @kept.shift while @kept.length > SIZE
          f
        end
      end

      # What a flood depends on: the events (as Planner.key_for has them) and those lent through, the player's tile and
      # level, the pricing, the moves and the route limit.
      def self.key_for(cost, mode)
        pf = PokeAccess::Pathfinder
        [pf.event_epoch, PokeAccess::World::Events.gen, PokeAccess::World::Probe.lent_tiles, $game_player.x,
         $game_player.y, pf.bridge_level, cost.style, mode, (PokeAccess::Config.route_limit rescue nil)]
      end

      # Floods from the player's state for a first budget.
      def initialize(cost, mode)
        @cost = cost
        @mode = mode
        @t = Tables.new({}, {}, {}, {}, {}, nil, [])
        @done = false
        advance
      end

      # Floods on from where it stopped for one more budget: NODES in effort mode, else the operation's own limit.
      def advance
        return if @done
        pf = PokeAccess::Pathfinder
        pf.searching do |lim|
          lim = Limits.new(:effort, NODES, 0) if lim.mode == :effort
          @t.limits = lim
          @done = Search.run(nil, @cost, @mode, :dijkstra, nil, nil, @t).status == :exhausted
        end
      end

      # True when the flood closed every state it reached.
      def done?; @done; end

      # The way to goal as a SearchResult: :found to its tile reached at the least cost, :exhausted when the flood
      # closed everything without reaching one, nil while it has not got there yet.
      def route_to(goal)
        s = cheapest(goal.tiles)
        return SearchResult.new(:found, Search.path_to(@t.came, s), 0, :flood, @t.settled[s / 5]) if s
        @done ? SearchResult.new(:exhausted, nil, 0, :flood) : nil
      end

      # The state that reaches one of tiles (on either bridge level) at the least cost, or nil.
      def cheapest(tiles)
        pf = PokeAccess::Pathfinder
        best = nil
        tiles.each do |x, y|
          [0, 1].each do |l|
            k = pf.skey(x, y, l)
            c = @t.settled[k]
            best = [c, @t.first[k]] if c && (best.nil? || c < best[0])
          end
        end
        best && best[1]
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Flood.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Flood.forget }

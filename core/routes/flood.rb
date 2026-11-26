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
      # level, the pricing (with what tiles cost, Moves.costed?, and the rules that count), the moves and the route
      # limit.
      def self.key_for(cost, mode)
        pf = PokeAccess::Pathfinder
        c = PokeAccess::Config
        [pf.event_epoch, PokeAccess::World::Events.gen, PokeAccess::World::Probe.lent_tiles, $game_player.x,
         $game_player.y, pf.bridge_level, cost.style, mode, (c.route_limit rescue nil), (c.avoid_grass rescue nil),
         PokeAccess::Puzzles.assist?]
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
        best = cheapest(goal)
        return SearchResult.new(:found, Search.path_to(@t.came, best[1]), 0, :flood, best[0]) if best
        @done ? SearchResult.new(:exhausted, nil, 0, :flood) : nil
      end

      # [cost, state] of the least that reaches one of goal's tiles on a level its floor allows, with the press through
      # a doorway after it priced (Goal#press), or steps onto its entry's tile and is taken on elsewhere; nil for none.
      def cheapest(goal)
        pf = PokeAccess::Pathfinder
        best = nil
        goal.tiles.each do |x, y|
          d = goal.press(x, y)
          pf::LEVELS.each do |l|
            next unless goal.floor_ok?(l)
            k = pf.skey(x, y, l)
            got = d ? pressed(k, d) : (@t.settled[k] && [@t.settled[k], @t.first[k]])
            best = got if got && (best.nil? || got[0] < best[0])
          end
        end
        es = goal.entry && Search.entry_state(goal.entry)
        c = es && @t.settled[es]
        c && (best.nil? || c < best[0]) ? [c, es] : best
      end

      # [cost, state] of the least closed state of tile key k with the press d after it and its turn; nil for none.
      def pressed(k, d)
        i = Regions::DIR_INDEX[d]
        best = nil
        (0..4).each do |from|
          s = k * 5 + from
          next unless @t.closed[s]
          c = @t.least[s] + @cost.step(1, from != 4 && from != i, nil)
          best = [c, s] if best.nil? || c < best[0]
        end
        best
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Flood.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Flood.forget }

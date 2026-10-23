module PokeAccess
  module Routes
    # A planned way to act on a target. kind: :walk (on foot), :assisted (on foot up to the first step past walking,
    # gate naming it, see route_gates), :surf (on foot to the shore, launch the way to push off), :company (a way by
    # water the game bars with someone along), :none (no way), :cut (the budget ran out first) or :far (beyond reach,
    # unsearched). stats: { :algo (the search that answered on foot), :expanded (its states), :cuts (searches cut
    # short), :unsettled (asking again goes on), :ms (to a tenth) }.
    Plan = Struct.new(:kind, :route, :gate, :stats, :launch)

    # The route policies, in one place: on foot first (a one-sided doorway reached from a tile it is walked into from,
    # no search beyond reach or where the regions rule it out), then assisted, a puzzle's control presses and a surf
    # launch, the assisted and the surf first ruled out by their own regions. The last SIZE plans are kept (key_for).
    module Planner
      # How many plans are kept.
      SIZE = 16

      @plans = []

      # Drops the kept plans.
      def self.forget; @plans = []; end

      # The way to act on (tx,ty), or to stand on it with onto (a spot to dive at), as a Plan of the caller's own.
      def self.plan(tx, ty, onto = false)
        kept([:plan, tx, ty, onto]) { make(tx, ty, onto) }
      end

      # The plan kept for what is asked (what, with the world and settings it was made under, key_for), else the one
      # the block makes, kept; the caller gets its own copy.
      def self.kept(what)
        PokeAccess::World::Epoch.settle(true)
        PokeAccess::World::Events.sync(true)
        key = key_for(what)
        hit = @plans.assoc(key)
        if hit
          @plans.delete(hit)
          @plans.push(hit)
          return copy(hit[1])
        end
        made = yield
        keep(key, made)
        copy(made)
      end

      # The route on foot to act on (tx,ty), or to stand on it with onto, as a SearchResult (see Planner).
      def self.walk(tx, ty, onto = false)
        pf = PokeAccess::Pathfinder
        pf.searching do |limits|
          px = $game_player.x; py = $game_player.y
          goal = goal_for(tx, ty, onto)
          dist = (px - tx).abs + (py - ty).abs
          if goal.hit?(px, py)
            SearchResult.new(:found, Pathfinder::Route.new, 0, nil)
          elsif dist > pf.reach
            limits.cut!
            SearchResult.new(:cut, nil, 0, nil)
          elsif unreachable?(goal)
            SearchResult.new(:exhausted, nil, 0, :regions)
          else
            r = searched_off(goal, !onto && !doorways(tx, ty))
            r.status == :found ? r : unfound(goal, r)
          end
        end
      end

      # The answer for a search on foot that found no way (r): exhausted when the regions tell the goal cannot be got
      # to; when they tell it can and r ran out of ways, searched again through the roaming walkers in the way; else r.
      def self.unfound(goal, r)
        s = reach(goal, true)
        return SearchResult.new(:exhausted, nil, r.expanded, r.algo) if s[0] == :no
        walkers = s[0] == :yes && r.status == :exhausted ? Regions.lendable_walkers : []
        return r if walkers.empty?
        past = PokeAccess::World::Probe.lend_through(walkers) { searched(goal, false) }
        return r unless past.status == :found
        past.expanded += r.expanded
        past
      end

      # What a route to (tx,ty) ends on: the tiles a one-sided doorway is walked into from, the spot itself with onto,
      # else the tiles it is acted on from.
      def self.goal_for(tx, ty, onto)
        doors = onto ? nil : doorways(tx, ty)
        doors ? Goal.new(doors, tx, ty) : (onto ? Goal.onto(tx, ty) : Goal.near(tx, ty))
      end

      # Whether the player can get to goal on foot, the one answer the list hides by and the routes give up by: the
      # regions' status of its tiles (Regions#status), walked on within the question's allowance with walk, else as
      # walked so far (Regions#known); never :no with edge_relax on, whose border steps they do not take.
      def self.reach(goal, walk = true)
        reg = Regions.foot
        s = walk ? reg.status(goal.tiles) : reg.known(goal.tiles)
        s[0] == :no && (PokeAccess::Config.edge_relax rescue false) ? Regions::UNKNOWN : s
      end

      # True when reach tells none of goal's tiles can be got to (walked on with walk).
      def self.unreachable?(goal, walk = false); reach(goal, walk)[0] == :no; end

      # A plan made afresh: on foot, else assisted, else by water, else none or cut. A search on foot stopped short
      # makes no cut once the regions, as walked by then, tell the target cannot be got to on foot; one stopped short
      # with nothing telling is never answered by an assisted route, which would call blocked a way it may have missed.
      def self.make(tx, ty, onto)
        pf = PokeAccess::Pathfinder
        t0 = PokeAccess.clock
        pf.searching do |limits|
          r = walk(tx, ty, onto)
          told = r.status != :found && unreachable?(goal_for(tx, ty, onto)) ? limits.cuts : 0
          made = if r.status == :found then Plan.new(:walk, r.route)
                 elsif beyond?(tx, ty) then Plan.new(:far)
                 elsif r.status != :cut && (g = assisted(tx, ty, onto)) then Plan.new(:assisted, g[0], g[1])
                 elsif (c = through_controls(tx, ty, onto)) then Plan.new(:assisted, c[0], c[1])
                 elsif (s = surf(tx, ty)) then s[0] ? Plan.new(:surf, s[0], nil, nil, s[1]) : Plan.new(:company)
                 else Plan.new(limits.cuts > told ? :cut : :none)
                 end
          made.stats = { :algo => r.algo, :expanded => r.expanded, :cuts => limits.cuts,
                         :unsettled => r.status == :cut && !r.algo.nil?,
                         :ms => ((PokeAccess.clock - t0) * 10000).round / 10.0 }
          made
        end
      end

      # The route to (tx,ty) up to its first assisted step, as [steps, gate]: a search with the obstacles set aside,
      # else Pushes; nil when nothing could assist, the assisted regions rule the goal out, or neither finds a way.
      def self.assisted(tx, ty, onto = false)
        pf = PokeAccess::Pathfinder
        return nil unless pf.assist_possible?
        goal = goal_for(tx, ty, onto)
        relax = (PokeAccess::Config.edge_relax rescue false)
        return nil if !relax && Regions.assisted.status(goal.tiles)[0] == :no
        full = pf.with_gates_open do
          pf.searching { Search.route(goal, pf.moves_mode(true, relax), pf.path_algorithm).route }
        end
        cut = full && pf.cut_at_gate(full)
        cut ? [cut[0], past(cut[1], full, cut[0].length)] : Pushes.route(goal)
      rescue StandardError => e
        PokeAccess.log_once("route_assisted", e)
        nil
      end

      # The gate of route full, at its press n, with the way past it when that way reaches the goal with nothing more
      # to clear or use on it, and no tile of full changes the puzzle (kinds_past): :after, how many presses are left
      # once the gate is passed, and :jumps and :slides, how many of them hop a ledge or slide, only when there are any.
      def self.past(gate, full, n)
        pf = PokeAccess::Pathfinder
        start = [$game_player.x, $game_player.y, pf.bridge_level]
        left = pf.with_gates_open do
          kinds_past(Moves.trace(start[0], start[1], start[2], full, pf.replay_mode), full, n, start)
        end
        return gate if left.nil? || left.empty?
        jumps = left.select { |k| k == :jump }.length
        slides = left.select { |k| k == :slide }.length
        gate[:after] = left.length
        gate[:jumps] = jumps if jumps > 0
        gate[:slides] = slides if slides > 0
        gate
      end

      # What the presses from the gate at press n of route full on do that cannot be undone (Moves.one_way), the gate's
      # own unless an assisted step's move; nil unless pts (full replayed from start [x, y, level]) cover full, no gate
      # or assisted step follows it, and no tile short of the last (the way to the gate too) is in Controls.keep_off.
      def self.kinds_past(pts, full, n, start)
        return nil unless pts.length == full.length && pts[n] && pts[n].gate
        return nil if pts[(n + 1)..-1].any? { |s| s.gate || s.kind == :assist }
        off = Controls.keep_off
        return nil if pts[0...-1].any? { |s| off[Routes.pkey(s.x, s.y)] }
        from = pts[n].kind == :assist ? n + 1 : n
        s = from > 0 ? pts[from - 1] : nil
        Moves.one_way(s ? s.x : start[0], s ? s.y : start[1], s ? s.level : start[2], full[from..-1])
      end

      # With the puzzle assist, the way to the first control whose presses open the way to (tx,ty) (Controls); nil
      # without the assist, or when no presses do.
      def self.through_controls(tx, ty, onto)
        return nil unless PokeAccess::Puzzles.assist?
        Controls.route(goal_for(tx, ty, onto))
      rescue StandardError => e
        PokeAccess.log_once("route_controls", e)
        nil
      end

      # The kept plan to push the boulder ev into the box [x0, y0, x1, y1], a puzzle's zone: :assisted up to its first
      # push or pull, :walk with no steps once inside, :cut past the pushes' limits, else :none.
      def self.carry(ev, box)
        kept([:carry, ev.id, box]) { carried(ev, box) }
      end

      # The carry plan made afresh (see carry).
      def self.carried(ev, box)
        PokeAccess::Pathfinder.searching do |limits|
          key = Routes.pkey(ev.x, ev.y)
          info = Effects.boulder_index[key]
          goal = info ? Pushes::RockGoal.new(key, ev.x, ev.y, box, info) : nil
          if !goal then Plan.new(:none)
          elsif goal.hit?(0, 0, []) then Plan.new(:walk, PokeAccess::Pathfinder::Route.new)
          elsif (g = Pushes.route(goal)) then Plan.new(:assisted, g[0], g[1])
          else Plan.new(limits.cuts > 0 ? :cut : :none)
          end
        end
      end

      # One search toward goal with ledge hops at their cost: HPA* when chosen and the map's moves are plain steps
      # (plain: a goal it can take, acting on a target), the search it falls back to taking what HPA* left of the
      # budget (Limits#less), else the engine with the chosen algorithm (JPS and the regions router among them, see
      # Search.best).
      def self.searched(goal, plain)
        pf = PokeAccess::Pathfinder
        mode = pf.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        algo = pf.path_algorithm
        if plain && algo == :hpa && Moves.uniform? && Moves.speed(mode) == 1
          spent = pf.hpa_states
          r = pf.hpa_search(goal.tx, goal.ty)
          return SearchResult.new(:found, Pathfinder::Route.new(r), 0, algo) if r.is_a?(Array)
          return pf.limits.less(pf.hpa_states - spent) { Search.route(goal, mode, algo) }
        end
        Search.route(goal, mode, algo)
      end

      # One search on foot toward goal that keeps off the tiles where a step would change the map's puzzle
      # (Controls.keep_off) but the goal's own, by an A* that reads each step afresh; with none on the map, or no way
      # without them, the plain search, its route kept only while the plates it crosses leave the rest of it open.
      def self.searched_off(goal, plain)
        off = Controls.keep_off
        return searched(goal, plain) if off.empty?
        goal.tiles.each { |x, y| off.delete(Routes.pkey(x, y)) }
        mode = PokeAccess::Pathfinder.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        kept = Moves.with_closed(off) { Search.fresh(goal, mode) }
        return kept if kept.status == :found
        r = searched(goal, plain)
        return r unless r.status == :found && !Controls.open_past?(r.route)
        SearchResult.new(:exhausted, nil, r.expanded + kept.expanded, r.algo)
      end

      # The tiles a one-sided doorway at (tx,ty) is walked into from, nil for any other target.
      def self.doorways(tx, ty)
        fs = Effects.door_facings(tx, ty)
        fs && fs.map { |f| [tx - PokeAccess::DIR_DELTA[f][0], ty - PokeAccess::DIR_DELTA[f][1]] }
      end

      # True when (tx,ty) lies beyond reach of the player (route_reach), where nothing is searched.
      def self.beyond?(tx, ty)
        ($game_player.x - tx).abs + ($game_player.y - ty).abs > PokeAccess::Pathfinder.reach
      end

      # What a plan depends on besides the tiles: the map, vehicle and events, the player's tile and bridge level, what
      # is asked (the target, or the piece and its zone), the settings the searches read, whether Strength is used and
      # whether the game lets the player surf with whoever walks along (Pathfinder.surf_with_company?).
      def self.key_for(what)
        pf = PokeAccess::Pathfinder
        c = PokeAccess::Config
        [pf.event_epoch, PokeAccess::World::Events.gen, $game_player.x, $game_player.y, pf.bridge_level, what,
         (c.route_style rescue nil), pf.path_algorithm, (c.astar_weight rescue nil), pf.hpa_cluster,
         (c.edge_relax rescue nil), pf.reach, Limits.from_config.key, PokeAccess::Puzzles.assist?,
         Pushes.strength_used?, pf.surf_with_company?]
      end

      # Keeps a plan, the oldest dropped past SIZE. Never a cut whose search on foot was left unsettled, as the next
      # question goes on where the regions and the flood stopped, nor one under a deadline, which the clock decided.
      def self.keep(key, made)
        if made.kind == :cut
          return if made.stats && made.stats[:unsettled]
          return if (PokeAccess::Config.route_limit rescue :effort) == :time
        end
        @plans.push([key, made])
        @plans.shift while @plans.length > SIZE
      end

      # A plan whose route the caller may change.
      def self.copy(made)
        Plan.new(made.kind, made.route && made.route.dup, made.gate, made.stats, made.launch)
      end

      # The route on foot onto the shore to push off from toward (tx,ty), with the way to push off, as [route,
      # direction]; [nil, direction] when someone walks along and the game will not let the player surf so
      # (Pathfinder.surf_with_company?); nil when surfing does not reach it (Pathfinder.surf_plan).
      def self.surf(tx, ty)
        pl = PokeAccess::Pathfinder.surf_plan(tx, ty)
        r = pl && walk(pl[0], pl[1], true).route
        return nil unless r
        PokeAccess::Pathfinder.surf_with_company? ? [r, pl[2]] : [nil, pl[2]]
      rescue StandardError => e
        PokeAccess.log_once("route_surf", e)
        nil
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Planner.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Planner.forget }

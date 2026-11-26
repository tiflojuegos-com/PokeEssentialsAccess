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

      # Drops the kept plans and the ways round the watchers' sight found wanting (searched_off).
      def self.forget
        @plans = []
        @unrounded = {}
      end

      # The way to act on (tx,ty), or to stand on it with onto (a spot to dive at), as a Plan of the caller's own.
      def self.plan(tx, ty, onto = false)
        kept([:plan, tx, ty, onto]) { make(tx, ty, onto) }
      end

      # The way on foot from (fx,fy) at bridge level lvl to act on (tx,ty), or to stand on it with onto, as a Plan
      # (:walk, :none or :cut): one A* from that tile (from_tile), with no regions, floods or HPA*, no surf and no
      # assisted steps, a walk ending with the press through a doorway (through). The free camera's route key asks it.
      # Answered with no search when (fx,fy) is in the player's zone on foot and the target is not, and with no presses
      # on the target's own tile.
      def self.plan_from(fx, fy, lvl, tx, ty, onto = false)
        kept([:from, fx, fy, lvl, tx, ty, onto]) do
          PokeAccess::Pathfinder.searching do
            goal = goal_for(tx, ty, onto)
            made = if goal.hit?(fx, fy, nil, lvl) || (fx == tx && fy == ty)
                     Plan.new(:walk, Pathfinder::Route.new)
                   elsif reach(Goal.onto(fx, fy), false)[0] == :yes && unreachable?(goal)
                     Plan.new(:none)
                   else
                     from_tile(goal, [fx, fy, lvl])
                   end
            made.route = through(made.route, tx, ty, [fx, fy, lvl]) if made.kind == :walk && !onto
            made
          end
        end
      end

      # The A* on foot from origin [x, y, level] toward goal as a Plan, searched again through the roaming walkers in the
      # way when it ran out of ways and the regions tell the goal can be got to, as unfound does for the player.
      def self.from_tile(goal, origin)
        mode = PokeAccess::Pathfinder.replay_mode
        r = Search.fresh(goal, mode, origin)
        walkers = r.status == :exhausted && reach(goal, true)[0] == :yes ? Regions.lendable_walkers : []
        r = PokeAccess::World::Probe.lend_through(walkers) { Search.fresh(goal, mode, origin) } unless walkers.empty?
        r.status == :found ? Plan.new(:walk, r.route) : Plan.new(r.status == :cut ? :cut : :none)
      end

      # The plan kept for what is asked (what, with the world and settings it was made under, key_for), while what is
      # left of Z's Lens of Truth still takes it as far as it needs (World::Lens.lasts?), else the one the block makes,
      # kept; the caller gets its own copy.
      def self.kept(what)
        PokeAccess::World::Epoch.settle(true)
        PokeAccess::World::Events.sync(true)
        key = key_for(what)
        hit = @plans.assoc(key)
        if hit && !PokeAccess::World::Lens.lasts?(hit[2])
          @plans.delete(hit)
          hit = nil
        end
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
          if goal.hit?(px, py, nil, pf.bridge_level)
            SearchResult.new(:found, Pathfinder::Route.new, 0, nil)
          elsif dist > pf.reach
            limits.cut!
            SearchResult.new(:cut, nil, 0, nil)
          elsif unreachable?(goal)
            SearchResult.new(:exhausted, nil, 0, :regions)
          else
            r = searched_off(goal, !onto && !entered_from(tx, ty) && !answering_sides(tx, ty))
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

      # What a route to (tx,ty) ends on: the press into the sight of a watcher there that takes the player on (its line,
      # its tile as the entry), the tiles a doorway is entered from with the press through it from each (door_goal), or
      # a healing spot's, the spot itself with onto, else the tiles it is acted on from.
      def self.goal_for(tx, ty, onto)
        return Goal.onto(tx, ty) if onto
        line = Effects.sight_line(tx, ty)
        return Goal.new(line + [[tx, ty]], tx, ty) if line
        door = door_goal(tx, ty)
        return door if door
        sides = PokeAccess::HealingFloors.entries(tx, ty) || answering_sides(tx, ty)
        goal = sides ? Goal.new(sides, tx, ty) : Goal.near(tx, ty)
        goal.floor = Effects.target_floor(tx, ty)
        goal
      end

      # The tiles an event that answers from some sides alone answers from, unless the player cannot get to any of them: the
      # way to it then ends beside it, wherever that is (nil).
      def self.answering_sides(tx, ty)
        tiles = Effects.act_sides(tx, ty)
        tiles && reach(Goal.new(tiles, tx, ty))[0] == :no ? nil : tiles
      end

      # Whether the player can get to goal on foot, the one answer the list hides by and the routes give up by: the
      # regions' status of its tiles and entry (Regions#status), walked on within the question's allowance with walk,
      # else as walked so far (Regions#known); never :no with edge_relax on, whose border steps they do not take.
      def self.reach(goal, walk = true)
        reg = Regions.foot
        s = walk ? reg.status(goal.tiles, goal.entry) : reg.known(goal.tiles, goal.entry)
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
          made = if r.status == :found then walked(r.route, tx, ty, onto)
                 elsif beyond?(tx, ty) then Plan.new(:far)
                 elsif r.status != :cut && (g = assisted(tx, ty, onto)) then Plan.new(:assisted, g[0], g[1])
                 elsif (c = through_controls(tx, ty, onto)) then Plan.new(:assisted, c[0], c[1])
                 elsif (s = by_water(tx, ty)) then s
                 else Plan.new(limits.cuts > told ? :cut : :none)
                 end
          made.stats = { :algo => r.algo, :expanded => r.expanded, :cuts => limits.cuts,
                         :unsettled => r.status == :cut && !r.algo.nil?,
                         :ms => ((PokeAccess.clock - t0) * 10000).round / 10.0 }
          made
        end
      end

      # The plan of a route walked to (tx,ty), or onto it with onto: assisted when it leads to a thing only the Lens of
      # Truth shows (World::Lens.show_cut) or crosses what the lens opens once it is down again (World::Lens.renew_cut);
      # else the walk, ending with the press through a doorway (through).
      def self.walked(route, tx, ty, onto)
        lens = PokeAccess::World::Lens
        s = lens.show_cut(route, tx, ty) || lens.renew_cut(route)
        return Plan.new(:assisted, s[0], s[1]) if s
        Plan.new(:walk, onto ? route : through(route, tx, ty))
      end

      # The route to (tx,ty) up to its first assisted step, as [steps, gate]: a search with the obstacles set aside,
      # else Pushes; nil when nothing could assist, the assisted regions rule the goal out, or neither finds a way.
      def self.assisted(tx, ty, onto = false)
        pf = PokeAccess::Pathfinder
        return nil unless pf.assist_possible?
        goal = pf.with_gates_open { goal_for(tx, ty, onto) }
        relax = (PokeAccess::Config.edge_relax rescue false)
        return nil if !relax && Regions.assisted.status(goal.tiles, goal.entry)[0] == :no
        full = pf.with_gates_open do
          pf.searching { Search.route(goal, pf.moves_mode(true, relax), pf.path_algorithm).route }
        end
        cut = full && pf.cut_at_gate(full)
        cut ? [cut[0], past(cut[1], full, cut[0].length, onto ? nil : [tx, ty])] : Pushes.route(goal)
      rescue StandardError => e
        PokeAccess.log_once("route_assisted", e)
        nil
      end

      # The gate of route full, at its press n, with the way past it when that way reaches the goal with nothing more to
      # clear or use and no tile of full changes the puzzle (kinds_past): :after, how many presses are left once the
      # gate is passed, the press through the doorway at door [x, y] among them where full ends on a tile it goes from
      # (door_press), and :jumps and :slides, how many hop a ledge or slide, only when there are any.
      def self.past(gate, full, n, door = nil)
        pf = PokeAccess::Pathfinder
        start = [$game_player.x, $game_player.y, pf.bridge_level]
        left = pf.with_gates_open do
          pts = Moves.trace(start[0], start[1], start[2], full, pf.replay_mode)
          kinds = kinds_past(pts, full, n, start)
          e = pts[-1]
          kinds && e && door && door_press(door[0], door[1], e.x, e.y, e.level) ? kinds.push(nil) : kinds
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
        Moves.one_way(s ? s.x : start[0], s ? s.y : start[1], s ? s.level : start[2], full[from..-1],
                      Moves.picks_of(full, from))
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

      # The kept plan to push the boulder ev into the box [x0, y0, x1, y1], a puzzle's zone, with, as event id => box,
      # the events its pushes move along (Effects.push_twins) in theirs: :assisted up to its first push or pull, :walk
      # with no steps once all are inside, :cut past the pushes' limits, else :none.
      def self.carry(ev, box, with = nil)
        kept([:carry, ev.id, box, with]) { carried(ev, box, with) }
      end

      # The carry plan made afresh (see carry).
      def self.carried(ev, box, with = nil)
        PokeAccess::Pathfinder.searching do |limits|
          key = Routes.pkey(ev.x, ev.y)
          info = Effects.boulder_index[key]
          others = (with || {}).map do |id, b|
            tw = ($game_map.events[id] rescue nil)
            tw ? [Routes.pkey(tw.x, tw.y), b, tw.x, tw.y] : nil
          end
          goal = info ? Pushes::RockGoal.new(key, ev.x, ev.y, box, info, others.compact) : nil
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

      # One search on foot toward goal (searched_plates); when its way steps on a tile watchers see (Sight.seen) but the
      # goal's own, one that keeps off those tiles and the plates, under a budget of its own (aside), taken when it finds
      # a way. One looked for in vain is not looked for again while what it depends on holds (round_key); one cut by its
      # budget is, since the next may find it.
      def self.searched_off(goal, plain)
        r = searched_plates(goal, plain)
        seen = Sight.seen
        return r if seen.empty? || r.status != :found || !crosses?(r.route, seen, goal)
        @unrounded ||= {}
        key = round_key(goal)
        return r if @unrounded[key] && @unrounded[key].equal?(Regions.foot)
        mode = PokeAccess::Pathfinder.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        unseen = aside { closed_search(goal, mode, Controls.keep_off.merge!(seen), !PokeAccess::Engine.gamedata?) }
        return unseen if unseen.status == :found
        return r if unseen.status == :cut
        @unrounded = {} if @unrounded.length >= SIZE
        @unrounded[key] = Regions.foot
        r
      end

      # What a way round the watchers' sight toward goal depends on besides the regions on foot, kept with it: the map,
      # what the watchers see (Sight.stamp) and the goal's tiles. The player's tile is not in it, as the route is asked
      # again at each step: from anywhere under the same regions and sight, a way round is taken to be as wanting.
      def self.round_key(goal)
        [($game_map.map_id rescue nil), Sight.stamp, goal.tiles]
      end

      # True when route, walked from the player as the guide replays it, steps on a tile of seen but the goal's own:
      # where each press ends, and before the GameData era the tiles a slide passes, as that engine checks trainers on
      # each tile of an ice slide (from GameData on, once it stops). A carry runs under the interpreter, which checks no
      # trainer, so the tiles it passes do not count.
      def self.crosses?(route, seen, goal)
        pf = PokeAccess::Pathfinder
        own = {}
        goal.tiles.each { |x, y| own[Routes.pkey(x, y)] = true }
        mid = !PokeAccess::Engine.gamedata?
        px = $game_player.x
        py = $game_player.y
        Moves.trace(px, py, pf.bridge_level, route.to_a, pf.replay_mode, Moves.picks_of(route)).each do |s|
          tiles = mid && s.kind == :slide ? passed(px, py, s.x, s.y) : [[s.x, s.y]]
          return true if tiles.any? { |x, y| seen[Routes.pkey(x, y)] && !own[Routes.pkey(x, y)] }
          px = s.x
          py = s.y
        end
        false
      end

      # The tiles a straight run from (x0,y0) to (x1,y1) passes, its end among them; the end alone off a row or column.
      def self.passed(x0, y0, x1, y1)
        return [[x1, y1]] unless x0 == x1 || y0 == y1
        dx = x1 <=> x0
        dy = y1 <=> y0
        (1..((x1 - x0).abs + (y1 - y0).abs)).map { |i| [x0 + dx * i, y0 + dy * i] }
      end

      # Runs the block under a budget of its own (Limits.from_config), the operation's put back after: what it stops
      # short is no cut of the operation's, and the operation's deadline moves on by the time it took (Limits#postpone).
      def self.aside
        PokeAccess::Pathfinder.in_context do |c|
          outer = c.limits
          c.limits = Limits.from_config
          t0 = PokeAccess.clock
          begin
            yield
          ensure
            c.limits = outer
            outer.postpone(PokeAccess.clock - t0) if outer
          end
        end
      end

      # One search on foot toward goal that keeps off the tiles where a step would change the map's puzzle
      # (Controls.keep_off) but the goal's own, by an A* that reads each step afresh; with none on the map, or no way
      # without them, the plain search, its route kept only while the plates it crosses leave the rest of it open.
      def self.searched_plates(goal, plain)
        off = Controls.keep_off
        return searched(goal, plain) if off.empty?
        mode = PokeAccess::Pathfinder.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        kept = closed_search(goal, mode, off)
        return kept if kept.status == :found
        r = searched(goal, plain)
        return r unless r.status == :found && !Controls.open_past?(r.route)
        SearchResult.new(:exhausted, nil, r.expanded + kept.expanded, r.algo)
      end

      # A search on foot toward goal by an A* that reads each step afresh and lands on no tile of off (pkey => true) but
      # the goal's own, which it takes out of off; with passing, no slide passes one either (crosses?).
      def self.closed_search(goal, mode, off, passing = false)
        goal.tiles.each { |x, y| off.delete(Routes.pkey(x, y)) }
        Moves.with_closed(off, passing) { Search.fresh(goal, mode) }
      end

      # The tiles a target at (tx,ty) works entered from alone: a doorway's (doorways) or a healing spot's
      # (HealingFloors.entries); nil for any other.
      def self.entered_from(tx, ty)
        doorways(tx, ty) || PokeAccess::HealingFloors.entries(tx, ty)
      end

      # The tiles a route to a doorway at (tx,ty) ends on (door_goal), nil for any other target.
      def self.doorways(tx, ty)
        goal = door_goal(tx, ty)
        goal && goal.tiles
      end

      # The Goal of a doorway at (tx,ty): the tiles a press from goes through it, each with that press (door_presses);
      # for one bumped into, those across a counter too, each with the action button's facing; for one walked onto that
      # takes the player on within the map, its own, stood on or entered by any move onto it (Goal#entry). With none, a
      # one-sided doorway's tiles its facings are walked into from. nil for a target that is no doorway.
      def self.door_goal(tx, ty)
        presses = door_presses(tx, ty, PokeAccess::Pathfinder.bridge_level)
        return nil unless presses
        if presses.empty?
          fs = Effects.door_facings(tx, ty)
          return fs && Goal.new(fs.map { |f| [tx - PokeAccess::DIR_DELTA[f][0], ty - PokeAccess::DIR_DELTA[f][1]] }, tx, ty)
        end
        t = Effects.touch_index[Routes.pkey(tx, ty)]
        presses += across_counters(tx, ty) if t && !t[0]
        by_tile = {}
        presses.each { |x, y, d| by_tile[Routes.pkey(x, y)] = d }
        tiles = presses.map { |x, y, _d| [x, y] }
        tiles.push([tx, ty]) if t && t[0] && t[1].values.any? { |e| e[0] == :warp }
        Goal.new(tiles, tx, ty, by_tile)
      end

      # The tiles across a counter from the event at (tx,ty), as Pathfinder.reach_tiles has them, neither on its area
      # nor beside it, each [x, y, the facing toward the event].
      def self.across_counters(tx, ty)
        area = PokeAccess::Pathfinder.area_at(tx, ty)
        out = []
        area.each do |ax, ay|
          DIRS.each do |dx, dy, d|
            x = ax - 2 * dx
            y = ay - 2 * dy
            next unless ($game_map.counter?(ax - dx, ay - dy) rescue false)
            out.push([x, y, d]) if area.all? { |bx, by| (x - bx).abs + (y - by).abs > 1 }
          end
        end
        out
      end

      # The presses that go through the doorway at (tx,ty) from the tiles beside its event (door_area), each [x, y,
      # direction] in the order of DIRS, at bridge level lvl (transfer_press?); nil for a target that is no doorway.
      def self.door_presses(tx, ty, lvl)
        area = door_area(tx, ty)
        return nil unless area
        inside = {}
        area.each { |x, y| inside[Routes.pkey(x, y)] = true }
        out = []
        PokeAccess::Pathfinder.searching do
          area.each do |ax, ay|
            DIRS.each do |dx, dy, d|
              x = ax - dx
              y = ay - dy
              out.push([x, y, d]) if !inside[Routes.pkey(x, y)] && transfer_press?(x, y, lvl, d)
            end
          end
        end
        out
      end

      # The tiles of the event at (tx,ty) (Pathfinder.area_at) when touching one of them takes the player elsewhere for
      # some facing, on or off the map; else nil.
      def self.door_area(tx, ty)
        area = PokeAccess::Pathfinder.area_at(tx, ty)
        doors = area.any? do |x, y|
          t = Effects.touch_index[Routes.pkey(x, y)]
          t && t[1].values.any? { |e| e[0] == :exit || e[0] == :warp }
        end
        doors ? area : nil
      end

      # The direction of the press from (x,y) at bridge level lvl that goes through the doorway at (tx,ty), or nil.
      def self.door_press(tx, ty, x, y, lvl)
        press = (door_presses(tx, ty, lvl) || []).find { |px, py, _d| px == x && py == y }
        press && press[2]
      end

      # route with the press through the doorway at (tx,ty) added where, walked from origin [x, y, bridge level] (the
      # player's state when nil), it ends on a tile that press goes from (door_press), lending the walkers in the way
      # where only so it gets there (as unfound finds it); else route as it is.
      def self.through(route, tx, ty, origin = nil)
        return route unless door_area(tx, ty)
        at = route_end(route, origin)
        walkers = at ? [] : Regions.lendable_walkers
        at = PokeAccess::World::Probe.lend_through(walkers) { route_end(route, origin) } unless walkers.empty?
        d = at && door_press(tx, ty, at[0], at[1], at[2])
        d ? route.dup.push(d) : route
      end

      # The state [x, y, bridge level] route leaves the player in, walked from origin (the player's state when nil) as
      # the guide replays it (Moves.trace); nil where it stops short.
      def self.route_end(route, origin)
        pf = PokeAccess::Pathfinder
        at = origin || [$game_player.x, $game_player.y, pf.bridge_level]
        return at if route.empty?
        pts = Moves.trace(at[0], at[1], at[2], route, pf.replay_mode)
        pts.length == route.length ? [pts[-1].x, pts[-1].y, pts[-1].level] : nil
      end

      # True when a press from (x,y) at bridge level lvl toward d goes through the doorway in front, as Moves.step plays
      # it: the press stops on that tile and its event answers arriving facing d with a transfer, or bumps into it and
      # the event answers a bump so (pressed_onto).
      def self.transfer_press?(x, y, lvl, d)
        dir = DIR_OF[d]
        return false if dir.nil? || PokeAccess::World::Terrain.outside?(x + dir[0], y + dir[1])
        pf = PokeAccess::Pathfinder
        pf.searching do
          pf.use_level(lvl)
          on = pressed_onto(x, y, dir)
          e = on.nil? ? nil : Effects.touch_at(x + dir[0], y + dir[1], d, on)
          !e.nil? && (e[0] == :exit || e[0] == :warp)
        end
      end

      # How a press from (x,y) toward dir meets the tile in front as Moves.step takes it: true when it stops there,
      # false when it bumps into it, nil when it goes elsewhere (a run armed, a registered move, a ledge hopped, ice
      # slid on).
      def self.pressed_onto(x, y, dir)
        d = dir[2]
        fx = x + dir[0]
        fy = y + dir[1]
        return nil if Moves.run_from(x, y, d)
        nbr = Moves.departure(x, y, dir)
        if nbr.nil?
          t = PokeAccess::World::Terrain
          return nil if t.ledge?(fx, fy) || t.ice?(fx, fy)
          return edge_step?(fx, fy) unless PokeAccess::World::Probe.step?(x, y, d)
          nbr = Moves.arrive(fx, fy, d)
        end
        return false unless nbr
        nbr[0] == fx && nbr[1] == fy ? true : nil
      end

      # True when the engine's closed step onto (x,y) is taken all the same: a passable border tile with edge_relax on.
      def self.edge_step?(x, y)
        relax = (PokeAccess::Pathfinder.replay_mode & Moves::RELAX) != 0
        relax && Moves.border_tile?(x, y) && ($game_map.passable?(x, y, 0) rescue false) ? true : false
      end

      # True when (tx,ty) lies beyond reach of the player (route_reach), where nothing is searched.
      def self.beyond?(tx, ty)
        ($game_player.x - tx).abs + ($game_player.y - ty).abs > PokeAccess::Pathfinder.reach
      end

      # What a plan depends on besides the tiles: the map, vehicle and events, the player's tile and bridge level, what
      # is asked (the target, or the piece and its zone), the settings the searches read (the puzzle assist among them,
      # which says the rules that count), whether Strength is used and whether the game lets the player surf with
      # whoever walks along (Pathfinder.surf_with_company?), and what the watchers see (Sight.stamp).
      def self.key_for(what)
        pf = PokeAccess::Pathfinder
        c = PokeAccess::Config
        [pf.event_epoch, PokeAccess::World::Events.gen, $game_player.x, $game_player.y, pf.bridge_level, what,
         (c.route_style rescue nil), (c.avoid_grass rescue nil), pf.path_algorithm, (c.astar_weight rescue nil), pf.hpa_cluster,
         (c.edge_relax rescue nil), pf.reach, Limits.from_config.key, PokeAccess::Puzzles.assist?,
         Pushes.strength_used?, pf.surf_with_company?, Sight.stamp]
      end

      # Keeps a plan, the oldest dropped past SIZE. Never a cut whose search on foot was left unsettled, as the next
      # question goes on where the regions and the flood stopped, nor one under a time limit, which the clock decided,
      # nor a trail's whose way round ran out of budget (:cut_short).
      # What Limits#wider's clock cut is kept: asking again from that tile would hold the game as long for the same answer.
      def self.keep(key, made)
        return if made.stats && made.stats[:cut_short]
        if made.kind == :cut
          return if made.stats && made.stats[:unsettled]
          return if (PokeAccess::Config.route_limit rescue :effort) == :time
        end
        @plans.push([key, made, PokeAccess::World::Lens.frames_needed(made.route)])
        @plans.shift while @plans.length > SIZE
      end

      # A plan whose route the caller may change.
      def self.copy(made)
        Plan.new(made.kind, made.route && made.route.dup, made.gate, made.stats, made.launch)
      end

      # Follow the proven water route up to the first action the player must take. Climb a waterfall before
      # trying to direct the player to a shore only reachable beyond it.
      def self.by_water(tx, ty, include_field = true)
        pf = PokeAccess::Pathfinder
        action = pf.surf_plan(tx, ty, include_field)
        return nil unless action
        x, y, d, field = action
        route = walk(x, y, true).route
        return nil unless route
        if field == :waterfall
          step = Moves.waterfall_step(x, y, DIR_OF[d], pf.bridge_level)
          return step && Plan.new(:assisted, route, step.gate)
        end
        pf.surf_with_company? ? Plan.new(:surf, route, nil, nil, d) : Plan.new(:company, nil, nil, nil, d)
      rescue StandardError => e
        PokeAccess.log_once("route_surf", e)
        nil
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Planner.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Planner.forget }

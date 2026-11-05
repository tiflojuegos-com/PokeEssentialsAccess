module PokeAccess
  module Routes
    # Routes that move boulders out of the way, cut at their first push, pull or other assisted step: a search over
    # where the player stands and where each moved boulder was left, a state packed into one Integer. Boulders move as
    # the game would move them: a push of one tile (on over ice where they slide), a pull, or a long push that sends
    # them off, the last the boulder makes if it sets anything that stays (Effects.push_facet).
    module Pushes
      # How many boulders a route may move with the puzzle assist on, and how many states it may look at.
      LIMIT = 12
      NODES = 8000
      # By effort, how many times a search's tiles (astar_max) it may look at, and for how many seconds: the states of a slow
      # game's Ruby would hold the game for seconds.
      WIDER = 4
      SECONDS = 0.5
      # How many states a search stays exact for, the cheapest plan first, and what the estimate weighs past them against
      # the presses already made: a hard room's route comes in far fewer states, a little longer at times.
      EXACT = 500
      WEIGHT = 3
      # The bits a moved boulder takes in a packed state: its starting tile's key over the key of where it is now, with
      # whether it is spent.
      BITS = 32
      # Where a state has a boulder a long push left stopping nobody: off any map, its key within BITS.
      GONE = [9999, 9999]

      # A goal for the player estimated by the presses left walking (Regions#presses_back), and as goal has it on a state
      # the walk does not tell.
      class WalkedGoal
        def initialize(goal, left)
          @goal = goal
          @left = left
        end

        def hit?(x, y, moved = nil); @goal.hit?(x, y, moved); end

        def bound(x, y, moved = nil, lvl = nil)
          @left[PokeAccess::Pathfinder.skey(x, y, lvl)] || @goal.bound(x, y, moved)
        end
      end

      # A goal for a boulder rather than the player: the one starting on (x, y) (rock that tile's key, info its
      # boulder_index entry) inside the box [x0, y0, x1, y1], estimated off a field walked back from the box, and off it
      # by the Manhattan distance where it was cut (else FAR, no way).
      class RockGoal
        FIELD_CAP = 4000

        def initialize(rock, x, y, box, info = nil)
          @rock = rock
          @x = x
          @y = y
          @box = box
          @info = info
        end

        # True when the boulder, where the moved boulders have it, is inside the box.
        def hit?(_cx, _cy, moved = [])
          bx, by = where(moved)
          manhattan(bx, by) == 0
        end

        # The fewest presses the boulder's pushes and pulls into the box may take from where the moved boulders have it;
        # FAR for a boulder spent out of the box or where the field, walked whole, has no way; one push's price where a
        # push may take it any number of tiles past what the field tells (field).
        def bound(_cx, _cy, moved = [], _lvl = nil)
          bx, by = where(moved)
          m = manhattan(bx, by)
          return 0 if m == 0 || @info.nil?
          return FAR if spent?(moved)
          n = field[Routes.pkey(bx, by)]
          price = 1 + PokeAccess::Pathfinder::GATE_COST
          return price if @far_pushes
          return n * price if n
          @field_cut ? m * price : FAR
        end

        # The tile's Manhattan distance to the box.
        def manhattan(bx, by)
          x0, y0, x1, y1 = @box
          (bx < x0 ? x0 - bx : (bx > x1 ? bx - x1 : 0)) + (by < y0 ? y0 - by : (by > y1 ? by - y1 : 0))
        end

        # The pushes and pulls into the box from each tile, key => count, walked back from the box as the game moves the
        # boulder (pushed_off?, pulled_off?). Meeting ice where boulders slide, or a cut with slides or long pushes to count,
        # sets @far_pushes and bound counts one push.
        def field
          return @field if @field
          terrain = PokeAccess::World::Terrain
          limits = PokeAccess::Pathfinder.limits
          long = @info[6] || {}
          x0, y0, x1, y1 = @box
          dist = {}
          queue = []
          iced = false
          (x0..x1).each { |x| (y0..y1).each { |y| dist[Routes.pkey(x, y)] = 0; queue.push([x, y]) } }
          until queue.empty?
            if dist.size > FIELD_CAP || limits.time_spent?
              @field_cut = true
              break
            end
            tx, ty = queue.shift
            here = dist[Routes.pkey(tx, ty)]
            iced ||= terrain.ice?(tx, ty)
            DIRS.each do |dir|
              sent = long[dir[2]]
              ax = tx - (sent ? sent[0] : dir[0]); ay = ty - (sent ? sent[1] : dir[1])
              iced ||= terrain.ice?(ax, ay)
              k = Routes.pkey(ax, ay)
              next if dist.key?(k) || !(pushed_off?(ax, ay, dir, sent, here) || pulled_off?(ax, ay, dir, sent))
              dist[k] = here + 1
              queue.push([ax, ay])
            end
          end
          @far_pushes = (Pushes.sliding? && (iced || @field_cut)) || (@field_cut && !long.empty?) ? true : false
          @field = dist
        end

        # True when a push along dir takes the boulder off (ax, ay), here pushes from the box where it lands: from behind it,
        # a way its page has, one tile as the game lets it or all a long push sends it, into the box if that is the last the
        # boulder makes (Pushes.movable?), never if it leaves the boulder gone.
        def pushed_off?(ax, ay, dir, sent, here)
          ways = @info[4]
          return false if ways && !ways.include?(dir[2])
          return false if sent && (sent[2] || (!sent[3] && here > 0))
          probe = PokeAccess::World::Probe
          return false unless probe.landing(ax - dir[0], ay - dir[1])
          sent ? true : probe.event_movable?(@info[0], ax, ay, dir[2], [ax, ay, ax - dir[0], ay - dir[1]])
        end

        # True when the player can pull the boulder a tile off (ax, ay) along dir, stepping back as Pushes.pull asks it.
        def pulled_off?(ax, ay, dir, sent)
          return false if sent || !@info[3]
          probe = PokeAccess::World::Probe
          tx = ax + dir[0]; ty = ay + dir[1]
          probe.step?(tx, ty, dir[2]) && probe.event_movable?(@info[0], ax, ay, dir[2], [ax, ay, tx + dir[0], ty + dir[1]])
        end

        # True when the moved boulders have this one spent (Pushes.movable?).
        def spent?(moved)
          (moved || []).any? { |e| e[0] == @rock && e[3] }
        end

        # The boulder's tile: where the search moved it, else where it starts.
        def where(moved)
          m = (moved || []).find { |e| e[0] == @rock }
          m ? [m[1], m[2]] : [@x, @y]
        end
      end

      # The way to goal through pushes and pulls, up to the first of them or of another assisted step, as [steps,
      # gate]; nil when there is none within the limits. A player's goal takes what the assisted regions tell, as far as
      # they do: its estimate, and no search at all when no boulder can open the way.
      def self.route(goal)
        rocks = Effects.boulder_index
        return nil if rocks.empty?
        walk = goal.is_a?(Goal) && !(PokeAccess::Config.edge_relax rescue false) ? Regions.assisted : nil
        left = walk && walk.presses_back(goal.tiles, {}, 0)
        pf = PokeAccess::Pathfinder
        pf.with_gates_open do
          PokeAccess::World::Probe.lend_through(rocks.values.map { |r| r[0] }) do
            pf.searching do |limits|
              next nil if left && sealed?(walk, goal, rocks)
              limits.wider(WIDER, SECONDS) { searched(goal, rocks, walk, left) }
            end
          end
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The search for goal: a boulder's stays an A* throughout, as its estimate leaves little to hurry past; a player's
      # goes on from the presses left walking to those with the boulders on the way at a push's price.
      def self.searched(goal, rocks, walk, left)
        return search(goal, rocks) unless goal.is_a?(Goal)
        return search(goal, rocks) { goal } unless left
        search(WalkedGoal.new(goal, left), rocks) do
          WalkedGoal.new(goal, walk.presses_back(goal.tiles, rocks, 1 + PokeAccess::Pathfinder::GATE_COST) || left)
        end
      end

      # True when the walk tells no route can get to goal: with every boulder that can move gone, or where a route may move
      # only one, with each of them gone in turn, the player still does not get there. It tells nothing where a boulder
      # may stop a slide (sure_no?) or can be pulled, which lands the player where the walk need not.
      def self.sealed?(walk, goal, rocks)
        return false unless walk.sure_no? && rocks.values.none? { |r| r[3] }
        can = lambda { |rock, x, y, dir| pushes?(x, y, dir, rock, [], { rock => rocks[rock] }) }
        moving = walk.past_boulders(goal.tiles, rocks, {}, limit > 1, &can)
        return false unless moving
        limit > 1 || moving.keys.all? { |rock| walk.past_boulders(goal.tiles, rocks, { rock => true }, false) }
      end

      # How many boulders a route may move: with the puzzle assist on, which plans a puzzle room for the player, up to
      # LIMIT; without it only the one that cuts the path, moved as often as it takes.
      def self.limit
        PokeAccess::Puzzles.assist? ? LIMIT : 1
      end

      # A best-first search over the packed states, priced in presses (a push, pull or other assisted step GATE_COST
      # more), estimated by goal.bound (a state at FAR left out): an A*, or with a block one for EXACT states that goes on
      # by the goal the block gives at WEIGHT times its estimate. The player moves as a route on foot replays.
      def self.search(goal, rocks)
        pf = PokeAccess::Pathfinder
        px = $game_player.x; py = $game_player.y
        mode = pf.replay_mode
        limits = pf.limits
        start = [px, py, [], pf.bridge_level]
        sk = pack(start)
        states = { sk => start }
        g = { sk => 0 }
        came = {}
        closed = {}
        heap = []
        iter = 0
        pf.heap_push(heap, [goal.bound(px, py, [], start[3]), 0, sk])
        weight = 1
        until heap.empty?
          iter += 1
          return limits.cut! if iter > NODES
          return nil if limits.spent?(iter)
          if iter == EXACT && block_given?
            goal = yield
            weight = WEIGHT
            heap = reweighed(heap, goal, states, g)
          end
          k = pf.heap_pop(heap)[2]
          next if closed[k]
          closed[k] = true
          cx, cy, moved, lvl = states[k]
          return cut(came, k) if goal.hit?(cx, cy, moved)
          pf.use_level(lvl)
          DIRS.each do |dir|
            moves_from(cx, cy, dir, moved, rocks, lvl, mode).each do |nst, step, cost|
              nk = pack(nst)
              next if closed[nk]
              ng = g[k] + cost
              next unless g[nk].nil? || ng < g[nk]
              est = goal.bound(nst[0], nst[1], nst[2], nst[3])
              next if est >= FAR
              g[nk] = ng
              states[nk] = nst
              came[nk] = [k, step]
              pf.heap_push(heap, [ng + est * weight, 0, nk])
            end
          end
        end
        nil
      end

      # The frontier ordered afresh by goal's estimate at WEIGHT; sorted, it is a heap.
      def self.reweighed(heap, goal, states, g)
        fresh = heap.map do |e|
          st = states[e[2]]
          [g[e[2]] + goal.bound(st[0], st[1], st[2], st[3]) * WEIGHT, 0, e[2]]
        end
        fresh.sort_by { |e| e[0] }
      end

      # The moves from (cx,cy) at bridge level lvl toward dir with the boulders where moved has them, each as [state,
      # [direction, presses, gate, transfer], cost]: a push or a pull of the boulder in front, else a move of
      # Moves.step, whose slides and hops stop at the boulders where the state has them though they are lent through.
      def self.moves_from(cx, cy, dir, moved, rocks, lvl, mode)
        rock = rock_at(cx + dir[0], cy + dir[1], moved, rocks)
        return [push(cx, cy, dir, rock, moved, rocks, lvl), pull(cx, cy, dir, rock, moved, rocks, lvl)].compact if rock
        t = Moves.with_rocks(lambda { |x, y| rock_at(x, y, moved, rocks) }) { Moves.step(cx, cy, lvl, dir, mode) }
        return [] if t.nil? || rock_at(t.x, t.y, moved, rocks)
        [[[t.x, t.y, moved, t.level], [dir[2], t.presses, t.gate, t.warp],
          t.presses + (t.gate ? PokeAccess::Pathfinder::GATE_COST : 0)]]
      end

      # Pushing the boulder rock in front of (cx,cy) along dir, to where that leaves it: the move, or nil where the game
      # would not move it or the route may move no more boulders.
      def self.push(cx, cy, dir, rock, moved, rocks, lvl)
        return nil unless pushes?(cx, cy, dir, rock, moved, rocks)
        info = rocks[rock]
        nx = cx + dir[0]; ny = cy + dir[1]
        gate = { :kind => :field, :label => label(info), :ev => info[0], :move => move_for(info), :x => nx, :y => ny }
        gate[:act] = true if info[2] == :act
        bx, by = pushed_to(info, nx, ny, dir, moved, rocks, cx, cy)
        long = long_push(info, dir)
        [[cx, cy, moved_to(moved, rock, bx, by, long && !long[3]), lvl], [dir[2], 1, gate], 1 + PokeAccess::Pathfinder::GATE_COST]
      end

      # Where a push along dir from (cx,cy) leaves boulder info, standing on (nx,ny): where its long push sends it (GONE
      # when that leaves it stopping nobody), else one tile on, to where it comes to rest (rest).
      def self.pushed_to(info, nx, ny, dir, moved, rocks, cx, cy)
        long = long_push(info, dir)
        return rest(info[0], nx + dir[0], ny + dir[1], dir, moved, rocks, cx, cy) unless long
        long[2] ? GONE : [nx + long[0], ny + long[1]]
      end

      # Boulder info's long push along dir (Effects.long_pushes), or nil.
      def self.long_push(info, dir)
        info[6] && info[6][dir[2]]
      end

      # Declares the game slides a boulder pushed onto ice on as it slides the player (Reborn's engine, whose
      # onStepTakenFieldMovement runs pbSlideOnIce for any character).
      def self.sliding_rocks!; @sliding = true; end

      # True when the game slides pushed boulders on ice (sliding_rocks!).
      def self.sliding?; @sliding ? true : false; end

      # Where boulder ev, pushed onto (x,y) along dir with the player on (cx,cy), comes to rest: there, or in a game
      # whose pushed boulders slide, on along dir while its tile is ice and the game lets it move on (its passable?,
      # as the push asks it), short of a boulder where the state has one.
      def self.rest(ev, x, y, dir, moved, rocks, cx, cy)
        return [x, y] unless @sliding
        probe = PokeAccess::World::Probe
        guard = 0
        while PokeAccess::World::Terrain.ice?(x, y) && guard < Moves::ARRIVAL_CAP
          guard += 1
          ax = x + dir[0]; ay = y + dir[1]
          break if rock_at(ax, ay, moved, rocks) || !probe.event_movable?(ev, x, y, dir[2], [x, y, cx, cy])
          x = ax; y = ay
        end
        [x, y]
      end

      # True when the boulder rock in front of (cx,cy) would move along dir: one the route may move, pushed that way (one
      # that moves itself only takes the ways its page has), with no boulder beyond, that the game lets move there; a
      # long push goes through all that, onto a tile of the map.
      def self.pushes?(cx, cy, dir, rock, moved, rocks)
        nx = cx + dir[0]; ny = cy + dir[1]
        return false unless movable?(rock, moved) && ready?(rocks[rock], nx + dir[0], ny + dir[1])
        ways = rocks[rock][4]
        return false if ways && !ways.include?(dir[2])
        long = long_push(rocks[rock], dir)
        return ($game_map.valid?(nx + long[0], ny + long[1]) rescue true) if long
        return false if rock_at(nx + dir[0], ny + dir[1], moved, rocks)
        PokeAccess::World::Probe.event_movable?(rocks[rock][0], nx, ny, dir[2], [nx, ny, cx, cy])
      end

      # Pulling the boulder rock in front of (cx,cy) along dir: the player steps back and it takes their tile, as the
      # game checks it; nil for one that cannot be pulled, or where turning toward it with the way held would push it.
      def self.pull(cx, cy, dir, rock, moved, rocks, lvl)
        info = rocks[rock]
        return nil unless info[3] && movable?(rock, moved) && ready?(info, cx, cy)
        back = 10 - dir[2]
        rx = cx + dir[0]; ry = cy + dir[1]
        bx = cx - dir[0]; by = cy - dir[1]
        return nil if rock_at(bx, by, moved, rocks)
        probe = PokeAccess::World::Probe
        return nil unless probe.event_movable?(info[0], cx, cy, back, [rx, ry, cx, cy]) && probe.step?(cx, cy, back)
        return nil unless probe.event_movable?(info[0], rx, ry, back, [rx, ry, bx, by])
        return nil if info[2] == :walk && pushes?(cx, cy, dir, rock, moved, rocks)
        gate = { :kind => :pull, :label => label(info), :ev => info[0], :face => dir[2], :x => rx, :y => ry }
        [[bx, by, moved_to(moved, rock, cx, cy), lvl], [dir[2], 1, gate], 1 + PokeAccess::Pathfinder::GATE_COST]
      end

      # True when the game moves boulder info onto (x,y) now: one with no condition of its own, or one whose condition
      # holds for that tile (Effects.push_script).
      def self.ready?(info, x, y)
        info[5].nil? || (info[5].call(x, y) ? true : false)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # True when the route may move boulder rock: one it moved already and has not spent, or one more within the limit. A
      # long push that sets anything spends it: what the page it opens does is for the plan made after that push to read.
      def self.movable?(rock, moved)
        m = moved.find { |e| e[0] == rock }
        m ? !m[3] : moved.length < limit
      end

      # The locator's name for a boulder: the Strength boulder, or a pushable object.
      def self.label(info)
        info[1] ? :loc_strength_boulder : :loc_pushable
      end

      # The field move a push of boulder info takes: none for a Strength boulder once Strength is in use on the map,
      # as the game's pbPushThisBoulder then pushes it with nothing more asked.
      def self.move_for(info)
        info[1] == :STRENGTH && strength_used? ? nil : info[1]
      end

      # True once the player has used Strength on this map (the game's $PokemonMap.strengthUsed).
      def self.strength_used?
        ($PokemonMap.strengthUsed rescue false) ? true : false
      end

      # The moved boulders with rock now at (x,y), spent if the push spent it, in order.
      def self.moved_to(moved, rock, x, y, spent = false)
        (moved.reject { |m| m[0] == rock } + [[rock, x, y, spent ? true : false]]).sort
      end

      # The boulder standing on (x,y) in a state -- one moved there, or one never moved from there -- as the key of
      # the tile it started on, or nil.
      def self.rock_at(x, y, moved, rocks)
        moved.each { |m| return m[0] if m[1] == x && m[2] == y }
        k = Routes.pkey(x, y)
        return nil unless rocks[k]
        moved.any? { |m| m[0] == k } ? nil : k
      end

      # A state [x, y, moved, level] as one Integer: the player's state key plus one, then each moved boulder in
      # order, its starting tile's key over the key of where it is now and whether it is spent.
      def self.pack(st)
        k = PokeAccess::Pathfinder.skey(st[0], st[1], st[3]) + 1
        st[2].each { |rock, x, y, spent| k = (((k << BITS) | rock) << BITS) | (Routes.pkey(x, y) << 1) | (spent ? 1 : 0) }
        k
      end

      # The steps of a route up to its first push, pull or other assisted step, with that step's gate and the
      # transfers on the way (each at its step's last press, as Search.path_to has them); nil when it has none.
      def self.cut(came, k)
        steps = []
        while (c = came[k])
          steps.unshift(c[1])
          k = c[0]
        end
        path = PokeAccess::Pathfinder::Route.new
        warps = []
        steps.each do |d, presses, gate, warp|
          if gate
            path.warps = warps
            path.rooms = warps.length
            return [path, gate]
          end
          presses.times { path.push(d) }
          warps.push(path.length - 1) if warp
        end
        nil
      end
    end
  end
end

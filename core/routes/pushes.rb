module PokeAccess
  module Routes
    # Routes that move boulders out of the way, cut at their first push, pull or other assisted step: a search over
    # where the player stands and where each moved boulder was left, a state packed into one Integer. Boulders move as
    # the game would move them: a push of one tile (on over ice where they slide) or a pull (Effects.push_facet).
    module Pushes
      # How many boulders a route may move with the puzzle assist on, and how many states it may look at.
      LIMIT = 12
      NODES = 1500
      # The bits a moved boulder takes in a packed state: its starting tile's key over the key of where it is now.
      BITS = 32

      # A goal for a boulder rather than the player: the one starting on (x, y) (rock that tile's key, info its
      # boulder_index entry) inside the box [x0, y0, x1, y1], estimated off a field walked back from the box, and off it
      # by the Manhattan distance where it was cut or the boulder can be pulled (else FAR, no way).
      class RockGoal
        FIELD_CAP = 4000
        FAR = 1 << 30

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

        # The fewest presses the boulder's pushes into the box may take from where the moved boulders have it; FAR
        # where the field, walked whole, has no way for a boulder that cannot be pulled; one push's price where a push
        # may slide it on over ice (field), which takes it any number of tiles.
        def bound(_cx, _cy, moved = [])
          bx, by = where(moved)
          m = manhattan(bx, by)
          return 0 if m == 0 || @info.nil?
          n = field[Routes.pkey(bx, by)]
          price = 1 + PokeAccess::Pathfinder::GATE_COST
          return price if @slides
          return n * price if n
          @field_cut || @info[3] ? m * price : FAR
        end

        # The tile's Manhattan distance to the box.
        def manhattan(bx, by)
          x0, y0, x1, y1 = @box
          (bx < x0 ? x0 - bx : (bx > x1 ? bx - x1 : 0)) + (by < y0 ? y0 - by : (by > y1 ? by - y1 : 0))
        end

        # The pushes into the box from each tile, key => count, walked back from the box as the game moves the boulder
        # (Probe.event_movable?); where boulders slide, meeting ice or a cut sets @slides and bound counts one push.
        def field
          return @field if @field
          probe = PokeAccess::World::Probe
          terrain = PokeAccess::World::Terrain
          limits = PokeAccess::Pathfinder.limits
          ev = @info[0]
          ways = @info[4]
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
            iced ||= terrain.ice?(tx, ty)
            DIRS.each do |dx, dy, d|
              ax = tx - dx; ay = ty - dy
              iced ||= terrain.ice?(ax, ay)
              next if ways && !ways.include?(d)
              k = Routes.pkey(ax, ay)
              next if dist.key?(k) || !probe.landing(ax - dx, ay - dy)
              next unless probe.event_movable?(ev, ax, ay, d, [ax, ay, ax - dx, ay - dy])
              dist[k] = dist[Routes.pkey(tx, ty)] + 1
              queue.push([ax, ay])
            end
          end
          @slides = Pushes.sliding? && (iced || @field_cut) ? true : false
          @field = dist
        end

        # The boulder's tile: where the search moved it, else where it starts.
        def where(moved)
          m = (moved || []).find { |e| e[0] == @rock }
          m ? [m[1], m[2]] : [@x, @y]
        end
      end

      # The way to goal through pushes and pulls, up to the first of them or of another assisted step, as [steps,
      # gate]; nil when there is none within the limits.
      def self.route(goal)
        rocks = Effects.boulder_index
        return nil if rocks.empty?
        pf = PokeAccess::Pathfinder
        pf.with_gates_open do
          PokeAccess::World::Probe.lend_through(rocks.values.map { |r| r[0] }) { pf.searching { search(goal, rocks) } }
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # How many boulders a route may move: with the puzzle assist on, which plans a puzzle room for the player, up to
      # LIMIT; without it only the one that cuts the path, moved as often as it takes.
      def self.limit
        PokeAccess::Puzzles.assist? ? LIMIT : 1
      end

      # A best-first search over the packed states, priced in presses (a push, pull or other assisted step GATE_COST
      # more), estimated by goal.bound (a state at RockGoal::FAR left out); the player moves as a route on foot replays.
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
        pf.heap_push(heap, [goal.bound(px, py, []), 0, sk])
        until heap.empty?
          iter += 1
          return limits.cut! if iter > NODES
          return nil if limits.spent?(iter)
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
              est = goal.bound(nst[0], nst[1], nst[2])
              next if est >= RockGoal::FAR
              g[nk] = ng
              states[nk] = nst
              came[nk] = [k, step]
              pf.heap_push(heap, [ng + est, 0, nk])
            end
          end
        end
        nil
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

      # Pushing the boulder rock in front of (cx,cy) one tile along dir, to where it comes to rest (rest): the move, or
      # nil where the game would not move it or the route may move no more boulders.
      def self.push(cx, cy, dir, rock, moved, rocks, lvl)
        return nil unless pushes?(cx, cy, dir, rock, moved, rocks)
        info = rocks[rock]
        nx = cx + dir[0]; ny = cy + dir[1]
        gate = { :kind => :field, :label => label(info), :ev => info[0], :move => move_for(info), :x => nx, :y => ny }
        gate[:act] = true if info[2] == :act
        bx, by = rest(info[0], nx + dir[0], ny + dir[1], dir, moved, rocks, cx, cy)
        [[cx, cy, moved_to(moved, rock, bx, by), lvl], [dir[2], 1, gate], 1 + PokeAccess::Pathfinder::GATE_COST]
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

      # True when the boulder rock in front of (cx,cy) would move one tile along dir: one the route may move, pushed
      # that way (one that moves itself only takes the ways its page has), with no boulder beyond, that the game lets
      # move there.
      def self.pushes?(cx, cy, dir, rock, moved, rocks)
        return false unless movable?(rock, moved) && ready?(rocks[rock])
        ways = rocks[rock][4]
        return false if ways && !ways.include?(dir[2])
        nx = cx + dir[0]; ny = cy + dir[1]
        return false if rock_at(nx + dir[0], ny + dir[1], moved, rocks)
        PokeAccess::World::Probe.event_movable?(rocks[rock][0], nx, ny, dir[2], [nx, ny, cx, cy])
      end

      # Pulling the boulder rock in front of (cx,cy) along dir: the player steps back and it takes their tile, as the
      # game checks it; nil for one that cannot be pulled, or where turning toward it with the way held would push it.
      def self.pull(cx, cy, dir, rock, moved, rocks, lvl)
        info = rocks[rock]
        return nil unless info[3] && movable?(rock, moved) && ready?(info)
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

      # True when the game moves boulder info now: one with no condition of its own, or one whose condition holds
      # (Effects.push_script).
      def self.ready?(info)
        info[5].nil? || (info[5].call ? true : false)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # True when the route may move boulder rock: one it moved already, or one more within the limit.
      def self.movable?(rock, moved)
        moved.length < limit || moved.any? { |m| m[0] == rock }
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

      # The moved boulders with rock now at (x,y), in order.
      def self.moved_to(moved, rock, x, y)
        (moved.reject { |m| m[0] == rock } + [[rock, x, y]]).sort
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
      # order, its starting tile's key over the key of where it is now.
      def self.pack(st)
        k = PokeAccess::Pathfinder.skey(st[0], st[1], st[3]) + 1
        st[2].each { |rock, x, y| k = (((k << BITS) | rock) << BITS) | Routes.pkey(x, y) }
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

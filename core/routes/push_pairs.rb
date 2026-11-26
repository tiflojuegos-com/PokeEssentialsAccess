module PokeAccess
  module Routes
    module Pushes
      # The fewest pushes that take a piece and the events it moves along (RockGoal's others) into their boxes: a
      # breadth-first walk over where the pieces stand and the part of the floor the player is in (reach), every other
      # boulder lent through, then back from the states inside the boxes. A player away from the pieces is taken to get
      # to any tile behind them. Not built (unknown) where a member's push is long or goes further from some tiles, or a
      # pushed one may slide on ice.
      class Pairs
        CAP = 6000
        # The most tiles one reach of the player reads: past it, they are taken to get to any tile behind a piece.
        FLOOD = 3000
        # What left gives for a state the walk reached that never gets into the boxes.
        NEVER = :never

        # members: [[key of its tile, event, its push_pieces entry, x, y, box], ...], the pushed piece first; the player
        # on (px, py).
        def initialize(members, px, py)
          @members = members
          @slot = {}
          members.each_with_index { |m, i| @slot[m[1].object_id] = i }
          @memo = {}
          @seen = {}
          @reach = {}
          @lent = Effects.push_pieces.values.map { |r| r[0] }
          @dist = build(px, py)
        end

        # True when the walk could not be made (see the class): an estimate then takes no help from it.
        def unknown?; @dist.nil?; end

        # The pushes left from pos (each member's [x, y], in members' order) with the player on (px, py): a count,
        # NEVER, or nil for a state the walk did not reach.
        def left(pos, px, py)
          return nil if @dist.nil?
          st = [pos, reach(pos, px, py)[0]]
          d = @dist[st]
          return d if d
          @seen[st] ? NEVER : nil
        end

        # The walk forward, then the counts back from the states inside the boxes; nil past CAP or where it cannot tell.
        def build(px, py)
          return nil if @members.any? { |m| m[2][6] || m[2][8] }
          pos = @members.map { |m| [m[3], m[4]] }
          start = [pos, reach(pos, px, py)[0]]
          @seen[start] = true
          back = {}
          inside = []
          queue = [[start, px, py]]
          until queue.empty?
            return nil if @seen.size > CAP
            st, x, y = queue.shift
            inside.push(st) if inside?(st[0])
            successors(st[0], x, y).each do |i, dir, np|
              return nil if Pushes.sliding? && np.any? { |tx, ty| PokeAccess::World::Terrain.ice?(tx, ty) }
              sx = st[0][i][0] - dir[0]
              sy = st[0][i][1] - dir[1]
              ns = [np, reach(np, sx, sy)[0]]
              (back[ns] ||= []).push(st)
              next if @seen[ns]
              @seen[ns] = true
              queue.push([ns, sx, sy])
            end
          end
          counted(inside, back)
        end

        # The part of the floor the player on (x, y) walks to with the members on pos, as [name, tiles]: tiles as [x, y]
        # => true, named by the least of them; [:open, nil] past FLOOD or where it touches no member.
        def reach(pos, x, y)
          known = (@reach[pos] ||= {})
          hit = known[[x, y]]
          return hit if hit
          tiles, whole = PokeAccess::World::Probe.lend_through(@lent) { flood(pos, x, y) }
          r = whole && touches?(pos, tiles) ? [tiles.keys.min, tiles] : [:open, nil]
          tiles.each_key { |t| known[t] = r }
          r
        end

        # The tiles the player walks to from (x, y), the members' tiles on pos shut, and whether that is all of them
        # (false past FLOOD).
        def flood(pos, x, y)
          tiles = { [x, y] => true }
          queue = [[x, y]]
          until queue.empty?
            return [tiles, false] if tiles.size > FLOOD
            cx, cy = queue.shift
            DIRS.each do |dx, dy, d|
              t = [cx + dx, cy + dy]
              next if tiles[t] || pos.include?(t) || !PokeAccess::World::Probe.step?(cx, cy, d)
              tiles[t] = true
              queue.push(t)
            end
          end
          [tiles, true]
        end

        # True when some tile of tiles is beside a member on pos.
        def touches?(pos, tiles)
          pos.any? { |mx, my| DIRS.any? { |dx, dy, _d| tiles[[mx + dx, my + dy]] } }
        end

        # The pushes left from each state, walked back over back (state => states that lead to it) from inside.
        def counted(inside, back)
          dist = {}
          inside.each { |p| dist[p] = 0 }
          queue = inside.dup
          until queue.empty?
            p = queue.shift
            (back[p] || []).each do |f|
              next if dist.key?(f)
              dist[f] = dist[p] + 1
              queue.push(f)
            end
          end
          dist
        end

        # True when every member stands inside its box.
        def inside?(pos)
          (0...@members.length).all? do |i|
            x0, y0, x1, y1 = @members[i][5]
            pos[i][0] >= x0 && pos[i][0] <= x1 && pos[i][1] >= y0 && pos[i][1] <= y1
          end
        end

        def member(i); @members[i]; end

        # The pushes from pos with the player on (px, py), as [member pushed, its DIRS step, where the members stand
        # after]: one of a member the player can push, each way its page has and its push rule lets (Pushes.ready?),
        # from a tile behind it they can stand on (stand?) and walk to (reach), that moves it or one it moves along.
        def successors(pos, px, py)
          tiles = reach(pos, px, py)[1]
          out = []
          @members.each_with_index do |m, i|
            info = m[2]
            next if info[2] == :along
            DIRS.each do |dir|
              next if info[4] && !info[4].include?(dir[2])
              next unless Pushes.ready?(info, pos[i][0] + dir[0], pos[i][1] + dir[1])
              sx = pos[i][0] - dir[0]
              sy = pos[i][1] - dir[1]
              next unless stand?(pos, sx, sy) && (tiles.nil? || tiles[[sx, sy]])
              np = pos.dup
              moved = shift(np, i, dir)
              ((info[7] && info[7][dir[2]]) || []).each do |tw|
                j = @slot[tw.object_id]
                moved = shift(np, j, dir) || moved if j
              end
              out.push([i, dir, np]) if moved
            end
          end
          out
        end

        # True when the player can stand on (x, y) with the members on pos: no member there, and some step out of it is
        # open (Probe.landing).
        def stand?(pos, x, y)
          return false if pos.include?([x, y])
          k = [x, y]
          @ground ||= {}
          return @ground[k] if @ground.key?(k)
          @ground[k] = PokeAccess::World::Probe.landing(x, y) ? true : false
        end

        # Moves member i of np a tile along dir where no other member stands and the game lets it; true when it moved.
        def shift(np, i, dir)
          x, y = np[i]
          to = [x + dir[0], y + dir[1]]
          return false if np.include?(to) || !movable?(@members[i][1], x, y, dir)
          np[i] = to
          true
        end

        # The game's answer for ev moving off (x, y) along dir, pushed from behind.
        def movable?(ev, x, y, dir)
          k = [ev.object_id, x, y, dir[2]]
          return @memo[k] if @memo.key?(k)
          @memo[k] = PokeAccess::World::Probe.event_movable?(ev, x, y, dir[2], [x, y, x - dir[0], y - dir[1]]) ? true : false
        end
      end
    end
  end
end

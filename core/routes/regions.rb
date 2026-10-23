module PokeAccess
  module Routes
    # Where the player can get to on the map: the states the moves reach are walked breadth first, those a plain step
    # joins both ways united into regions (union-find) and every other move an edge between them. A question walks on
    # only within its allowance (a slice a frame with tick); a self-walking character is no wall (Events.mover?).
    class Regions
      # Each variant's moves and its share: the states its questions may walk at once in effort mode, then a tenth of it
      # a frame.
      VARIANTS = { :foot => [Moves::LEDGE, 10000], :assist => [Moves::LEDGE | Moves::ASSIST, 10000],
                   :water => [Moves::LEDGE | Moves::SURF_PLAN, 20000] }
      # The variants the map frames walk on, in turn.
      TICKED = [:foot, :water, :assist]
      # What a map frame may spend walking, in ms, and the map frames it waits once the regions were dropped.
      SLICE_MS = 2
      SETTLE_FRAMES = 10
      # How often, in states, a walk under a deadline reads the clock (a power of two: it is used as a mask).
      CLOCK = 8
      # The index in DIRS of each step's opposite.
      OPPOSITE = [1, 0, 3, 2]
      UNKNOWN = [:unknown].freeze
      NO = [:no].freeze

      @sets = {}
      @calm = 0

      # Drops every variant, each told it is gone; the map frames wait SETTLE_FRAMES before walking again.
      def self.forget
        @sets.each_value { |r| r.drop }
        @sets = {}
        @calm = PokeAccess::Frame.serial + SETTLE_FRAMES
      end

      # One map frame's walk with regions_background on: SLICE_MS for the first variant with states left, the assisted
      # one only where anything could assist; none for SETTLE_FRAMES once the regions were dropped, by this very frame's
      # reading of the world too.
      def self.tick
        return unless (PokeAccess::Config.regions_background rescue false)
        return if PokeAccess::Frame.serial < @calm || $game_player.nil?
        TICKED.each do |v|
          next if v == :assist && !PokeAccess::Pathfinder.assist_possible?
          r = self.for(v, false)
          return if PokeAccess::Frame.serial < @calm
          return if r.slice(SLICE_MS) > 0
        end
      end

      # The regions of a variant for the vehicle the player is on, the world brought level first (the events synced,
      # and the tiles compared with tiles; a map frame leaves them to the walk that reads them, as comparing dumps the
      # whole map).
      def self.for(variant, tiles = true)
        PokeAccess::World::Epoch.settle(tiles)
        PokeAccess::World::Events.sync
        key = [variant, PokeAccess::Pathfinder.vehicle_state]
        @sets[key] ||= new(variant)
      end

      # The regions on foot.
      def self.foot; self.for(:foot); end

      # The regions with the assisted steps.
      def self.assisted; self.for(:assist); end

      # The characters that walk about by themselves (World::Events.walkers) taken as no wall, lent through: those whose
      # absence is all their presence changes. Kept as walls: one whose touch does something (it carries, warps or
      # leaves on a bump), and one on or beside a tile that moves the player by itself, where it stops a slide.
      def self.lendable_walkers
        PokeAccess::World::Events.walkers.select { |ev| lent_over?(PokeAccess::World::Events.tiles_of(ev)) }
      end

      # True when a walker on tiles is lent through: none of them does something on a touch or moves the player.
      def self.lent_over?(tiles)
        tiles.none? { |x, y| Effects.touch_index[Routes.pkey(x, y)] || Moves.forcing?(x, y) }
      end

      # True when the walker of record r, over tiles, is lent through: its own touch does nothing either, read from the
      # record, as a change is told before the record joins the list touch_index reads.
      def self.lent?(r, tiles)
        own = PokeAccess::World::Events.facet(r, :touch)
        (own.nil? || own.empty?) && lent_over?(tiles)
      end

      # The regions by water.
      def self.water; self.for(:water); end

      # The regions of variant, none walked yet.
      def initialize(variant)
        @variant = variant
        @mode, @share = VARIANTS[variant]
        @id = {}
        @keys = []
        @levels = []
        @parent = []
        @size = []
        @mask = []
        @step = []
        @from = []
        @to = []
        @warp = []
        @moves = []
        @head = 0
        @version = 0
        @graph = nil
        @graph_version = -1
        @rooms = {}
        @tiles = nil
        @tiles_key = nil
        @left = @share
        @top_up = 0
        @frame = nil
        @deadline = nil
        @dropped = false
      end

      # Marks these regions as gone: whoever is asking them starts afresh.
      def drop; @dropped = true; end

      # True once the walk has begun and every state reached has been walked.
      def done?; !@keys.empty? && @head >= @keys.length; end

      # Whether the player can get to any of tiles (on either bridge level): [:yes, rooms away], [:no] once every
      # state reached is walked and none of theirs is, else [:unknown]; what the walk does not tell yet it walks on
      # for, within the question's allowance.
      def status(tiles)
        return Regions.for(@variant).status(tiles) if @dropped
        src = root
        return UNKNOWN unless src
        a = answer(src, tiles)
        return a unless a.equal?(UNKNOWN) && ask > 0
        answer(src, tiles)
      end

      # status as the walk tells it now, without walking on.
      def known(tiles)
        return Regions.for(@variant).known(tiles) if @dropped
        src = root
        src ? answer(src, tiles) : UNKNOWN
      end

      # Every tile the player can get to as [x, y], the walk gone on within the question's allowance first; kept until
      # the walk moves on or the player's region changes.
      def tiles
        return Regions.for(@variant).tiles if @dropped
        src = root
        return [] unless src
        ask
        top = find(src)
        rooms = rooms_from(top)
        key = [@graph_version, top]
        return @tiles if @tiles_key == key
        seen = {}
        out = []
        @keys.each_index do |i|
          next unless rooms[find(i)]
          t = @keys[i] >> 1
          next if seen[t]
          seen[t] = true
          out.push([t / PKEY_STRIDE, t % PKEY_STRIDE])
        end
        @tiles_key = key
        @tiles = out
      end

      # Walks on for a search cut short that the walk may yet answer (the regions router): by effort a whole share more
      # than the allowance gives, else as a question walks. The states walked.
      def renew
        return Regions.for(@variant).renew if @dropped
        return 0 unless root
        @left = @share if (PokeAccess::Config.route_limit rescue :effort) == :effort
        ask
      end

      # Walks on for ms of this map frame (tick); the states walked.
      def slice(ms)
        return 0 if @dropped || root.nil?
        advance(nil, PokeAccess.clock + ms / 1000.0)
      end

      # The region the player's state lies in, nil without a player; it changes as the walk unites regions.
      def zone
        src = root
        src ? find(src) : nil
      end

      # The player's state, added to the walk when new; nil without a player.
      def root
        return nil unless $game_player
        pf = PokeAccess::Pathfinder
        lvl = pf.bridge_level
        k = pf.skey($game_player.x, $game_player.y, lvl)
        @id[k] || add(k, lvl)
      end

      # [:yes, rooms away] when one of tiles lies in a region reached from src's, NO once all is walked, else UNKNOWN.
      def answer(src, tiles)
        rooms = rooms_from(find(src))
        pf = PokeAccess::Pathfinder
        best = nil
        tiles.each do |x, y|
          [0, 1].each do |l|
            i = @id[pf.skey(x, y, l)]
            r = i && rooms[find(i)]
            best = r if r && (best.nil? || r < best)
          end
        end
        return [:yes, best] if best
        done? && sure_no? ? NO : UNKNOWN
      end

      # True when a whole walk that reaches none of the tiles tells they cannot be got to: not in the assisted variant
      # while a boulder stands on or beside a tile that moves the player by itself (Moves.forcing?), as the walk lends
      # it through and so never takes the slides that stop at it.
      def sure_no?
        @variant != :assist || Effects.boulder_index.values.none? { |b| Moves.forcing?(b[0].x, b[0].y) }
      end

      # Walks on within what a question may still spend (allowance); the states walked.
      def ask
        a = allowance
        return 0 unless a
        n = advance(a[0], a[1])
        if @left > 0
          @left -= n
        else
          @top_up -= n
        end
        n
      end

      # What a question may still walk, as [states, deadline], nil for no bound in either: in effort mode the variant's
      # share at first, then a tenth of it a frame; under a time limit until the frame's deadline (route_budget_ms from
      # its first question); with none all of it. nil once spent.
      def allowance
        c = PokeAccess::Config
        mode = (c.route_limit rescue :effort)
        return [nil, nil] if mode == :none
        f = PokeAccess::World::Epoch.frame
        unless @frame == f
          @frame = f
          @deadline = PokeAccess.clock + (c.route_budget_ms rescue 12).to_i / 1000.0
          @top_up = @share / 10
        end
        return [nil, @deadline] if mode == :time
        n = @left > 0 ? @left : @top_up
        n > 0 ? [n, nil] : nil
      end

      # Walks on from where the walk stopped, up to max states and the deadline (nil: no bound); never while the probe's
      # answers are unstable. The events' indexes are read first, from the world as it stands, as nothing read while
      # events are lent is kept. The states walked.
      def advance(max, deadline)
        return 0 if done? || !PokeAccess::World::Probe.stable?
        pf = PokeAccess::Pathfinder
        probe = PokeAccess::World::Probe
        fx = Effects
        fx.touch_index
        fx.ramp_map?
        walkers = Regions.lendable_walkers
        pf.with_level_kept do
          if @variant == :assist
            rocks = fx.boulder_index.values.map { |b| b[0] }
            pf.with_gates_open { probe.lend_through(walkers + rocks) { walk(max, deadline) } }
          else
            probe.lend_through(walkers) { walk(max, deadline) }
          end
        end
      end

      # Walks the states in the order reached until all are, max are or the deadline passes; the states walked. A plain
      # step sets its bit in the state's mask and its target in @step (four slots a state), uniting both if it steps
      # back plainly too; any other move is an edge in @moves (from, to, direction, presses, warp) for the router.
      def walk(max, deadline)
        pf = PokeAccess::Pathfinder
        mv = Moves
        mode = @mode
        keys = @keys
        mask = @mask
        id = @id
        n = 0
        while @head < keys.length
          break if max && n >= max
          break if deadline && n > 0 && (n & (CLOCK - 1)) == 0 && PokeAccess.clock > deadline
          n += 1
          i = @head
          @head += 1
          t = keys[i] >> 1
          x = t / PKEY_STRIDE
          y = t % PKEY_STRIDE
          l = @levels[i]
          pf.use_level(l)
          b = 0
          while b < 4
            dir = DIRS[b]
            b += 1
            f = mv.fast(x, y, dir, mode)
            next if f.nil?
            if f == true
              nx = x + dir[0]; ny = y + dir[1]; nl = l; plain = true; warp = 0
            else
              s = mv.step(x, y, l, dir, mode)
              next if s.nil?
              nx = s.x; ny = s.y; nl = s.level; warp = s.warp ? 1 : 0
              plain = (s.kind == :walk || s.kind == :surf) && s.presses == 1 && s.gate.nil? && warp == 0 && nl == l &&
                      nx == x + dir[0] && ny == y + dir[1]
            end
            nk = pf.skey(nx, ny, nl)
            j = id[nk] || add(nk, nl)
            @moves.push(i, j, dir[2], s.presses, warp) unless plain
            if plain
              mask[i] |= 1 << (b - 1)
              @step[i * 4 + b - 1] = j
              if j < i && (mask[j] & (1 << OPPOSITE[b - 1])) != 0
                union(i, j)
                next
              end
            end
            @from.push(i)
            @to.push(j)
            @warp.push(warp)
          end
        end
        @version += 1 if n > 0
        n
      end

      # A state newly reached, as its index, to be walked in turn.
      def add(k, lvl)
        i = @keys.length
        @id[k] = i
        @keys.push(k)
        @levels.push(lvl)
        @parent.push(i)
        @size.push(1)
        @mask.push(0)
        @version += 1
        i
      end

      # The region of state i: the root of its tree, the path to it shortened on the way.
      def find(i)
        p = @parent
        r = i
        r = p[r] until p[r] == r
        while p[i] != r
          n = p[i]
          p[i] = r
          i = n
        end
        r
      end

      # Unites the regions of states a and b, the smaller under the larger.
      def union(a, b)
        ra = find(a)
        rb = find(b)
        return if ra == rb
        ra, rb = rb, ra if @size[ra] < @size[rb]
        @parent[rb] = ra
        @size[ra] += @size[rb]
      end

      # The edges between regions, root => [root, transfer (1) or not (0), ...], worked out again once the walk moved
      # on; an edge left inside a region is dropped for good, as regions only ever merge.
      def graph
        return @graph if @graph_version == @version
        out = {}
        from = []
        to = []
        warp = []
        @from.each_index do |e|
          a = find(@from[e])
          b = find(@to[e])
          next if a == b
          (out[a] ||= []).push(b, @warp[e])
          from.push(@from[e])
          to.push(@to[e])
          warp.push(@warp[e])
        end
        @from = from
        @to = to
        @warp = warp
        @rooms = {}
        @graph_version = @version
        @graph = out
      end

      # The fewest transfers from region src to each region it reaches (0 for its own and those reached without one),
      # kept until the walk moves on.
      def rooms_from(src)
        g = graph
        hit = @rooms[src]
        return hit if hit
        rooms = { src => 0 }
        cur = [src]
        d = 0
        until cur.empty?
          nxt = []
          k = 0
          while k < cur.length
            r = cur[k]
            k += 1
            next unless rooms[r] == d
            adj = g[r]
            next unless adj
            j = 0
            while j < adj.length
              b = adj[j]
              nd = d + adj[j + 1]
              j += 2
              old = rooms[b]
              next if old && old <= nd
              rooms[b] = nd
              (nd == d ? cur : nxt).push(b)
            end
          end
          cur = nxt
          d += 1
        end
        @rooms[src] = rooms
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Regions.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Regions.forget }
# A walker the regions lend through keeps them as it comes, goes or steps; one they walk as a wall, or any other
# change, drops them.
PokeAccess::World::Events.on_change do |tiles, r, how|
  lent = how != :change && PokeAccess::World::Events.mover?(r) && PokeAccess::Routes::Regions.lent?(r, tiles)
  PokeAccess::Routes::Regions.forget unless lent
end

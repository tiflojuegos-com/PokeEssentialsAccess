module PokeAccess
  module Routes
    # The fast path of Moves: each tile's class (bits telling a move out of it or into it may be more than a plain
    # step), kept while the map's tiles, events and rules stand, and fast, which answers plain moves from the classes
    # and the probe and leaves the rest to step, answering as step would.
    module Moves
      # fast's answer when only step can say.
      SPECIAL = :special

      # A tile's class: a ledge, ice, falling water (a waterfall or its crest), owned by an arrival rule, owned by a
      # departure rule, a touch event's tile (an effect on arrival or on a bump, a run armed, ground to hold), a bridge
      # tile (whose terrain changes with the bridge height), on the map's border, off the map.
      C_LEDGE = 1
      C_ICE = 2
      C_FALL = 4
      C_IN = 8
      C_OUT = 16
      C_EVENT = 32
      C_BRIDGE = 64
      C_BORDER = 128
      C_OFF = 256
      # The classes a move out of a tile, or into it, may be special from.
      FROM_SPECIAL = C_OUT | C_EVENT | C_BRIDGE
      INTO_SPECIAL = C_LEDGE | C_ICE | C_IN | C_EVENT | C_BRIDGE | C_OFF
      # The classes of a tile that moves the player by itself (forcing?).
      FORCING = C_ICE | C_IN | C_OUT

      # A tile's class in an assisted search: an obstacle a field move clears, an action-button event's tile, a tile in
      # front a registered assisted step owns.
      A_GATE = 1
      A_ACT = 2
      A_FRONT = 4

      # Touch effects that take the player off the tile in front.
      RELOCATING = [:carry, :warp, :run]

      # The most tiles one press may take the player along each of DIRS (up, down, left, right), for a search's
      # estimate.
      class Strides
        def initialize(all)
          @all = all
          @up, @down, @left, @right = all
        end

        # The fewest presses that may cover dx tiles right and dy down (negative: left and up), each press along one
        # way.
        def presses(dx, dy)
          (dx > 0 ? (dx + @right - 1) / @right : (@left - 1 - dx) / @left) +
            (dy > 0 ? (dy + @down - 1) / @down : (@up - 1 - dy) / @up)
        end

        # True when a press covers one tile whichever way.
        def plain?; @all == [1, 1, 1, 1]; end
      end

      # One tile a press, whichever way.
      ONE_STRIDE = Strides.new([1, 1, 1, 1])

      @krows = []
      @arows = []
      @kgen = nil
      @kw = nil
      @kh = nil
      @scan = nil
      @reloc = nil
      @shortcuts = nil
      @strides = nil
      @crowded = nil

      # Drops the classes taken (the events changed).
      def self.forget_classes
        @krows = []
        @arows = []
        @kgen = nil
        @kw = nil
        @kh = nil
      end

      # Drops the classes, the map's scan, its shortcuts and strides (the tiles, the map or the rules changed).
      def self.forget_map
        forget_classes
        @scan = nil
        @shortcuts = nil
        @strides = nil
        @crowded = nil
      end

      # A move from (cx,cy) toward dir with mode as the classes and the probe tell: true for a plain step (one press,
      # no gate, no transfer), nil for none (onto a closed tile too), SPECIAL when only step can say.
      def self.fast(cx, cy, dir, mode)
        g = PokeAccess::World::Events.gen
        forget_classes unless g == @kgen
        @kgen = g
        return water_fast(cx, cy, dir) if (mode & SURF_PLAN) != 0
        return SPECIAL if (klass(cx, cy) & FROM_SPECIAL) != 0
        nx = cx + dir[0]; ny = cy + dir[1]
        return nil if @closed && @closed[Routes.pkey(nx, ny)]
        k = klass(nx, ny)
        return SPECIAL if (k & INTO_SPECIAL) != 0
        return SPECIAL if (k & C_FALL) != 0 && ($PokemonGlobal.surfing rescue false)
        assist = (mode & ASSIST) != 0
        return SPECIAL if assist && ((aklass(nx, ny) & (A_GATE | A_ACT | A_FRONT)) != 0 || (aklass(cx, cy) & A_ACT) != 0)
        return true if PokeAccess::World::Probe.flat_step?(cx, cy, dir[2], nx, ny)
        return SPECIAL if (k & C_BORDER) != 0 && (mode & RELAX) != 0
        return SPECIAL if assist && (($PokemonGlobal.bicycle rescue false) || @assist_sources.any? { |r| r.owner.nil? })
        nil
      end

      # A planned surf's move as far as the terrain and the probe tell: true from water onto water that does not fall,
      # open afloat, one press as water_step takes it; nil when a surfer cannot make it; SPECIAL for any other (a shore,
      # a touch event or a bridge on the way, water an arrival rule owns ahead).
      def self.water_fast(cx, cy, dir)
        nx = cx + dir[0]; ny = cy + dir[1]
        return SPECIAL unless surf_water?(cx, cy) && surf_water?(nx, ny)
        k = klass(nx, ny)
        return SPECIAL if ((klass(cx, cy) | k) & (C_EVENT | C_BRIDGE)) != 0 || (k & C_IN) != 0
        probe = PokeAccess::World::Probe
        probe.afloat { probe.flat_step?(cx, cy, dir[2], nx, ny) } ? true : nil
      end

      # True when (x,y) or a tile beside it moves the player by itself (ice, a tile an arrival or leave rule owns): a
      # character standing there stops a slide.
      def self.forcing?(x, y)
        g = PokeAccess::World::Events.gen
        forget_classes unless g == @kgen
        @kgen = g
        [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].any? { |dx, dy| (klass(x + dx, y + dy) & FORCING) != 0 }
      end

      # The class bits of (x,y) (C_*), taken on first sight.
      def self.klass(x, y)
        w = (@kw ||= ($game_map.width rescue 0).to_i)
        return C_OFF if x < 0 || y < 0 || x >= w || y >= (@kh ||= ($game_map.height rescue 0).to_i)
        row = (@krows[y] ||= [])
        k = row[x]
        k.nil? ? (row[x] = tile_class(x, y)) : k
      end

      # The class bits of (x,y) as they stand now (see klass).
      def self.tile_class(x, y)
        t = PokeAccess::World::Terrain
        return C_BRIDGE if t.bridge_at?(x, y)
        c = t.cell(x, y)
        k = 0
        k |= C_LEDGE if (c & t::LEDGE) != 0
        k |= C_ICE if (c & t::ICE) != 0
        k |= C_FALL if (c & t::FALLING) != 0
        k |= C_IN if @arrival_rules.any? { |r| owns?(r.owner, x, y) }
        k |= C_OUT if @leave_rules.any? { |r| owns?(r.owner, x, y) }
        k |= C_EVENT if Effects.touch_index[Routes.pkey(x, y)]
        k |= C_BORDER if border_tile?(x, y)
        k
      end

      # The assisted class bits of (x,y) (A_*), taken on first sight by an assisted search.
      def self.aklass(x, y)
        return 0 if PokeAccess::World::Terrain.outside?(x, y)
        row = (@arows[y] ||= [])
        k = row[x]
        k.nil? ? (row[x] = assisted_class(x, y)) : k
      end

      # The assisted class bits of (x,y) as they stand now (see aklass).
      def self.assisted_class(x, y)
        key = Routes.pkey(x, y)
        k = 0
        k |= A_GATE if Effects.gate_index[key]
        k |= A_ACT if Effects.act_index[key]
        k |= A_FRONT if @assist_sources.any? { |r| r.owner && owns?(r.owner, x, y) }
        k
      end

      # The most tiles one press may take the player across on this map with the moves of mode, for a search's
      # estimate: 1, 2 where ledge hops count, or nil when there is no telling (see base_speed, and a touch event that
      # carries, warps or runs, whose moves shortcuts lists).
      def self.speed(mode)
        relocating? ? nil : base_speed(mode)
      end

      # speed but for the touch events that move the player: nil with ice, falling water afloat or in a planned surf,
      # a rule that may move the player, and in an assisted search an action-button event or a registered assisted
      # step that owns a tile here.
      def self.base_speed(mode)
        t = PokeAccess::World::Terrain
        bits, loose, _bridges, _ledges, assisted = map_scan
        return nil if loose
        return nil if (bits & t::FALLING) != 0 && ((mode & SURF_PLAN) != 0 || ($PokemonGlobal.surfing rescue false))
        return nil if (mode & ASSIST) != 0 && (assisted || !Effects.act_index.empty?)
        ((mode & LEDGE) != 0 && (bits & t::LEDGE) != 0) ? 2 : 1
      end

      # The map's scan (map_scan), for World::Visits to keep with the map left.
      def self.saved_scan; @scan; end

      # Puts back a scan saved with the map.
      def self.restore_scan(s); @scan = s; end

      # The map's terrain for speed, read once per map and tiles: [the terrain bits of all its tiles (both bridge
      # heights), whether a press may cover any number of them (ice, or an arrival or leave rule owning a tile here),
      # whether it has bridges, its ledge tiles, whether a registered assisted step owns a tile here].
      def self.map_scan
        return @scan if @scan
        t = PokeAccess::World::Terrain
        w = ($game_map.width rescue 0).to_i
        h = ($game_map.height rescue 0).to_i
        bits = 0
        reps = {}
        bridges = false
        ledges = []
        (0...h).each do |y|
          (0...w).each do |x|
            bridge = t.bridge_at?(x, y)
            bridges ||= bridge
            c = t.cell(x, y)
            ledges.push([x, y]) if (c & t::LEDGE) != 0
            bits |= c | (bridge ? t.cell(x, y, true) : 0)
            reps[t.index(x, y, false)] ||= [x, y]
          end
        end
        owned = lambda do |r|
          o = r.owner
          next true if o.nil? || bridges || reps.values.any? { |x, y| owns?(o, x, y) }
          o[:tiles] ? (0...h).any? { |y| (0...w).any? { |x| (o[:tiles].call(x, y) rescue false) } } : false
        end
        loose = (bits & t::ICE) != 0 || @arrival_rules.dup.concat(@leave_rules).any?(&owned)
        @scan = [bits, loose, bridges, ledges, @assist_sources.any?(&owned)]
      end

      # How far a press may take the player along each way on this map with the moves of mode, as Strides: two the
      # ways a ledge hop sets off in (each ledge asked from its four sides, kept while the events stand; every way on a
      # map with bridges, whose levels the hops are not told apart on), else one; nil where base_speed has no telling.
      def self.strides(mode)
        s = base_speed(mode)
        return nil if s.nil?
        return ONE_STRIDE if s == 1
        scan = map_scan
        return Strides.new([2, 2, 2, 2]) if scan[2]
        key = [PokeAccess::World::Events.gen, PokeAccess::Pathfinder.event_epoch]
        return @strides[1] if @strides && @strides[0] == key
        probe = PokeAccess::World::Probe
        all = [1, 1, 1, 1]
        scan[3].each do |x, y|
          DIRS.each_with_index { |dir, i| all[i] = 2 if all[i] == 1 && probe.step?(x - dir[0], y - dir[1], dir[2]) }
        end
        @strides = [key, Strides.new(all)]
        @strides[1]
      end

      # The moves into this map's carries, warps and runs as step takes them from level lvl with mode, as [from x,
      # from y, presses, landing x, landing y], kept while the events stand; nil on a map with bridges.
      def self.shortcuts(lvl, mode)
        return nil if map_scan[2]
        key = [PokeAccess::World::Events.gen, PokeAccess::Pathfinder.event_epoch, lvl, mode]
        return @shortcuts[1] if @shortcuts && @shortcuts[0] == key
        out = []
        Effects.touch_index.each do |k, t|
          next unless t[1].values.any? { |e| RELOCATING.include?(e[0]) }
          ex = k / Routes::PKEY_STRIDE; ey = k % Routes::PKEY_STRIDE
          DIRS.each do |dir|
            [[ex - dir[0], ey - dir[1]], [ex - 2 * dir[0], ey - 2 * dir[1]], [ex, ey]].each do |fx, fy|
              s = step(fx, fy, lvl, dir, mode)
              out.push([fx, fy, s.presses, s.x, s.y]) if s && RELOCATING.include?(s.kind)
            end
          end
        end
        out.uniq!
        @shortcuts = [key, out]
        out
      end

      # True while this map's shortcuts were found too many for a bound (Bound::WORK) under the same event
      # pages, vehicle and level: a character's step does not change that, so the list is not built again for it.
      def self.crowded?(lvl, mode)
        @crowded == [PokeAccess::Pathfinder.event_epoch, lvl, mode]
      end

      # Remembers that the shortcuts are too many for a bound, until the event pages, the vehicle or the level change.
      def self.crowd!(lvl, mode)
        @crowded = [PokeAccess::Pathfinder.event_epoch, lvl, mode]
      end

      # True when a touch event of this map carries, warps or runs the player, kept while the events stand.
      def self.relocating?
        idx = Effects.touch_index
        g = PokeAccess::World::Events.gen
        return @reloc[1] if @reloc && @reloc[0] == g
        v = idx.values.any? { |e| e[1].values.any? { |f| RELOCATING.include?(f[0]) } }
        @reloc = [g, v]
        v
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Moves.forget_map }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Routes::Moves.forget_map }
PokeAccess::World::Visits.keeper(lambda { PokeAccess::Routes::Moves.saved_scan },
                                 lambda { |s| PokeAccess::Routes::Moves.restore_scan(s) })

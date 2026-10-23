module PokeAccess
  module Routes
    # One move from a search state as the game plays it, and the replay of a route with the same moves: a run armed on
    # the tile, else the step over the terrain (moves_terrain) and the event it lands on, else the event it bumps and,
    # with ASSIST, what gets the player past it.
    module Moves
      # The mode bits of a search or a replay: ledge hops, assisted steps (a gate, the action button, Waterfall, a
      # registered assist, getting off the bike), a passable border tile as a step (edge_relax), and surfing (afloat
      # only water moves, ashore the move on foot and then pushing off).
      LEDGE = 1
      ASSIST = 2
      RELAX = 4
      SURF_PLAN = 8

      # How many touch events one carry may hand the player on to (an arrow floor is a chain of them).
      CARRY_HOPS = 32
      # Effects that leave a step onto their tile where it lands: the run it arms, ground to hold the key on.
      IN_PLACE = [:run, :hold]

      # One move of a route as a search makes it and a replay retraces it: the tile and bridge level it ends on, its
      # presses (a run, a ride across), an assisted step's gate (route_gates), mid (passed partway along a run), warp (a
      # transfer on this map) and kind: :walk, :jump, :slide, :carry, :warp, :run, :ramp, :assist or :surf.
      Step = Struct.new(:x, :y, :level, :presses, :gate, :mid, :warp, :kind)

      # Step with the defaults a plain move has: one press, no gate, not partway along a run, no transfer, a walk.
      class Step
        def initialize(x, y, level, presses = 1, gate = nil, mid = false, warp = false, kind = :walk)
          super
        end

        # The [x, y] tile the step leaves the player on.
        def tile; [x, y]; end
      end

      # A registered rule: the tiles it owns (see owns?) and its block.
      Rule = Struct.new(:owner, :body)

      @arrival_rules = []
      @held_rules = []
      @leave_rules = []
      @assist_sources = []

      # Registers a terrain rule: the block gets (x, y, d) for a step arriving on (x,y) in direction d and answers the
      # [x, y] it ends on ([x, y, presses] for ground ridden straight across with the key held, a press a tile), false
      # when the step cannot be taken, or nil when the tile is none of its terrain.
      # param owner the tiles it may answer for (see owns?); without one it is asked on every tile
      def self.arrival_rule(owner = nil, &rule); register(@arrival_rules, owner, rule); end

      # Registers the tiles where the player has to keep the direction key held down, or the terrain throws them
      # back: the block gets (x, y) and answers true on such a tile.
      # param owner as arrival_rule's
      def self.held_key_rule(owner = nil, &rule); register(@held_rules, owner, rule); end

      # Registers terrain the player leaves by a move of its own (a rail hopped off): the block gets (x, y, dir) and
      # answers the [x, y] the press lands on, false when it fails, or nil when (x,y) is none of its terrain.
      # param owner as arrival_rule's, of the tile left
      def self.leave_rule(owner = nil, &rule); register(@leave_rules, owner, rule); end

      # Registers an assisted step a plugin or a game adds (a wall climbed with its own item): the block gets
      # (x, y, dir, level) and answers a Step with its gate, or nil.
      # param owner the tiles in front it may answer for, as arrival_rule's with each key prefixed front_
      def self.assist_source(owner = nil, &blk); register(@assist_sources, owner, blk, "front_"); end

      # The keys an owner may have (see owns?).
      OWNER_KEYS = [:tags, :kinds, :flags, :tiles]

      # Adds a rule to its stage, its owner's keys read without prefix, and has the tile classes and the map's scan
      # taken afresh; an owner key it does not know is an error, so a misspelt one cannot silence a rule.
      def self.register(list, owner, body, prefix = "")
        own = nil
        if owner
          own = {}
          owner.each do |k, v|
            key = k.to_s.index(prefix) == 0 ? k.to_s[prefix.length..-1].to_sym : nil
            raise ArgumentError, "unknown rule owner key #{k.inspect}" unless OWNER_KEYS.include?(key)
            own[key] = v
          end
        end
        list.push(Rule.new(own, body))
        forget_map
      end

      # True when a rule's owner takes in (x,y): its terrain number in :tags, its kind in :kinds, a flag of :flags,
      # or a yes from the :tiles block, which may read only the map's tiles and events; any tile when it has no
      # owner. A list may come as a block, read when asked (a game's numbers known only once it runs).
      def self.owns?(owner, x, y)
        return true if owner.nil?
        t = PokeAccess::World::Terrain
        v = owner[:tags]
        return true if v && listed(v).include?(t.number(x, y))
        v = owner[:kinds]
        return true if v && listed(v).include?(t.kind(x, y))
        v = owner[:flags]
        return true if v && listed(v).any? { |f| t.flag?(x, y, f) }
        v = owner[:tiles]
        v ? ((v.call(x, y) rescue false) ? true : false) : false
      end

      # An owner's list, read from its block when it comes as one.
      def self.listed(v); v.respond_to?(:call) ? v.call : v; end

      # True when a game or plugin registered an assisted step.
      def self.assist_registered?; !@assist_sources.empty?; end

      # True when a game or plugin registered terrain that moves the player on arriving or leaving.
      def self.ruled_terrain?
        !@arrival_rules.empty? || !@leave_rules.empty?
      end

      # True when every move here is one plain tile, as the uniform-grid searches (JPS, HPA*) need: not surfing (a
      # waterfall carries), and no touch events or registered terrain that move the player.
      def self.uniform?
        return false if ($PokemonGlobal.surfing rescue false)
        Effects.touch_index.empty? && !ruled_terrain?
      end

      # One move from (cx,cy) at bridge level lvl toward dir ([dx, dy, d], see DIRS) as the game plays it, with the
      # bits of mode: a Step, or nil when it goes nowhere or off the map (the latter without asking the engine).
      def self.step(cx, cy, lvl, dir, mode)
        return nil if PokeAccess::World::Terrain.outside?(cx + dir[0], cy + dir[1])
        return surf_step(cx, cy, lvl, dir, mode) if (mode & SURF_PLAN) != 0
        d = dir[2]
        run = run_from(cx, cy, d)
        return run_step(cx, cy, d, run, lvl) if run
        dx = dir[0]; dy = dir[1]
        nx = cx + dx; ny = cy + dy
        kind = :jump
        nbr = departure(cx, cy, dir)
        if nbr.nil?
          c = PokeAccess::World::Terrain.cell(nx, ny)
          if (c & PokeAccess::World::Terrain::LEDGE) != 0
            nbr = (mode & LEDGE) != 0 ? ledge_jump(cx, cy, dx, dy, d) : nil
            return nil if nbr == false
            nbr = ice_slide(nbr[0], nbr[1], dx, dy, d) if nbr && PokeAccess::World::Terrain.ice?(nbr[0], nbr[1])
          elsif PokeAccess::World::Probe.step?(cx, cy, d)
            nbr = (c & PokeAccess::World::Terrain::ICE) != 0 ? ice_slide(nx, ny, dx, dy, d) : arrive(nx, ny, d)
            kind = (nbr && !nbr[2] && (nbr[0] != nx || nbr[1] != ny)) ? :slide : :walk
          elsif (mode & RELAX) != 0 && border_tile?(nx, ny) && ($game_map.passable?(nx, ny, 0) rescue false)
            nbr = [nx, ny]
            kind = :walk
          end
        end
        nbr ? landed(nbr, lvl, d, kind, mode) : bump(cx, cy, lvl, dir, mode)
      end

      # The Step a move onto nbr facing d ends as once the touch event there fires: the tile, a ramp's other level or a
      # carry's or warp's landing; nil off the map, at an exit or barrier (a carry's chain too), or on a closed tile.
      # Its presses are nbr's third, if any (ground ridden across, see arrival_rule).
      def self.landed(nbr, lvl, d, kind, mode)
        x = nbr[0]; y = nbr[1]
        p = nbr[2] || 1
        return nil unless ($game_map.valid?(x, y) rescue true)
        return nil if @closed && @closed[Routes.pkey(x, y)]
        gate = (mode & ASSIST) != 0 ? Effects.gate_at(x, y) : nil
        e = Effects.touch_at(x, y, d, true)
        return Step.new(x, y, lvl, p, gate, false, false, kind) if e.nil? || IN_PLACE.include?(e[0])
        case e[0]
        when :exit, :barrier then nil
        when :ramp then Step.new(x, y, ramp_level(e[1], lvl), p, gate, false, false, :ramp)
        else
          via = []
          l = e[0] == :carry ? carry_landing(x, y, e, 0, via) : PokeAccess::World::Probe.landing(e[1], e[2])
          return nil if l == false
          return Step.new(x, y, lvl, p, gate, false, false, kind) unless l
          Step.new(l[0], l[1], lvl, p, gate, false, e[0] == :warp || !via.empty?, e[0])
        end
      end

      # A move into what stops a step: the bumped touch event's carry or warp, else with ASSIST what gets the player
      # past it (assisted).
      def self.bump(cx, cy, lvl, dir, mode)
        e = Effects.touch_at(cx + dir[0], cy + dir[1], dir[2], false)
        via = []
        l = case (e && e[0])
            when :carry then carry_landing(cx, cy, e, 0, via)
            when :warp then PokeAccess::World::Probe.landing(e[1], e[2])
            end
        return Step.new(l[0], l[1], lvl, 1, nil, false, e[0] == :warp || !via.empty?, e[0]) if l
        return nil if (mode & ASSIST) == 0
        s = assisted(cx, cy, dir, lvl)
        s.kind = :assist if s
        s
      end

      # A move with SURF_PLAN: afloat only a water move (water_step); ashore the move on foot and, failing it, pushing
      # off.
      def self.surf_step(cx, cy, lvl, dir, mode)
        wet = surf_water?(cx, cy)
        s = wet ? nil : step(cx, cy, lvl, dir, mode & ~SURF_PLAN)
        return s if s
        s = water_step(cx, cy, dir, lvl, wet)
        s.kind = :surf if s
        s
      end

      # The run armed on (x,y) that sets off in direction d, or nil.
      def self.run_from(x, y, d)
        t = Effects.touch_index[Routes.pkey(x, y)]
        return nil if t.nil?
        r = t[1].values.find { |e| e[0] == :run }
        (r && r[1] == d) ? r : nil
      end

      # A run taken from (x,y): its first step is the engine's to allow, the rest cross whatever the tiles say, and it
      # lands where the run ends, a Step of the run's presses; nil when it cannot be taken.
      def self.run_step(x, y, d, run, lvl)
        return nil unless PokeAccess::World::Probe.step?(x, y, d)
        l = PokeAccess::World::Probe.landing(x + run[3], y + run[4])
        l ? Step.new(l[0], l[1], lvl, run[2], nil, false, false, :run) : nil
      end

      # Where a carry from (x,y) leaves the player, a touch event fired along its steps taking over; false for a chain
      # that cannot be taken (off the map, a story block, past CARRY_HOPS), nil when it lands on no tile.
      # param via an Array that gets an entry when the chain ends through a transfer to another spot of the map
      def self.carry_landing(x, y, e, hops = 0, via = nil)
        return false if hops > CARRY_HOPS
        (e[4] || []).each do |dx, dy, face|
          nxt = face ? Effects.touch_at(x + dx, y + dy, face, true) : nil
          next if nxt.nil? || nxt[0] == :ramp || IN_PLACE.include?(nxt[0])
          return false if nxt[0] == :exit || nxt[0] == :barrier
          return carry_landing(x + dx, y + dy, nxt, hops + 1, via) unless nxt[0] == :warp
          via.push(true) if via
          return PokeAccess::World::Probe.landing(nxt[1], nxt[2])
        end
        PokeAccess::World::Probe.landing(x + e[1], y + e[2])
      end

      # The bridge level a ramp leaves the player on, from the level they stepped on it at.
      def self.ramp_level(ramp, lvl)
        return (lvl.to_i > 0 ? 0 : 2) if ramp == :toggle
        ramp.to_i
      end

      # What the player can do from (cx,cy) toward dir where walking stops, as a Step with its gate, or nil: the
      # action button, climbing a waterfall, a registered assist, getting off the bike.
      def self.assisted(cx, cy, dir, lvl)
        s = act_step(cx, cy, dir, lvl) || waterfall_step(cx, cy, dir, lvl)
        return s if s
        @assist_sources.each do |src|
          next unless owns?(src.owner, cx + dir[0], cy + dir[1])
          s = (src.body.call(cx, cy, dir, lvl) rescue nil)
          return s if s
        end
        dismount_step(cx, cy, dir, lvl)
      end

      # The action button pressed facing dir: at the event in front, or at the one the player stands on when it fires
      # from its own tile.
      def self.act_step(cx, cy, dir, lvl)
        d = dir[2]
        e = Effects.act_at(cx + dir[0], cy + dir[1], d, false) || Effects.act_at(cx, cy, d, true)
        return nil if e.nil?
        probe = PokeAccess::World::Probe
        l = e[0] == :warp ? probe.landing(e[1], e[2]) : probe.landing(cx + e[1], cy + e[2])
        l ? Step.new(l[0], l[1], lvl, 1, { :kind => :act, :face => d, :x => cx, :y => cy }) : nil
      end

      # Climbing a waterfall with Waterfall: surfing, facing up into the fall.
      def self.waterfall_step(cx, cy, dir, lvl)
        return nil unless dir[2] == 8 && ($PokemonGlobal.surfing rescue false)
        l = waterfall_ascent(cx, cy - 1)
        return nil if l.nil?
        gate = { :kind => :field, :label => :surf_waterfall, :move => :WATERFALL, :x => cx, :y => cy - 1 }
        Step.new(l[0], l[1], lvl, 1, gate)
      end

      # Getting off the bike where it cannot go on (tall grass, ice), on a map that lets the player off it.
      def self.dismount_step(cx, cy, dir, lvl)
        return nil unless ($PokemonGlobal.bicycle rescue false)
        return nil if PokeAccess::MapMeta.always_bicycle?(($game_map.map_id rescue 0))
        probe = PokeAccess::World::Probe
        return nil unless probe.on_foot { probe.step?(cx, cy, dir[2]) }
        Step.new(cx + dir[0], cy + dir[1], lvl, 1, { :kind => :dismount, :face => dir[2], :x => cx, :y => cy })
      end

      # Runs the block with the tiles of closed (pkey => true) kept off: no move lands on them.
      def self.with_closed(closed)
        was = @closed
        @closed = closed
        yield
      ensure
        @closed = was
      end

      # Replays a route from (x,y) at bridge level lvl with the moves of mode, one Step per press (mid Steps, of the
      # move's kind, for the tiles a run or a ride across passes), stopping at the first that cannot be taken now.
      def self.trace(x, y, lvl, path, mode)
        pf = PokeAccess::Pathfinder
        out = []
        pf.searching do
          i = 0
          while i < path.length
            d = path[i]
            dir = DIR_OF[d]
            pf.use_level(lvl)
            n = dir ? step(x, y, lvl, dir, mode) : nil
            break if n.nil?
            presses = n.presses
            break unless path[i, presses].length == presses && path[i, presses].all? { |c| c == d }
            (1...presses).each do |k|
              out.push(Step.new(x + dir[0] * k, y + dir[1] * k, lvl, 1, nil, true, false, n.kind))
            end
            x = n.x; y = n.y; lvl = n.level
            out.push(n)
            i += presses
          end
        end
        out
      end

      # What each press of a route from (x,y) at bridge level lvl does that cannot be undone the same way: :jump where
      # the player hops (a ledge, an event that hops them over, as jump? tells the guide), :slide where it slides them
      # on, else nil; nil from the first press the route cannot take now.
      def self.one_way(x, y, lvl, path)
        steps = trace(x, y, lvl, path, PokeAccess::Pathfinder.replay_mode)
        from = [[x, y]] + steps.map { |s| [s.x, s.y] }
        (0...path.length).map do |i|
          s = steps[i]
          if s.nil? then nil
          elsif jump?(from[i][0], from[i][1], path[i]) then :jump
          elsif s.kind == :slide then :slide
          end
        end
      end

      # True if a route step from (x,y) in direction d can be taken now with the moves of mode, from the player's
      # bridge level: the first press of a run counts as its start.
      def self.ok?(x, y, d, mode)
        dir = DIR_OF[d]
        return false if dir.nil?
        pf = PokeAccess::Pathfinder
        pf.searching do
          lvl = pf.bridge_level
          pf.use_level(lvl)
          !step(x, y, lvl, dir, mode).nil?
        end
      end

      # True if the step from (x,y) in direction d is a jump the player makes by walking into it: a ledge, or an event
      # that hops them over what it stands on.
      def self.jump?(x, y, d)
        dd = PokeAccess::DIR_DELTA[d]
        return false if dd.nil?
        nx = x + dd[0]; ny = y + dd[1]
        return true if PokeAccess::World::Terrain.ledge?(nx, ny)
        e = Effects.touch_at(nx, ny, d, false) || Effects.touch_at(nx, ny, d, true)
        !e.nil? && e[0] == :carry && e[3] ? true : false
      end

      # True if the player must hold the direction key down on (x,y): ground a game registers, a touch event there
      # that lets the player on only so, or one that fires as they arrive and carries them on only with the key held.
      def self.held?(x, y)
        return true if @held_rules.any? { |rule| owns?(rule.owner, x, y) && (rule.body.call(x, y) rescue false) }
        t = Effects.touch_index[Routes.pkey(x, y)]
        !t.nil? && t[1].values.any? { |e| e[0] == :hold || (t[0] && e[0] == :carry && e[5]) }
      end
    end
  end
end

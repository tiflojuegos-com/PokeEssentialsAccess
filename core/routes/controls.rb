module PokeAccess
  module Routes
    # Routes through a puzzle's controls: when walls of the map's mechanic stand between the player and the goal, the
    # fewest presses that open the way, read off the controls' and the walls' pages (World::Mechanics::Links). The
    # route walks to the first control to press and is cut there; walks keep off plates and grid cells (keep_off), or
    # cross plates only while their presses leave the rest of the route open (open_past?).
    module Controls
      # The most presses a way may take, the most floor tiles read, and the most tiles the presses may walk in all.
      DEPTH = 6
      TILES = 8000
      VISITS = 40000

      # The way on foot to the first control to press on the way to goal, as [steps, gate]; nil when the walls leave
      # the way open already, when no presses within DEPTH open it, when the search is cut (presses, or the
      # route limit's deadline, past before the floor is read or while it is), or when the control cannot be walked to.
      def self.route(goal)
        mech = PokeAccess::World::Mechanics
        inst = mech.instance
        return nil unless inst && inst.spec[:obstacles] && !inst.controls.empty?
        deps = mech::Links.flags(inst)
        ctrls = mech.pieces(:control).select { |p| deps[mech::Links.key(inst.controls[p.ev.id])] }
        walls = mech::Links.walls(inst)
        return nil if ctrls.empty? || walls.empty?
        limits = PokeAccess::Pathfinder.limits
        return limits.cut! if limits.time_spent?
        floor = PokeAccess::World::Probe.lend_through(walls) { floor_from($game_player.x, $game_player.y) }
        return nil unless floor
        seq = presses(inst, ctrls, floor, goal)
        seq ? way_to(seq) : nil
      end

      # The tiles walkable from (x, y) with every wall set aside, each with the tiles one step leads to: key =>
      # [[key, x, y], ...] (nil past TILES); nil once the route limit's deadline passes, the stop counted.
      def self.floor_from(x, y)
        pf = PokeAccess::Pathfinder
        lim = pf.limits
        n = 0
        mode = pf.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        floor = { Routes.pkey(x, y) => nil }
        queue = [[x, y, pf.bridge_level]]
        until queue.empty? || floor.size > TILES
          return nil if lim.mode == :time && lim.spent?(n += 1)
          cx, cy, lvl = queue.shift
          out = []
          DIRS.each do |dir|
            t = Moves.step(cx, cy, lvl, dir, mode)
            next unless t
            k = Routes.pkey(t.x, t.y)
            out.push([k, t.x, t.y])
            next if floor.key?(k)
            floor[k] = nil
            queue.push([t.x, t.y, t.level])
          end
          floor[Routes.pkey(cx, cy)] = out
        end
        floor
      end

      # The floor tiles reachable from key start, the blocked ones never entered and the stops entered but never left
      # (a plate stepped onto is pressed), as key => true.
      def self.region(floor, start, blocked, stops = {})
        seen = { start => true }
        queue = [start]
        until queue.empty?
          k = queue.shift
          (floor[k] || []).each do |nk, _x, _y|
            next if seen[nk] || blocked[nk]
            seen[nk] = true
            queue.push(nk) unless stops[nk]
          end
        end
        seen
      end

      # The fewest presses that open the way to goal, in turn, as [piece, key of the tile it is pressed from] each; nil
      # when the way is open already, when none within DEPTH opens it, or past VISITS tiles or the deadline (a cut).
      def self.presses(inst, ctrls, floor, goal)
        links = PokeAccess::World::Mechanics::Links
        limits = PokeAccess::Pathfinder.limits
        aims = goal.tiles.map { |x, y| Routes.pkey(x, y) }
        stops = plates(inst)
        queue = [[{}, Routes.pkey($game_player.x, $game_player.y), []]]
        seen = {}
        visits = 0
        (DEPTH + 1).times do
          later = []
          queue.each do |over, pos, done|
            sig = [over.reject { |k, _v| k[0] == :self }.to_a.sort_by { |k, _v| k.inspect }, pos]
            next if seen[sig]
            seen[sig] = true
            return limits.cut! if visits > VISITS || limits.time_spent?
            reach = region(floor, pos, links.blocked(inst, over), stops)
            visits += reach.size
            return (done.empty? ? nil : done) if aims.any? { |k| reach[k] }
            ctrls.each do |p|
              at = press_key(p, reach)
              nxt = at && pressed(inst, p, over)
              later.push([nxt, at, done.dup.push([p, at])]) if nxt
            end
          end
          queue = later
        end
        nil
      end

      # The flags after pressing control p from over, as its live page sets them (a flag back at its value now dropped);
      # nil when the press changes none of them or no page fires on the player's press.
      def self.pressed(inst, p, over)
        mech = PokeAccess::World::Mechanics
        links = mech::Links
        pg = links.live_page(p.ev, over)
        return nil unless pg && (pg.trigger rescue 5) <= 2
        w = inst.controls[p.ev.id]
        k = links.key(w)
        now = mech::State.flag(w)
        vals = mech.written(pg, w).uniq
        nxt = over.dup
        unless vals.empty?
          on = over.key?(k) ? over[k] : now
          set_flag(nxt, k, vals.length == 1 && !vals[0].nil? ? vals[0] : !on, now)
        end
        mech.self_written(pg).each do |ch, v|
          set_flag(nxt, [:self, p.ev.id, ch], v, links.self_switch(p.ev.id, ch, {}))
        end
        nxt == over ? nil : nxt
      end

      # Sets flag k to v in flags, dropped where v is its value now.
      def self.set_flag(flags, k, v, now)
        if v == now then flags.delete(k) else flags[k] = v end
      end

      # The key of the tile a control is pressed from within reach: a plate's own, else a tile beside it; nil when
      # none is reached.
      def self.press_key(p, reach)
        ex = p.ev.x
        ey = p.ev.y
        own = Routes.pkey(ex, ey)
        return (reach[own] ? own : nil) if plate?(p.ev)
        DIRS.each do |dx, dy, _d|
          k = Routes.pkey(ex + dx, ey + dy)
          return k if reach[k]
        end
        nil
      end

      # True for a control fired by stepping onto it: a touch page that can be walked onto.
      def self.plate?(ev)
        r = PokeAccess::World::Events.record_of(ev)
        r ? [1, 2].include?(r.trigger) && (r.through || r.char.to_s.empty?) : false
      end

      # The plates of the controls some wall of the mechanic reads, as pkey => piece; none on a map without walls.
      def self.plates(inst)
        mech = PokeAccess::World::Mechanics
        return {} unless inst.spec[:obstacles] && inst.controls && !inst.controls.empty?
        deps = mech::Links.flags(inst)
        out = {}
        mech.pieces(:control).each do |p|
          next unless plate?(p.ev) && deps[mech::Links.key(inst.controls[p.ev.id])]
          out[Routes.pkey(p.ev.x, p.ev.y)] = p
        end
        out
      end

      # The tiles a walk on foot keeps off, as pkey => true: where a step would change the map's puzzle, the plates
      # some wall reads and a floor grid's cells while a letter is being formed on it.
      def self.keep_off
        mech = PokeAccess::World::Mechanics
        inst = mech.instance
        return {} unless inst
        off = {}
        plates(inst).each_key { |k| off[k] = true }
        spec = inst.spec
        spec[:cells].each { |x, y| off[Routes.pkey(x, y)] = true } if spec[:cells] && mech.truth(spec[:active])
        off
      end

      # Whether a route on foot stays open past the plates it crosses: each press in turn must leave the rest of the
      # route clear of the walls it puts up (Links.blocked).
      def self.open_past?(route)
        mech = PokeAccess::World::Mechanics
        inst = mech.instance
        on = inst ? plates(inst) : {}
        return true if on.empty?
        pf = PokeAccess::Pathfinder
        steps = Moves.trace($game_player.x, $game_player.y, pf.bridge_level, route.to_a, pf.replay_mode)
        keys = steps.map { |s| Routes.pkey(s.x, s.y) }
        over = {}
        keys[0...-1].each_with_index do |k, i|
          next unless on[k]
          over = pressed(inst, on[k], over) || over
          shut = mech::Links.blocked(inst, over)
          return false if keys[(i + 1)..-1].any? { |nk| shut[nk] }
        end
        true
      end

      # The way on foot to press the first control of seq (see presses), as [steps, gate], gate[:presses] naming them
      # all: one step short of a plate (off it when on it, gate[:back] the step back) or beside a lever; nil when none.
      def self.way_to(seq)
        p = seq[0][0]
        ev = p.ev
        step = plate?(ev)
        r = Planner.walk(ev.x, ev.y, step)
        return nil unless r.status == :found && r.route
        route = r.route
        under = step && route.empty?
        if under
          off = step_off(ev)
          return nil unless off
          route.push(off)
        elsif step
          route.pop
        end
        gate = { :kind => :control, :label => p.label, :ev => ev, :step => step, :x => ev.x, :y => ev.y,
                 :presses => seq.map { |q, _at| q.label } }
        gate[:back] = 10 - route[0] if under
        [route, gate]
      end

      # The way off the plate ev underfoot whose next step back lands on it again, as a direction, onto a tile that is
      # none of the puzzle's other controls when there is one; nil for none.
      def self.step_off(ev)
        pf = PokeAccess::Pathfinder
        mode = pf.moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
        ctrls = {}
        PokeAccess::World::Mechanics.pieces(:control).each { |p| ctrls[Routes.pkey(p.ev.x, p.ev.y)] = true }
        found = nil
        DIRS.each do |dir|
          t = Moves.step(ev.x, ev.y, pf.bridge_level, dir, mode)
          back = t && DIRS.find { |b| b[0] == -dir[0] && b[1] == -dir[1] }
          s = back && Moves.step(t.x, t.y, t.level, back, mode)
          next unless s && s.x == ev.x && s.y == ev.y
          return dir[2] unless ctrls[Routes.pkey(t.x, t.y)]
          found ||= dir[2]
        end
        found
      end
    end
  end
end

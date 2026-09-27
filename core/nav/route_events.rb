module PokeAccess
  # Pathfinder, the map's events: what stepping onto one (or bumping into it) does to a route, read through
  # EventPages and indexed per map:
  #   :carry    a Set Move Route on the player and nothing else (a hop over a hedge), landing them elsewhere;
  #   :warp     a transfer to another spot of this map;
  #   :exit     a transfer off the map: the end of any route, never a tile to cross on the way;
  #   :barrier  a cutscene that stops the player and shoves them back or aside;
  #   :ramp     a bridge ramp, which moves the player between the two levels of a bridge map;
  #   :run      presses that cross what the tiles call impassable, armed by arriving on the tile (a side staircase,
  #             see touch_source): [:run, direction, presses, dx, dy];
  #   :hold     ground the page lets the player onto only with the direction key held down (a cracked floor).
  # Action-button events have an index of their own (act_index), which only an assisted search reads.
  module Pathfinder
    # Event codes that make an event worth walking: a move route, a transfer, a script, a common event.
    TOUCHY = [209, 201, 355, 117]
    # How many touch events one carry may hand the player on to (an arrow floor is a chain of them).
    CARRY_HOPS = 32
    # Effects that leave a step onto their tile where it lands: the run it arms, ground to hold the key on.
    IN_PLACE = [:run, :hold]

    # Registers a reader of events a plugin gives a meaning of its own: it gets a live event and answers the
    # effect arriving on it has for every facing (a :run), or nil to leave the event to EventPages.
    def self.touch_source(&reader)
      @touch_sources ||= []
      @touch_sources.push(reader)
    end

    # Per-map index: pkey => [fires_on_arrival, { facing => effect }], built per map and vehicle state (event_index);
    # a search keeps the one it first asked for.
    def self.touch_index
      c = @context
      return c.touch if c && c.touch
      idx = event_index(:touch) { |mid| build_touch_index(mid) }
      c.touch = idx if c && c.vehicle
      idx
    end

    # Walks every player- and event-touch event of the map for the four facings, a page with a script condition once
    # per tile; a plugin reader's effect (touch_source) takes precedence.
    def self.build_touch_index(mid)
      idx = {}
      ($game_map.events.values rescue []).each do |ev|
        own = sourced_effect(ev)
        if own
          event_tiles(ev).each { |x, y| idx[pkey(x, y)] ||= [true, { 2 => own, 4 => own, 6 => own, 8 => own }] }
          next
        end
        trig = PokeAccess.ivar(ev, :@trigger)
        next unless trig == 1 || trig == 2
        list = PokeAccess.ivar(ev, :@list)
        next unless list.is_a?(Array) && list.any? { |c| TOUCHY.include?((c.code rescue 0)) }
        on = fires_on_arrival?(ev)
        shared = PokeAccess::EventPages.varies_by_tile?(list) ? nil : touch_effects(ev, on, mid, nil, nil)
        event_tiles(ev).each do |x, y|
          effects = shared || touch_effects(ev, on, mid, x, y)
          idx[pkey(x, y)] ||= [on, effects] unless effects.empty?
        end
      end
      idx
    end

    # The effect a registered plugin reader gives ev, or nil.
    def self.sourced_effect(ev)
      (@touch_sources || []).each do |src|
        e = (src.call(ev) rescue nil)
        return e if e
      end
      nil
    end

    # The four facings' effects of touching ev; with a tile, each is walked from where the player stands as it fires.
    # param act walk the page as one started with the action button, answering yes (see act_index)
    def self.touch_effects(ev, on, mid, x, y, act = false)
      effects = {}
      [2, 4, 6, 8].each do |d|
        dd = PokeAccess::DIR_DELTA[d]
        at = x.nil? ? nil : (on ? [x, y] : [x - dd[0], y - dd[1]])
        o = PokeAccess::EventPages.outcome(ev, d, at, act)
        e = act ? act_effect_of(o, mid) : touch_effect_of(o, d, on, mid)
        effects[d] = e if e
      end
      effects
    end

    # Per-map index of action-button events that take the player where they could not walk (a climb), walked answering
    # yes: pkey => [fires_on_arrival, { facing => effect }]; built only when an assisted search asks.
    def self.act_index
      event_index(:act) { |mid| build_act_index(mid) }
    end

    # Walks every action-button event of the map for the four facings, answering yes (see act_index).
    def self.build_act_index(mid)
      idx = {}
      ($game_map.events.values rescue []).each do |ev|
        next unless PokeAccess.ivar(ev, :@trigger) == 0
        list = PokeAccess.ivar(ev, :@list)
        next unless list.is_a?(Array) && list.any? { |c| TOUCHY.include?((c.code rescue 0)) }
        on = fires_on_arrival?(ev)
        event_tiles(ev).each do |x, y|
          effects = touch_effects(ev, on, mid, x, y, true)
          idx[pkey(x, y)] ||= [on, effects] unless effects.empty?
        end
      end
      idx
    end

    # What pressing the action button at an event does for a route: a carry with Through on (a climb) or a warp within
    # the map; nil for a page that fights, sets something that stays, or cannot be read.
    def self.act_effect_of(o, mid)
      return nil if o.nil? || o.unknown || o.changes || o.battle
      if o.transfer
        return (o.transfer[0] == mid && o.transfer[1]) ? [:warp, o.transfer[1], o.transfer[2]] : nil
      end
      (o.move && o.through) ? [:carry, o.move[0], o.move[1], o.jump, nil] : nil
    end

    # The effect of pressing the action button facing d at (x,y): on the event standing there when it fires
    # from its own tile (on), on the one in front otherwise.
    def self.act_at(x, y, d, on)
      t = act_index[pkey(x, y)]
      return nil if t.nil? || t[0] != on
      t[1][d]
    end

    # The tiles an event occupies: size(w,h) spreads it right and up from its own tile, as both the engine's
    # own sizes (v19+) and the gen-6 plugin read the name.
    def self.event_tiles(ev)
      tiles_of(ev.x, ev.y, PokeAccess.ivar(ev, :@width), PokeAccess.ivar(ev, :@height)) { ev.name }
    end

    # The tiles a w x h event standing on (x,y) covers, right and up from it; with no size kept (w or h not an
    # Integer), the size(w,h) in the name the block gives, else one tile.
    def self.tiles_of(x, y, w, h)
      unless w.is_a?(Integer) && h.is_a?(Integer)
        m = yield.to_s.match(/size\(\s*(\d+)\s*,\s*(\d+)\s*\)/i)
        w, h = m ? [m[1].to_i, m[2].to_i] : [1, 1]
      end
      out = []
      [w, 1].max.times { |i| [h, 1].max.times { |j| out.push([x + i, y - j]) } }
      out
    end

    # The engine's own answer to "does this event fire when the player stands on it": a sprite-less (or
    # through) event on a tile the map lets anyone stand on. Asked of the event where the engine has it.
    def self.fires_on_arrival?(ev)
      r = (ev.over_trigger? rescue nil)
      return r ? true : false unless r.nil?
      return false unless ev.character_name.to_s.empty? || (ev.through rescue false)
      ($game_map.passable?(ev.x, ev.y, 0) rescue false) ? true : false
    end

    # One facing's effect from a walk's outcome, or nil when it changes nothing for a route. A carry keeps its steps
    # when the page does not wait for the move, as each tile's own touch event then fires (arrow floors).
    def self.touch_effect_of(o, d, on, mid)
      return nil if o.nil?
      return (o.maybe_transfer ? [:exit] : nil) if o.unknown
      if o.transfer
        return [:exit] if o.transfer[0] != mid
        return o.transfer[1] ? [:warp, o.transfer[1], o.transfer[2]] : nil
      end
      if o.move
        return [:carry, o.move[0], o.move[1], o.jump, (o.waits ? nil : o.path)] unless o.talks || o.changes
        return barrier?(o, d, on) ? [:barrier] : nil
      end
      return [:ramp, o.bridge] if on && !o.bridge.nil?
      (on && o.held) ? [:hold] : nil
    end

    # A story block: the page talks, sets nothing lasting and moves the player back or aside; a wall from that side.
    def self.barrier?(o, d, on)
      return false unless on && o.talks && !o.changes
      dd = PokeAccess::DIR_DELTA[d]
      o.move[0] * dd[0] + o.move[1] * dd[1] <= 0
    end

    # The effect of the event at (x,y) for facing d, when it fires the way asked: arriving (on) or bumping.
    def self.touch_at(x, y, d, on)
      t = touch_index[pkey(x, y)]
      return nil if t.nil? || t[0] != on
      t[1][d]
    end

    # True when every move here is one plain tile, as the uniform-grid searches (JPS, HPA*) need: not surfing (a
    # waterfall carries), and no touch events or registered terrain that move the player; else plain A* searches.
    def self.uniform_grid?
      return false if ($PokemonGlobal.surfing rescue false)
      touch_index.empty? && !ruled_terrain?
    end

    # True when a bridge ramp is on this map: only then does the search carry the bridge level.
    def self.ramp_map?
      event_index(:ramps, false) { touch_index.any? { |_k, t| t[1].any? { |_d, e| e[0] == :ramp } } } ? true : false
    end

    # How many tiles of this map carry each kind of touch effect, for the diagnostic.
    def self.touch_census
      out = Hash.new(0)
      touch_index.each_value { |t| t[1].values.map { |e| e[0] }.uniq.each { |k| out[k] += 1 } }
      out
    end

    # The facings from which walking into the doorway at (x,y) leaves the map, or nil when it is no doorway
    # or leaves from every side.
    def self.door_facings(x, y)
      t = touch_index[pkey(x, y)]
      return nil if t.nil?
      fs = t[1].select { |_d, e| e[0] == :exit }.map { |d, _e| d }
      (fs.empty? || fs.length == 4) ? nil : fs.sort
    end

    # True if stepping onto (x,y) facing d leaves the map.
    def self.exit_step?(x, y, d)
      e = touch_at(x, y, d, true)
      !e.nil? && e[0] == :exit
    end

    # The tile (x, y) if the player could stand on it, else nil, which drops an event edge that would end there.
    def self.landing(x, y)
      return nil unless ($game_map.valid?(x, y) rescue false)
      [2, 4, 6, 8].any? { |dd| player_passable?(x, y, dd) } ? [x, y] : nil
    end

    # The bridge level a ramp leaves the player on, from the level they stepped on it at.
    def self.ramp_level(ramp, lvl)
      return (lvl.to_i > 0 ? 0 : 2) if ramp == :toggle
      ramp.to_i
    end

    # One move from (cx,cy) at bridge level lvl as the game plays it, the step and then the event it lands on or
    # bumps: a Step (presses of a run, the gate of an assisted step), or nil when it goes nowhere or off the map.
    # An event landing that fails the check falls back to the plain step.
    def self.move_target(cx, cy, dir, allow_ledge, edge_relax, lvl = 0)
      d = dir[2]
      run = run_from(cx, cy, d)
      return run_step(cx, cy, d, run, lvl) if run
      nbr = step_target(cx, cy, dir, allow_ledge, edge_relax)
      return bump_step(cx, cy, dir, lvl) if nbr.nil?
      return nil unless ($game_map.valid?(nbr[0], nbr[1]) rescue true)
      c = @context
      gate = (c && c.assisting) ? gate_at(nbr[0], nbr[1]) : nil
      e = touch_at(nbr[0], nbr[1], d, true)
      return Step.new(nbr[0], nbr[1], lvl, 1, gate) if e.nil? || IN_PLACE.include?(e[0])
      case e[0]
      when :exit, :barrier then nil
      when :ramp then Step.new(nbr[0], nbr[1], ramp_level(e[1], lvl), 1, gate)
      else
        l = (e[0] == :carry ? carry_landing(nbr[0], nbr[1], e) : landing(e[1], e[2])) || nbr
        Step.new(l[0], l[1], lvl, 1, gate)
      end
    end

    # A move into what stops a step: the bumped touch event's carry or warp, else in an assisted search what gets the
    # player past it.
    def self.bump_step(cx, cy, dir, lvl)
      e = touch_at(cx + dir[0], cy + dir[1], dir[2], false)
      l = case (e && e[0])
          when :carry then carry_landing(cx, cy, e)
          when :warp then landing(e[1], e[2])
          end
      return Step.new(l[0], l[1], lvl) if l
      c = @context
      (c && c.assisting) ? assisted_step(cx, cy, dir, lvl) : nil
    end

    # The run armed on (x,y) that sets off in direction d, or nil.
    def self.run_from(x, y, d)
      t = touch_index[pkey(x, y)]
      return nil if t.nil?
      r = t[1].values.find { |e| e[0] == :run }
      (r && r[1] == d) ? r : nil
    end

    # A run taken from (x,y): its first step is the engine's to allow, the rest cross whatever the tiles say,
    # and it lands where the run ends, a Step of the run's presses; nil when it cannot be taken.
    def self.run_step(x, y, d, run, lvl)
      return nil unless passable_at?(x, y, d)
      l = landing(x + run[3], y + run[4])
      l ? Step.new(l[0], l[1], lvl, run[2]) : nil
    end

    # Where a carry from (x,y) leaves the player: along its kept steps, a tile whose own touch event fires takes over;
    # nil for a chain that leaves the map, meets a story block or passes CARRY_HOPS.
    def self.carry_landing(x, y, e, hops = 0)
      return nil if hops > CARRY_HOPS
      (e[4] || []).each do |dx, dy, face|
        nxt = face ? touch_at(x + dx, y + dy, face, true) : nil
        next if nxt.nil? || nxt[0] == :ramp || IN_PLACE.include?(nxt[0])
        return nil if nxt[0] == :exit || nxt[0] == :barrier
        return nxt[0] == :warp ? landing(nxt[1], nxt[2]) : carry_landing(x + dx, y + dy, nxt, hops + 1)
      end
      landing(x + e[1], y + e[2])
    end

    # Replays a route from (x,y) at bridge level lvl with the search's own moves, one Step per press (mid Steps for
    # the tiles a run passes), stopping at the first that cannot be taken now.
    def self.trace(x, y, lvl, path)
      out = []
      searching do
        i = 0
        while i < path.length
          d = path[i]
          dir = DIR_OF[d]
          use_level(lvl)
          n = dir ? move_target(x, y, dir, true, false, lvl) : nil
          break if n.nil?
          presses = n.presses
          break unless path[i, presses].length == presses && path[i, presses].all? { |c| c == d }
          (1...presses).each { |k| out.push(Step.new(x + dir[0] * k, y + dir[1] * k, lvl, 1, nil, true)) }
          x = n.x; y = n.y; lvl = n.level
          out.push(n)
          i += presses
        end
      end
      out
    end

    # True if a route step from (x,y) in direction d can be taken now, from the player's bridge level: the
    # first press of a run counts as its start.
    def self.step_ok?(x, y, d)
      dir = DIR_OF[d]
      return false if dir.nil?
      searching do
        lvl = bridge_level
        use_level(lvl)
        !move_target(x, y, dir, true, false, lvl).nil?
      end
    end

    # True if the step from (x,y) in direction d is a jump the player makes by walking into it: a ledge, or
    # an event that hops them over what it stands on.
    def self.jump_step?(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      return false if dd.nil?
      nx = x + dd[0]; ny = y + dd[1]
      return true if (PokeAccess::Terrain.ledge_at?(nx, ny) rescue false)
      e = touch_at(nx, ny, d, false) || touch_at(nx, ny, d, true)
      !e.nil? && e[0] == :carry && e[3] ? true : false
    end
  end
end

module PokeAccess
  # The two guides toward the locator's selected target, sharing one route followed along its track (the states its
  # presses reach): the cane (Shift+I) chimes toward the next step, the step guide (Ctrl+I) says the route leg by leg.
  # The map frame's :nav stage runs it (tick); a map change turns both off in silence.
  module Guide
    # Manhattan tiles of the cane's distance scale: its volume is 1 - dist/FALLOFF of full, floored at 35% (reached at
    # about 15.6 tiles), and with the distance rhythm its chime's gap grows to twice at FALLOFF tiles.
    FALLOFF = 24.0
    # Least seconds between plans made because the target moved, between checks that the next step is open, and
    # between those of the safety window.
    RECHECK_SEC = 0.5
    # Least seconds between two chimes, one sounding at once where the way turns included.
    CHIME_GAP = 0.15
    # Presses ahead the safety window replays, every RECHECK_SEC.
    WINDOW = 16
    # Tiles walked, or seconds passed, before a target the search ran out on is searched for again.
    CUT_TILES = 8
    CUT_SEC = 1.0

    @cane = false
    @steps = false
    @at = 0
    @tiles = {}

    # True while the cane (:cane), the step guide (:steps) or either (nil) is on.
    def self.on?(kind = nil)
      return @cane if kind == :cane
      return @steps if kind == :steps
      @cane || @steps
    end

    # Shift+I (:cane) and Ctrl+I (:steps): turns that guide on toward the selected target, or off, and says so; turned
    # on, it says again what to do where the route stops short and the jump ahead.
    def self.toggle(kind)
      if on?(kind)
        switch(kind, false)
        return PokeAccess.speak(PokeAccess::I18n.t(kind == :cane ? :loc_guide_off : :loc_steps_off), true)
      end
      loc = PokeAccess::Locator
      loc.ensure_target
      t = loc.target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if t.nil?
      switch(kind, true)
      @hold_said = nil
      @jump_at = nil
      key = kind == :cane ? :loc_guide_to : :loc_steps_to
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => loc.target_name(t)), true)
    end

    # Turns a guide on in silence as a target is chosen, with auto_guide (:cane) or auto_steps (:steps) on.
    def self.arm(kind)
      c = PokeAccess::Config
      on = kind == :cane ? (c.auto_guide rescue false) : (c.auto_steps rescue false)
      switch(kind, true) if on && PokeAccess::Locator.target
    end

    # Sets a guide on or off: turned on, it chimes or says its leg at once, and says again that there is no way, planned
    # for afresh; turned off, its sounds stop.
    def self.switch(kind, on)
      if kind == :cane
        @cane = on
        @chime_at = nil
        stop_tone unless on
      else
        @steps = on
        @leg = nil
      end
      return unless on
      @said_none = nil
      @verdict = nil
      @checked_at = nil
    end

    # Turns both guides off and forgets the route, saying line unless nil (a key, or a line already made): cutting what
    # was said last while nothing was said since the guides' last frame (fresh?), else queued after it (a forced move's
    # notice in the same frame).
    def self.stop(line = nil)
      cut = fresh?
      @cane = false
      @steps = false
      stop_tone
      forget
      @seq = nil
      PokeAccess.speak(line.is_a?(Symbol) ? PokeAccess::I18n.t(line) : line, cut) if line
    end

    # True while nothing was said since the guides' last frame ended, or none has run since they were stopped.
    def self.fresh?
      @seq.nil? || @seq == PokeAccess.spoken_seq
    end

    # Forgets the route, the target it was for and what was said of them; the guides stay as they are.
    def self.forget
      @target_id = nil
      @goal = nil
      @plan = nil
      @track = nil
      @index = nil
      @tiles = {}
      @at = 0
      @left_key = nil
      @ahead_key = nil
      @state = nil
      @stamp = nil
      @stale = false
      @verdict = nil
      @planned_at = nil
      @blocked_at = nil
      @checked_at = nil
      @leg = nil
      @leg_seq = nil
      @chime_at = nil
      @chime_dir = nil
      @jump_at = nil
      @held_said = false
      @hold_said = nil
      @push_said = nil
      @kinds = nil
      @said_none = nil
      @none_cue_at = nil
    end

    # An event ended: a target with no way, or a route held at an obstacle, is planned for afresh, as what ended may
    # have opened the way (a felled tree) without a change on the route's tiles showing it.
    def self.event_ended
      return unless @plan && (@plan.route.nil? || @plan.kind == :assisted)
      @plan = nil
      @verdict = nil
    end

    # Marks the route for a check when an event's change touches one of its tiles (World::Events.on_change).
    def self.touched(tiles)
      return if @tiles.empty?
      @stale = true if tiles.any? { |x, y| @tiles[PokeAccess::Routes.pkey(x, y)] }
    end

    # One map frame, unless the engine carries the player on (Control.carried?) or its answers cannot be kept (partway
    # up a side stair): keeps the route current (follow), then arrives, holds where it stops short, says there is no
    # way, says a jump ahead, says the leg and chimes; what has been said by its end is the next frame's fresh? mark.
    def self.tick
      return unless @cane || @steps
      return unless PokeAccess::Control.free?
      return if PokeAccess::Control.carried? || !PokeAccess::World::Probe.stable?
      loc = PokeAccess::Locator
      return stop(:loc_target_lost) unless loc.target_valid?
      t = loc.target
      now = PokeAccess.clock
      PokeAccess::World::Events.sync
      follow(t, now)
      left = remaining
      return no_way(t) if left.nil?
      @said_none = nil
      @none_cue_at = nil
      return arrive(t) if left.empty?
      @hold_said = nil
      say_jump(left)
      say_leg(left) if @steps
      cane(left, t, now) if @cane
    ensure
      @seq = PokeAccess.spoken_seq
    end

    # Keeps the route current: plans again for a new target, the target moved (at most every RECHECK_SEC, at once when
    # the route runs out), the player off the track, a lapsed "no way" (recheck_none), and the rest failing to replay
    # after a tiles or events change (event_epoch), or every RECHECK_SEC through the next step or WINDOW presses.
    def self.follow(t, now)
      id = PokeAccess::Locator.identity(t)
      unless id == @target_id
        forget
        @target_id = id
      end
      st = player_state
      return plan(t, st, now) if @plan.nil?
      if st != @state
        @state = st
        return plan(t, st, now) unless locate(st)
      end
      return plan(t, st, now) if @goal != [t.x, t.y] && (due?(@planned_at, now) || (remaining || [0]).empty?)
      return recheck_none(t, st, now) unless @track
      epoch = PokeAccess::Pathfinder.event_epoch
      if @stale || @stamp != epoch
        @stale = false
        @stamp = epoch
        return plan(t, st, now) unless replays?(nil)
      end
      if due?(@blocked_at, now)
        @blocked_at = now
        return plan(t, st, now) unless replays?(1)
      end
      return unless due?(@checked_at, now)
      @checked_at = now
      plan(t, st, now) unless replays?(WINDOW)
    end

    # With no way, checked every RECHECK_SEC, the player standing still too: plans again once the "no way" told lapses
    # (verdict?), as a search that ran out does CUT_SEC on and any does with the regions made anew.
    def self.recheck_none(t, st, now)
      return unless due?(@checked_at, now)
      @checked_at = now
      plan(t, st, now) unless verdict?(st, now)
    end

    # True when at is unset or gap seconds have passed since it.
    def self.due?(at, now, gap = RECHECK_SEC)
      at.nil? || now - at >= gap
    end

    # Plans the way to t from the player's state st, unless a "no way" told before still holds there (verdict?).
    def self.plan(t, st, now)
      @planned_at = now
      @goal = [t.x, t.y]
      @state = st
      return if verdict?(st, now)
      made = PokeAccess::Locator.route_plan(t)
      @plan = made
      @stamp = PokeAccess::Pathfinder.event_epoch
      @stale = false
      @blocked_at = now
      @checked_at = now
      @at = 0
      @left_key = nil
      @ahead_key = nil
      if made.route
        track(made.route, st)
        @verdict = nil
      else
        @track = nil
        @index = nil
        @tiles = {}
        reg = PokeAccess::Routes::Regions.foot
        @verdict = [reg, reg.zone, st, now]
      end
    end

    # True while the last plan's "no way" holds at st: the regions unchanged and, for a :cut or :far one, within
    # CUT_TILES tiles and CUT_SEC seconds of where it was told, else the player still in the zone it was told from.
    def self.verdict?(st, now)
      v = @verdict
      return false if v.nil? || @plan.nil? || @plan.route
      reg = PokeAccess::Routes::Regions.foot
      return false unless v[0].equal?(reg)
      if @plan.kind == :cut || @plan.kind == :far
        return (st[0] - v[2][0]).abs + (st[1] - v[2][1]).abs < CUT_TILES && now - v[3] < CUT_SEC
      end
      !v[1].nil? && v[1] == reg.zone
    end

    # Replays route from st as the search made it (Moves.trace) into the track: the state after each press, indexed
    # (Pathfinder.skey) to the presses walked when the player is in it, and the tiles it passes, for touched; and what
    # each press does that cannot be undone (Moves.one_way), for the legs.
    def self.track(route, st)
      pf = PokeAccess::Pathfinder
      pts = PokeAccess::Routes::Moves.trace(st[0], st[1], st[2], route, pf.replay_mode)
      @track = pts
      @kinds = PokeAccess::Routes::Moves.one_way(st[0], st[1], st[2], route)
      @index = { pf.skey(st[0], st[1], st[2]) => 0 }
      @tiles = { PokeAccess::Routes.pkey(st[0], st[1]) => true }
      pts.each_with_index do |p, i|
        k = pf.skey(p.x, p.y, p.level)
        @index[k] = i + 1 unless @index.key?(k)
        @tiles[PokeAccess::Routes.pkey(p.x, p.y)] = true
      end
    end

    # Moves the cursor to the player's state on the track, forward or back; false off it. A state on it but for its
    # bridge level counts within two presses of the cursor: the level flips a frame late on a ramp.
    def self.locate(st)
      return false unless @index
      pf = PokeAccess::Pathfinder
      i = @index[pf.skey(st[0], st[1], st[2])]
      if i.nil?
        j = @index[pf.skey(st[0], st[1], 1 - st[2])]
        i = j if j && (j - @at).abs <= 2
      end
      return false if i.nil?
      @at = i
      true
    end

    # The player's state: [x, y, bridge level as 0 or 1].
    def self.player_state
      [$game_player.x, $game_player.y, PokeAccess::Pathfinder.bridge_level.to_i > 0 ? 1 : 0]
    end

    # The presses left of the route, nil without one.
    def self.remaining
      r = @plan && @plan.route
      return nil if r.nil?
      key = [r.object_id, @at]
      return @left if @left_key == key
      @left_key = key
      @left = r[@at..-1] || []
    end

    # The transfers left on the route, as the presses of the rest they land after.
    def self.warps_left
      @plan.route.warps.map { |w| w - @at }.select { |w| w >= 0 }
    end

    # True while the next n presses (all of them with nil) can still be taken from the player's state as the track has
    # them; where they stop short of a run they cut (a stair's presses, taken together), stretched over its press on.
    def self.replays?(n)
      left = remaining
      return true if left.nil? || left.empty?
      part = n ? left[0, n] : left
      st = @state
      moves = PokeAccess::Routes::Moves
      mode = PokeAccess::Pathfinder.replay_mode
      pts = moves.trace(st[0], st[1], st[2], part, mode)
      if pts.length < part.length && part.length < left.length
        m = part.length
        m += 1 while m < left.length && left[m] == left[m - 1]
        part = left[0, m]
        pts = moves.trace(st[0], st[1], st[2], part, mode)
      end
      return false unless pts.length == part.length
      pts.each_with_index do |p, k|
        q = @track[@at + k]
        return false unless q && q.x == p.x && q.y == p.y
      end
      true
    end

    # No way to the target: said once, unless just told (told?), and the cane chiming straight toward it once per tile
    # and direction.
    def self.no_way(t)
      stop_tone
      unless @said_none
        @said_none = true
        line = PokeAccess::Routes::Text.none(@plan && @plan.kind)
        PokeAccess.speak(line, false) unless told?(line)
      end
      none_cue(t) if @cane
    end

    # True when the line said last, since the guides' last frame, is a longer one ending with line: the selection's,
    # which closes with why there is no way.
    def self.told?(line)
      last = PokeAccess.last_spoken.to_s
      !fresh? && last.length > line.length && last.end_with?(line)
    end

    # The cane's chime straight toward a target with no way, once per tile and direction.
    def self.none_cue(t)
      d = straight_dir(t)
      here = [$game_player.x, $game_player.y, d]
      return if here == @none_cue_at
      @none_cue_at = here
      cue(d, distance(t))
    end

    # The end of the route: where it stops short (an obstacle, a shore) the guides stay on and say what to do once per
    # tile, a push kept up the same way only once; on a puzzle goal holding its piece they end with the piece's line
    # unless just told; else they end with Locator.arrived_line (a dive spot's action, a map edge's way off).
    def self.arrive(t)
      stop_tone
      line = hold_line
      if line.nil? && (inside = PokeAccess::Puzzles.carried_line(t))
        stop(nil)
        return if PokeAccess::Puzzles.track_told?(inside)
        return PokeAccess.speak(inside, false)
      end
      return stop(PokeAccess::Locator.arrived_line(t)) if line.nil?
      here = [$game_player.x, $game_player.y, line]
      return if @hold_said == here
      @hold_said = here
      PokeAccess.speak(line, false) unless pushing_on?(line)
    end

    # True where the player keeps moving the piece the way the line said for it tells: the same line again, the player
    # one tile on that way, as a push or a pull moves them (the piece's own line says how far it is meanwhile); notes
    # where it stands for the next one, until a leg is said.
    def self.pushing_on?(line)
      way = carry_way
      last = @push_said
      @push_said = way ? [line, $game_player.x, $game_player.y, way] : nil
      return false unless way && last && last[0] == line && last[3] == way
      dd = PokeAccess::DIR_DELTA[way]
      $game_player.x - last[1] == dd[0] && $game_player.y - last[2] == dd[1]
    end

    # The way the plan's gate moves its piece, the player following it: a push away from the player, a pull toward
    # them; nil for any other gate.
    def self.carry_way
      g = @plan && @plan.kind == :assisted ? @plan.gate : nil
      return nil if g.nil? || [:act, :dismount, :control].include?(g[:kind])
      return (g[:face] ? 10 - g[:face] : nil) if g[:kind] == :pull
      return nil unless g[:move].nil? && g[:item].nil? && g[:x] && g[:y]
      dx = g[:x] - $game_player.x
      dy = g[:y] - $game_player.y
      dx < 0 ? 4 : (dx > 0 ? 6 : (dy < 0 ? 8 : 2))
    end

    # What to say where the route stops short of the target (Routes::Text), or nil where it arrived.
    def self.hold_line
      return PokeAccess::Routes::Text.hold(@plan.gate, $game_player.x, $game_player.y) if @plan.kind == :assisted
      @plan.kind == :surf ? PokeAccess::Routes::Text.surf_hold(@plan.launch) : nil
    end

    # What the next press holds, from the player's state: [jump, held], a jump the player walks into (a ledge, a hop
    # over a hedge) and ground it lands on where the key must be kept down; kept while the state and the press stand.
    def self.ahead(left)
      key = [@state, left[0], @left_key]
      return @ahead if @ahead_key == key
      @ahead_key = key
      st = @state
      p = @track && @track[@at]
      moves = PokeAccess::Routes::Moves
      @ahead = [(moves.jump?(st[0], st[1], left[0]) rescue false), p ? (moves.held?(p.x, p.y) rescue false) : false]
    end

    # The jump the next press makes, once where it takes off, partway along a leg too: its sound toward it, and for the
    # cane alone its words ("jump down"), queued; the step guide says it as a leg of its own.
    def self.say_jump(left)
      unless ahead(left)[0]
        @jump_at = nil
        return
      end
      return if @jump_at == @state
      @jump_at = @state
      PokeAccess::Sound.cue(:jump, :dir => left[0])
      PokeAccess.speak(PokeAccess::Routes::Text.jump(left[0]), false) unless @steps
    end

    # Says the step guide's next leg (Routes::Text.legs) when new: another direction or kind, a longer count or, on the
    # same route, another run past a transfer; a count falling as the player walks stays silent. A new leg cuts the
    # last one while nothing else was said since.
    def self.say_leg(left)
      leg = PokeAccess::Routes::Text.legs(left, warps_left, @kinds && @kinds[@at..-1])[0]
      last = @leg
      @leg = [leg[0], leg[1], @at + leg[1], @plan, leg[3]]
      if last && last[0] == leg[0] && last[4] == leg[3] && leg[1] <= last[1]
        return if !last[3].equal?(@plan) || last[2] == @at + leg[1]
      end
      held = (@track[@at, leg[1]] || []).any? { |p| (PokeAccess::Routes::Moves.held?(p.x, p.y) rescue false) }
      PokeAccess.speak(PokeAccess::Routes::Text.leg(leg[0], leg[1], held, leg[2], leg[3]), leg_on_top?)
      @leg_seq = PokeAccess.spoken_seq
      @push_said = nil
    end

    # True if the last line said is the step guide's last leg, which a newer one may cut instead of queueing.
    def self.leg_on_top?
      !@leg_seq.nil? && @leg_seq == PokeAccess.spoken_seq
    end

    # The cane: a sustained tone toward the next step while it lands where the key must be held (with the positional
    # engine), else a chime toward it, on its rhythm (interval) or at once where the way turns, CHIME_GAP apart at
    # least.
    def self.cane(left, t, now)
      d = left[0]
      dist = distance(t)
      held = ahead(left)[1]
      say_held(held)
      return if hold_tone(held ? d : nil, dist)
      gap = @chime_at ? now - @chime_at : nil
      return unless gap.nil? || gap >= interval(dist) || (d != @chime_dir && gap >= CHIME_GAP)
      @chime_at = now
      @chime_dir = d
      cue(d, dist)
    end

    # The cane's "keep the key held down": once as its next step lands on such ground, again only after the route has
    # left it; the step guide's leg says it instead while it is on.
    def self.say_held(held)
      unless held
        @held_said = false
        return
      end
      return if @held_said || @steps
      @held_said = true
      PokeAccess.speak(PokeAccess::I18n.t(:loc_hold_key), false)
    end

    # Seconds between chimes, from guide_freq: by distance (guide_rhythm :distance) growing up to twice as long at
    # FALLOFF tiles or beyond, else the same at any distance.
    def self.interval(dist)
      base = PokeAccess.freq_to_seconds((PokeAccess::Config.guide_freq rescue 75))
      return base unless (PokeAccess::Config.guide_rhythm rescue :distance) == :distance
      f = dist.to_f / FALLOFF
      base * (1.0 + (f > 1.0 ? 1.0 : f))
    end

    # The Manhattan distance from the player to t.
    def self.distance(t)
      (t.x - $game_player.x).abs + (t.y - $game_player.y).abs
    end

    # The way straight toward t when it has no route: the longer axis, else the other, whichever can be stepped on, then
    # whichever is water to surf; 0 when neither.
    def self.straight_dir(t)
      px = $game_player.x; py = $game_player.y
      dx = t.x - px; dy = t.y - py
      horiz = dx == 0 ? 0 : (dx < 0 ? 4 : 6)
      vert = dy == 0 ? 0 : (dy < 0 ? 8 : 2)
      first, second = dx.abs >= dy.abs ? [horiz, vert] : [vert, horiz]
      probe = PokeAccess::World::Probe
      return first if first != 0 && probe.step?(px, py, first)
      return second if second != 0 && probe.step?(px, py, second)
      return first if first != 0 && water_ahead?(px, py, first)
      return second if second != 0 && water_ahead?(px, py, second)
      0
    end

    # True if the tile a step toward d from (px,py) is water to surf.
    def self.water_ahead?(px, py, d)
      dd = PokeAccess::DIR_DELTA[d]
      dd ? PokeAccess::World::Terrain.surfable?(px + dd[0], py + dd[1]) : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The chime toward d, louder as the target nears (Sound.cue places it).
    def self.cue(d, dist)
      return if d == 0
      vol = volume(dist)
      PokeAccess::Sound.cue(:guide, :dir => d, :vol => vol) if vol
    end

    # The guide's volume for a target dist tiles away, louder as it nears, or nil with its sound off.
    def self.volume(dist)
      v = PokeAccess::Config.event_volume
      return nil if v.nil? || v <= 0
      f = 1.0 - (dist.to_f / FALLOFF)
      f = 0.35 if f < 0.35
      f = 1.0 if f > 1.0
      (v * f).to_i
    end

    # The cane's held-key tone: a sustained chime toward d while the next step lands where the key must be held; true
    # while it plays, false (and stopped) with no d or no positional engine, leaving the chime to play.
    def self.hold_tone(d, dist)
      return stop_tone if d.nil?
      vol = volume(dist)
      played = !vol.nil? && (PokeAccess::Sound.hold(:guide_hold, :dir => d, :vol => vol) rescue false)
      return stop_tone unless played
      @tone = true
    end

    # Silences the held-key tone if it sounds; false, as no tone plays.
    def self.stop_tone
      (PokeAccess::Sound.release(:guide_hold) rescue nil) if @tone
      @tone = false
    end
  end
end

PokeAccess::World::Events.on_change { |tiles, _r, _how| PokeAccess::Guide.touched(tiles) }
# A map change or a load turns both guides off in silence.
PokeAccess::Caches.register(:guide) { PokeAccess::Guide.stop }

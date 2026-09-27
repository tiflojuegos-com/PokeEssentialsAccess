module PokeAccess
  # Locator part 4 of 4: the two guides toward the selected target, sharing one route. The cane (Shift+I) chimes
  # toward the next step; the step guide (Ctrl+I) speaks the route leg by leg. The route is searched once and
  # consumed as the player walks it.
  module Locator
    # RPG direction code => its localization key.
    DIR_NAMES = { 8 => :dir_up, 2 => :dir_down, 4 => :dir_left, 6 => :dir_right }

    # Manhattan distance (tiles) over which the guide chime fades to its quietest; nearer targets play louder.
    GUIDE_FALLOFF_TILES = 24.0
    # Minimum seconds between forced recomputes of a route whose next step is blocked (it briefly is, at corners).
    RECHECK_BLOCKED_SEC = 0.5
    # Flat chime per direction (one sound pre-panned) and its pitch before the guide tone: high ahead, low behind.
    CUE_FILES = { 4 => "pa_guide_l", 6 => "pa_guide_r" }
    CUE_PITCH = { 8 => 140, 2 => 70 }

    # Seconds between guide chimes, from guide_freq; it grows linearly with the Manhattan distance dist, up to twice
    # as long at GUIDE_FALLOFF_TILES or beyond (nil dist: no scaling).
    def self.guide_interval(dist = nil)
      base = PokeAccess.freq_to_seconds((PokeAccess::Config.guide_freq rescue 55))
      return base if dist.nil?
      f = dist.to_f / GUIDE_FALLOFF_TILES
      f = 1.0 if f > 1.0
      base * (1.0 + f)
    end

    # Seconds a cached route is trusted before it is replayed to check it still holds, from guide_refresh.
    def self.guide_refresh_seconds
      s = (PokeAccess::Config.guide_refresh rescue 4).to_i
      s <= 0 ? 4 : s
    end

    # Starts the guide chime toward the current target when auto-guide is enabled.
    def self.auto_guide_on
      return unless (PokeAccess::Config.auto_guide rescue false)
      return unless @target
      @guide = true
      @guide_time = nil
      @guide_from = nil
      @guide_noroute = false
    end

    # Silently starts the step guide toward the current target when auto_steps is on; the first leg follows.
    def self.auto_steps_on
      return unless (PokeAccess::Config.auto_steps rescue false)
      return unless @target
      @steps = true
      @steps_at = nil
      @steps_leg = nil
    end

    # Toggles the guide-cane mode (Shift+I): a panned chime points to the next step toward the target.
    def self.toggle_guide
      @guide = !@guide
      if @guide
        ensure_target
        unless @target
          @guide = false
          return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true)
        end
        @guide_time = nil
        @guide_from = nil
        @guide_noroute = nil
        PokeAccess.speak(PokeAccess::I18n.t(:loc_guide_to, :name => target_name(@target)), true)
      else
        stop_held_key_tone
        PokeAccess.speak(PokeAccess::I18n.t(:loc_guide_off), true)
      end
    end

    # Toggles the step guide (Ctrl+I): speaks the leg being walked, and each next one as the last is finished.
    def self.toggle_steps
      @steps = !@steps
      if @steps
        ensure_target
        unless @target
          @steps = false
          return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true)
        end
        @steps_at = nil
        @steps_leg = nil
        @guide_noroute = nil
        PokeAccess.speak(PokeAccess::I18n.t(:loc_steps_to, :name => target_name(@target)), true)
      else
        forget_steps
        PokeAccess.speak(PokeAccess::I18n.t(:loc_steps_off), true)
      end
    end

    # Drops what the step guide remembers about the leg it was on, so the next tick speaks afresh.
    def self.forget_steps
      @steps_at = nil
      @steps_leg = nil
    end

    # Ends both guides at once and says why (key): arrival and a lost target end the journey, said once.
    def self.stop_guides(key)
      @guide = false
      @steps = false
      @hold_said = nil
      @held_ahead = false
      stop_held_key_tone
      forget_steps
      PokeAccess.speak(PokeAccess::I18n.t(key), true)
    end

    # True while an ice slide carries the player: the engine's flag (sliding up to v20, ice_sliding in v21), or the
    # frame they step onto ice before it is set. Both guides hold meanwhile: the search packs the run as one step.
    def self.sliding?
      g = $PokemonGlobal
      return true if g && (((g.sliding rescue false) || (g.ice_sliding rescue false)) ? true : false)
      return false unless $game_player
      return false unless ($game_player.moving? rescue false)
      (PokeAccess::Terrain.ice_at?($game_player.x, $game_player.y) rescue false)
    rescue StandardError
      false
    end

    # The straight-line direction toward ev when no route is found: the dominant axis, else the other, whichever is
    # walkable, then whichever is surfable water; 0 when neither.
    def self.straight_dir(ev)
      px = $game_player.x; py = $game_player.y
      dx = ev.x - px; dy = ev.y - py
      horiz = dx == 0 ? 0 : (dx < 0 ? 4 : 6)
      vert  = dy == 0 ? 0 : (dy < 0 ? 8 : 2)
      primary, secondary = (dx.abs >= dy.abs) ? [horiz, vert] : [vert, horiz]
      return primary if primary != 0 && PokeAccess::Pathfinder.player_passable?(px, py, primary)
      return secondary if secondary != 0 && PokeAccess::Pathfinder.player_passable?(px, py, secondary)
      return primary if primary != 0 && surfable_ahead?(px, py, primary)
      return secondary if secondary != 0 && surfable_ahead?(px, py, secondary)
      0
    end

    # True if the tile one step in a direction is surfable water, so straight_dir tells water from a wall.
    def self.surfable_ahead?(px, py, dir)
      dd = PokeAccess::DIR_DELTA[dir]
      return false if dd.nil? || $game_map.nil?
      PokeAccess::Terrain.surfable_at?(px + dd[0], py + dd[1])
    rescue StandardError
      false
    end

    # Plays the guide chime for a step, louder as the target nears: left and right through the 3D engine when ready,
    # otherwise a flat cue, pitched high ahead and low behind (HRTF cannot place front and back on stereo headphones).
    def self.guide_cue(dir, dist)
      return if dir == 0
      vol = guide_volume(dist)
      return if vol.nil?
      return if (PokeAccess::Audio3D.guide(dir, vol) rescue false)
      PokeAccess::Spatial.cue(CUE_FILES[dir] || "pa_guide_c", vol, cue_pitch(dir))
    end

    # The guide's volume for a target dist tiles away, louder as it nears, or nil with its sound off.
    def self.guide_volume(dist)
      v = PokeAccess::Config.event_volume
      return nil if v.nil? || v <= 0
      factor = 1.0 - (dist.to_f / GUIDE_FALLOFF_TILES)
      factor = 0.35 if factor < 0.35
      factor = 1.0 if factor > 1.0
      (v * factor).to_i
    end

    # The guide's pitch toward dir through the guide tone.
    def self.cue_pitch(dir)
      ((CUE_PITCH[dir] || 100) * PokeAccess::Spatial.guide_tone_factor).round
    end

    # Runs each frame while the cane is on. Acts on its chime timer and, without chiming, on each new tile while
    # held-key ground lies ahead, so the held-key tone and hint come a step early.
    def self.guide_tick
      return unless @guide
      return if PokeAccess::Spatial.busy?
      return if sliding?
      now = PokeAccess.clock
      dist = ((@target.x - $game_player.x).abs + (@target.y - $game_player.y).abs rescue nil)
      here = [$game_player.x, $game_player.y]
      timed = @guide_time.nil? || (now - @guide_time) >= guide_interval(dist)
      return unless timed || (@held_ahead && @guide_tile != here)
      @guide_time = now if timed
      @guide_tile = here
      return stop_guides(:loc_target_lost) unless target_valid?
      refresh_guide_path
      path = @guide_path
      if path && !path.empty? && !PokeAccess::Pathfinder.step_ok?($game_player.x, $game_player.y, path[0])
        if @blocked_recheck_at.nil? || (now - @blocked_recheck_at) >= RECHECK_BLOCKED_SEC
          @blocked_recheck_at = now
          @guide_fresh = nil
          refresh_guide_path
          path = @guide_path
        end
      else
        @blocked_recheck_at = nil
      end
      return arrive if path && path.empty?
      if path.nil?
        stop_held_key_tone
        @held_ahead = false
        unless @guide_noroute
          @guide_noroute = true
          PokeAccess.speak(PokeAccess::Pathfinder.no_route_text(@guide_cut), false)
        end
        return noroute_cue(dist)
      end
      @guide_noroute = false
      @noroute_cue_at = nil
      announce_jump_step(path[0])
      held = held_leg?(path[0, 1])
      @held_ahead = held || held_leg?(path)
      announce_held_key(held)
      return if held_key_tone(held ? path[0] : nil, dist)
      guide_cue(path[0], dist) if timed
    end

    # Runs each map frame while the step guide is on; acts only when the player's or the target's tile changes.
    def self.steps_tick
      return unless @steps
      return if PokeAccess::Spatial.busy?
      return if sliding?
      return stop_guides(:loc_target_lost) unless target_valid?
      here = [$game_player.x, $game_player.y, @target.x, @target.y]
      return if @steps_at == here
      @steps_at = here
      refresh_guide_path
      path = @guide_path
      return arrive if path && path.empty?
      if path.nil?
        @steps_leg = nil
        unless @guide_noroute
          @guide_noroute = true
          PokeAccess.speak(PokeAccess::Pathfinder.no_route_text(@guide_cut), false)
        end
        return
      end
      @guide_noroute = false
      announce_leg(path)
    end

    # Speaks the leg at the head of the route when it is new: a new direction, or a longer count the same way (a
    # recomputed route); a count falling as the player walks stays silent. A new leg cuts the previous one while
    # nothing else has been said since, so wandering off the route leaves no backlog of old directions.
    def self.announce_leg(path)
      leg = PokeAccess::Pathfinder.legs(path)[0]
      return if leg.nil?
      last = @steps_leg
      @steps_leg = leg
      return if last && last[0] == leg[0] && leg[1] <= last[1]
      announce_jump_step(path[0], leg_on_top?)
      text = PokeAccess::Pathfinder.leg_text(leg)
      text = "#{text}, #{PokeAccess::I18n.t(:loc_hold_key)}" if held_leg?(path)
      PokeAccess.speak(text, leg_on_top?)
      @leg_seq = PokeAccess.spoken_seq
    end

    # True if the last line said is the step guide's previous leg, which a newer leg may cut instead of queueing.
    def self.leg_on_top?
      !@leg_seq.nil? && @leg_seq == PokeAccess.spoken_seq
    end

    # True if the route's first leg, replayed as the search made it, passes ground where the key must be held down.
    def self.held_leg?(path)
      pf = PokeAccess::Pathfinder
      leg = pf.legs(path)[0]
      return false if leg.nil?
      pts = pf.trace($game_player.x, $game_player.y, pf.bridge_level, path[0, leg[1]])
      pts.any? { |p| pf.held_key_at?(p.x, p.y) }
    rescue StandardError
      false
    end

    # The cane's "keep the key held down", said once as its next step ends on such ground (held) and again only
    # after the route has left it; with the step guide on, its leg says it instead.
    def self.announce_held_key(held)
      unless held
        @held_key_said = false
        return
      end
      return if @held_key_said || @steps
      @held_key_said = true
      PokeAccess.speak(PokeAccess::I18n.t(:loc_hold_key), false)
    end

    # The cane's held-key tone: a sustained chime toward dir while the next step is held-key ground; true if it
    # plays, false (and stopped) with no dir or no positional engine, leaving the chime to play.
    def self.held_key_tone(dir, dist)
      return stop_held_key_tone if dir.nil?
      vol = guide_volume(dist)
      played = !vol.nil? && (PokeAccess::Audio3D.guide_hold(dir, vol, cue_pitch(dir)) rescue false)
      return stop_held_key_tone unless played
      @held_tone = true
      true
    end

    # Silences the held-key tone if it sounds. Answers false: no tone plays.
    def self.stop_held_key_tone
      (PokeAccess::Audio3D.guide_hold(nil) rescue nil) if @held_tone
      @held_tone = false
      false
    end

    # The chime for an unreachable target: straight toward it, once per tile and direction.
    def self.noroute_cue(dist)
      dir = straight_dir(@target)
      here = [$game_player.x, $game_player.y, dir] rescue nil
      return if here && here == @noroute_cue_at
      @noroute_cue_at = here
      guide_cue(dir, dist)
    end

    # True if the next guide step is a jump the player walks into: a ledge, or an event that hops them over
    # what it stands on (a hedge, a gap).
    def self.jump_step?(d)
      return false if d.nil? || d == 0 || $game_map.nil? || $game_player.nil?
      PokeAccess::Pathfinder.jump_step?($game_player.x, $game_player.y, d)
    end

    # Drops the remembered jump tile and held-key hint and stops the held-key tone; runs on a map change.
    def self.forget_jump
      @jump_at = nil
      @held_key_said = false
      @held_ahead = false
      stop_held_key_tone
    end

    # Speaks "jump <dir>" when the next step is a jump, once per tile; cut interrupts what is being said.
    def self.announce_jump_step(d, cut = false)
      unless jump_step?(d)
        @jump_at = nil
        return
      end
      here = [$game_player.x, $game_player.y]
      return if @jump_at == here
      @jump_at = here
      PokeAccess.speak(PokeAccess::I18n.t(:loc_jump, :dir => PokeAccess::I18n.t(DIR_NAMES[d])), cut)
    rescue StandardError
      nil
    end

    # The end of the route: at a dive spot both guides end with what the action button does there; where the route
    # stops short (a shore, an obstacle) they stay on and say what to do, once per tile; else they end on arrival.
    def self.arrive
      stop_held_key_tone
      line = hold_line
      return stop_guides(dive_key(@target) || :loc_arrived) if line.nil?
      here = [$game_player.x, $game_player.y, line]
      return if @hold_said == here
      @hold_said = here
      PokeAccess.speak(line, false)
    end

    # What to say while holding where the route stops short of the target, or nil when it simply arrived.
    def self.hold_line
      return gate_line(@guide_gate) if @guide_gate
      return nil unless @guide_surf
      d = PokeAccess::Pathfinder.launch_dir(@target.x, @target.y)
      return PokeAccess::I18n.t(:loc_surf_here) if d.nil?
      PokeAccess::I18n.t(:loc_surf_toward, :dir => PokeAccess::I18n.t(DIR_NAMES[d]))
    end

    # What to do where an assisted route stops: act facing a way, dismount, push the obstacle, or use its field move
    # (or that it is needed, when the party surely cannot use it).
    def self.gate_line(g)
      t = PokeAccess::I18n
      case g[:kind]
      when :act then return t.t(:loc_act_here, :dir => t.t(DIR_NAMES[g[:face]]))
      when :dismount then return t.t(:loc_dismount_here, :dir => t.t(DIR_NAMES[g[:face]]))
      end
      dx = g[:x] - $game_player.x; dy = g[:y] - $game_player.y
      d = dx < 0 ? 4 : (dx > 0 ? 6 : (dy < 0 ? 8 : 2))
      return t.t(:loc_gate_push, :what => t.t(g[:label]), :dir => t.t(DIR_NAMES[d])) if g[:move].nil?
      key = PokeAccess::FieldMoves.can?(g[:move]) == false ? :loc_gate_need : :loc_gate_use
      t.t(key, :what => t.t(g[:label]), :dir => t.t(DIR_NAMES[d]), :move => PokeAccess::FieldMoves.name(g[:move]))
    end

    # The arrival line of a spot the player acts on (dive, surface), or nil for any other target.
    def self.dive_key(t)
      return nil unless t.is_a?(SurfaceTarget)
      { :surf_dive => :loc_dive_here, :surf_surface => :loc_surface_here }[t.key]
    end

    # Drops the walked steps of the cached route, replayed as the search made it; true if the player is still on it.
    # Partway along a run (a side staircase) nothing is dropped, as the rest replays only from where it started.
    def self.advance_guide_path(px, py)
      return false unless @guide_path && @guide_from
      return true if [px, py] == @guide_from
      pts = PokeAccess::Pathfinder.trace(@guide_from[0], @guide_from[1], @guide_level.to_i, @guide_path)
      i = pts.index { |p| p.x == px && p.y == py }
      return false if i.nil?
      return true if pts[i].mid
      @guide_path = @guide_path[(i + 1)..-1] || []
      @guide_from = [px, py]
      @guide_level = pts[i].level
      true
    end

    # Keeps the guide route current: reused while the player follows it, else searched again, then tried to a
    # field-move obstacle and to a shore to surf from; no route is remembered per player and target tile.
    def self.refresh_guide_path
      px = $game_player.x; py = $game_player.y
      tx = @target.x; ty = @target.y
      now = PokeAccess.clock
      return if @guide_path && @guide_target == [tx, ty] && follow_cached_path(px, py, now)
      return if @guide_path.nil? && @noroute_key == [px, py, tx, ty]
      pf = PokeAccess::Pathfinder
      return if @guide_path && pf.on_stair?
      @guide_from = [px, py]
      @guide_level = pf.bridge_level
      @guide_target = [tx, ty]
      @guide_fresh = now
      @guide_gate = nil
      @guide_surf = false
      cuts = pf.cuts
      @guide_path = dive_key(@target) ? pf.find_path_onto(tx, ty) : pf.find_path(tx, ty)
      if @guide_path.nil?
        g = pf.gated_path(tx, ty)
        if g
          @guide_path, @guide_gate = g
        else
          @guide_path = pf.surf_launch(tx, ty)
          @guide_surf = !@guide_path.nil?
        end
      end
      @noroute_key = @guide_path.nil? ? [px, py, tx, ty] : nil
      @guide_cut = @guide_path.nil? && pf.cuts != cuts
      @guide_end = route_end(px, py, @guide_path)
      @guide_epoch = pf.event_epoch
    end

    # The tile a route from (px,py) leaves the player on, replayed as the search made it, or nil for none.
    def self.route_end(px, py, path)
      return nil if path.nil?
      pf = PokeAccess::Pathfinder
      pts = pf.trace(px, py, pf.bridge_level, path)
      pts.empty? ? [px, py] : pts.last.tile
    end

    # Drops the remembered "no route" and any route held at an obstacle so the next refresh searches again; runs
    # when an event ends, which clearing an obstacle does.
    def self.forget_noroute
      @noroute_key = nil
      @guide_path = nil if @guide_gate
    end

    # True while the player is on the cached route and it holds: trusted within guide_refresh_seconds unless the
    # event epoch changed (a cracked floor gave way), otherwise replayed to check it.
    def self.follow_cached_path(px, py, now)
      return false unless [px, py] == @guide_from || advance_guide_path(px, py)
      epoch = PokeAccess::Pathfinder.event_epoch
      return true if @guide_fresh && (now - @guide_fresh) < guide_refresh_seconds && @guide_epoch == epoch
      @guide_fresh = now
      @guide_epoch = epoch
      path_walkable?(px, py, @guide_path, @guide_end)
    end

    # True if every step of a cached route can still be taken from (px, py), replayed as the search made it, and it
    # still ends on goal when one is given.
    def self.path_walkable?(px, py, path, goal = nil)
      return true if path.nil? || path.empty?
      pf = PokeAccess::Pathfinder
      pts = pf.trace(px, py, pf.bridge_level, path)
      pts.length == path.length && (goal.nil? || pts.last.tile == goal)
    end
  end
end
PokeAccess::Caches.register(:guide_jump) { PokeAccess::Locator.forget_jump }

module PokeAccess
  # Locator part 4 of 4: the guide cane. A panned/pitched chime points to the next step toward the
  # selected target. The route is computed once by A* and then CONSUMED as the player walks it
  # (recomputing only on deviation, target change or a freshness check), which keeps it cheap on big maps.
  module Locator
    # rpg direction code => its localization key (for the "jump <dir>" cue).
    DIR_NAMES = { 8 => :dir_up, 2 => :dir_down, 4 => :dir_left, 6 => :dir_right }

    # Manhattan distance (tiles) over which the guide chime fades to its quietest; nearer targets play louder.
    GUIDE_FALLOFF_TILES = 24.0
    # Minimum seconds between forced "next step blocked" recomputes, so walking corners (where path[0] briefly
    # faces a wall mid-step) does not trigger a per-tick double A*. The normal per-tick refresh is unaffected.
    RECHECK_BLOCKED_SEC = 0.5

    # Seconds between guide chimes, from guide_freq (higher = more frequent), paced in real time. The chime
    # spaces out with distance so a far target does not "gallop": at the target tile it is the configured
    # interval, growing linearly up to 2x at GUIDE_FALLOFF_TILES (24) or beyond. Close stays responsive,
    # far stays calm but still audible. param dist manhattan distance to the target (nil = no scaling)
    def self.guide_interval(dist = nil)
      base = PokeAccess.freq_to_seconds((PokeAccess::Config.guide_freq rescue 55))
      return base if dist.nil?
      f = dist.to_f / GUIDE_FALLOFF_TILES
      f = 1.0 if f > 1.0
      base * (1.0 + f)
    end

    # Seconds before a forced fresh A* (bounds staleness if the map changes mid-route), from guide_refresh.
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
        PokeAccess.speak(PokeAccess::I18n.t(:loc_guide_off), true)
      end
    end

    # The straight-line direction toward the target, used only when A* cannot route. Prefers a WALKABLE
    # next tile so the chime leads around a wall, not into it; keeps the dominant direction only if
    # neither axis is walkable yet (e.g. deep water before surfing).
    def self.straight_dir(ev)
      px = $game_player.x; py = $game_player.y
      dx = ev.x - px; dy = ev.y - py
      horiz = dx == 0 ? 0 : (dx < 0 ? 4 : 6)
      vert  = dy == 0 ? 0 : (dy < 0 ? 8 : 2)
      primary, secondary = (dx.abs >= dy.abs) ? [horiz, vert] : [vert, horiz]
      return primary if primary != 0 && ($game_player.passable?(px, py, primary) rescue false)
      return secondary if secondary != 0 && ($game_player.passable?(px, py, secondary) rescue false)
      return primary if primary != 0 && surfable_ahead?(px, py, primary)
      return secondary if secondary != 0 && surfable_ahead?(px, py, secondary)
      0
    end

    # True if the tile one step in a direction is surfable water, so straight_dir tells water from a wall.
    def self.surfable_ahead?(px, py, dir)
      return false if dir == 0 || $game_map.nil?
      nx, ny = step_tile(px, py, dir)
      PokeAccess::Terrain.surfable_at?(nx, ny)
    rescue StandardError
      false
    end

    # Plays the panned/pitched guide chime for a step, louder as the target nears. Left/right go through
    # the 3D engine; up/down (front/back, which HRTF cannot place) use a pitched flat cue (high=up, low=down).
    def self.guide_cue(dir, dist)
      return if dir == 0
      v = PokeAccess::Config.event_volume
      return if v.nil? || v <= 0
      factor = 1.0 - (dist.to_f / GUIDE_FALLOFF_TILES)
      factor = 0.35 if factor < 0.35
      factor = 1.0 if factor > 1.0
      vol = (v * factor).to_i
      if (dir == 4 || dir == 6) && (PokeAccess::Audio3D.guide(dir, vol) rescue false)
        return
      end
      case dir
      when 4 then PokeAccess::Spatial.cue("pa_guide_l", vol)
      when 6 then PokeAccess::Spatial.cue("pa_guide_r", vol)
      when 8 then PokeAccess::Spatial.cue("pa_guide_c", vol, 140)
      else        PokeAccess::Spatial.cue("pa_guide_c", vol, 70)
      end
    end

    # Runs each frame while guiding: chimes toward the target on a timer (the path refresh only runs on tick).
    def self.guide_tick
      return unless @guide
      return if PokeAccess::Spatial.busy?
      now = PokeAccess.clock
      dist = ((@target.x - $game_player.x).abs + (@target.y - $game_player.y).abs rescue nil)
      return if @guide_time && (now - @guide_time) < guide_interval(dist)
      @guide_time = now
      unless target_valid?
        @guide = false
        return PokeAccess.speak(PokeAccess::I18n.t(:loc_target_lost), true)
      end
      refresh_guide_path
      path = @guide_path
      if path && !path.empty? && !ledge_step?(path[0]) && !($game_player.passable?($game_player.x, $game_player.y, path[0]) rescue true)
        if @blocked_recheck_at.nil? || (now - @blocked_recheck_at) >= RECHECK_BLOCKED_SEC
          @blocked_recheck_at = now
          @guide_fresh = nil
          refresh_guide_path
          path = @guide_path
        end
      else
        @blocked_recheck_at = nil
      end
      if path && path.empty?
        @guide = false
        return PokeAccess.speak(PokeAccess::I18n.t(@guide_surf ? :loc_surf_here : :loc_arrived), true)
      end
      if path.nil?
        unless @guide_noroute
          @guide_noroute = true
          PokeAccess.speak(PokeAccess::I18n.t(:loc_no_route), false)
        end
        return noroute_cue(dist)
      end
      @guide_noroute = false
      @noroute_cue_at = nil
      announce_jump_step(path[0])
      guide_cue(path[0], dist)
    end

    # The cue for an unreachable target: still points straight at it (so the guide keeps nudging the player
    # closer even when A* finds no route), but does NOT re-chime while standing on the same tile facing the
    # same way -- otherwise it gallops identically in place. A move (new tile or new straight direction)
    # speaks again. param dist manhattan distance to the target
    def self.noroute_cue(dist)
      dir = straight_dir(@target)
      here = [$game_player.x, $game_player.y, dir] rescue nil
      return if here && here == @noroute_cue_at
      @noroute_cue_at = here
      guide_cue(dir, dist)
    end

    # True if the next guide step is a ledge hop (the faced tile is a ledge), not a normal walk.
    def self.ledge_step?(d)
      return false if d.nil? || d == 0 || $game_map.nil? || $game_player.nil?
      fx, fy = step_tile($game_player.x, $game_player.y, d)
      PokeAccess::Terrain.ledge_at?(fx, fy)
    rescue StandardError
      false
    end

    # Drops the remembered jump tile (map change or guide shutdown), so a fresh map cannot inherit it.
    def self.forget_jump
      @jump_at = nil
    end

    # Speaks "jump <dir>" once when the next step is a ledge hop, so the player jumps it instead of
    # walking into it. Tracks the tile so it is not repeated on every chime.
    def self.announce_jump_step(d)
      unless ledge_step?(d)
        @jump_at = nil
        return
      end
      here = [$game_player.x, $game_player.y]
      return if @jump_at == here
      @jump_at = here
      PokeAccess.speak(PokeAccess::I18n.t(:loc_jump, :dir => PokeAccess::I18n.t(DIR_NAMES[d])), false)
    rescue StandardError
      nil
    end

    # The tile reached by stepping one tile in an rpg maker direction from (x, y).
    def self.step_tile(x, y, dir)
      case dir
      when 8 then [x, y - 1]
      when 2 then [x, y + 1]
      when 4 then [x - 1, y]
      when 6 then [x + 1, y]
      else [x, y]
      end
    end

    # The tile a route step actually LANDS on: one tile normally, but TWO when the step crosses a ledge --
    # the pathfinder packs a ledge hop as a single direction whose landing is beyond the ledge tile
    # (ledge_jump's two-tile model), so a consumer advancing one tile per step desynchronises after every
    # hop and re-runs the full A* (the cached guide route was useless on ledge routes).
    def self.step_span(x, y, dir)
      fx, fy = step_tile(x, y, dir)
      if (PokeAccess::Terrain.ledge_at?(fx, fy) rescue false)
        [x + 2 * (fx - x), y + 2 * (fy - y)]
      else
        [fx, fy]
      end
    end

    # Advances the cached path to the player's tile by dropping walked steps. True if still on the path.
    def self.advance_guide_path(px, py)
      return false unless @guide_path && @guide_from
      x, y = @guide_from
      consumed = 0
      @guide_path.each do |d|
        break if [x, y] == [px, py]
        x, y = step_span(x, y, d)
        consumed += 1
      end
      return false unless [x, y] == [px, py]
      @guide_path = @guide_path[consumed..-1] || []
      @guide_from = [px, py]
      true
    end

    # Keeps the guide path current without re-running A* every tick: computed once and consumed as the
    # player follows it, recomputing only on deviation, target move, or freshness lapse. An UNREACHABLE
    # result (find_path nil) is remembered by [player_xy, target_xy] so the costly A* is not re-run every
    # tick while the player stands at the same spot for the same out-of-reach target -- the straight-line
    # no-route cue still sounds. The memo clears the moment the player moves, the target changes, or
    # something invalidates the pathfinder caches (a switch that opens a path ends an event -> forget_noroute).
    def self.refresh_guide_path
      px = $game_player.x; py = $game_player.y
      tx = @target.x; ty = @target.y
      now = PokeAccess.clock
      return if @guide_path && @guide_target == [tx, ty] && follow_cached_path(px, py, now)
      return if @guide_path.nil? && @noroute_key == [px, py, tx, ty]
      @guide_from = [px, py]
      @guide_target = [tx, ty]
      @guide_fresh = now
      @guide_path = PokeAccess::Pathfinder.find_path(tx, ty)
      if @guide_path.nil?
        sp = (PokeAccess::Pathfinder.surf_launch(tx, ty) rescue nil)
        @guide_surf = !sp.nil?
        @guide_path = sp
        @noroute_key = @guide_path.nil? ? [px, py, tx, ty] : nil
      else
        @guide_surf = false
        @noroute_key = nil
      end
    end

    # Drops the remembered "no route" result so the next refresh re-runs A* (e.g. after a switch opens a
    # path). Called from the same event-end hook that invalidates the pathfinder caches.
    def self.forget_noroute; @noroute_key = nil; end

    # Tries to reuse the cached route. True while the player is still on it and it is valid; inside the
    # freshness window that is trusted, past it the route is re-checked with a cheap linear walkability
    # scan (not a full A*), so guiding to a far target never pays for a periodic full search.
    def self.follow_cached_path(px, py, now)
      return false unless [px, py] == @guide_from || advance_guide_path(px, py)
      return true if @guide_fresh && (now - @guide_fresh) < guide_refresh_seconds
      @guide_fresh = now
      path_walkable?(px, py, @guide_path)
    end

    # True if every step of a cached route is still walkable from a start tile (a ledge hop counts as
    # walkable and advances to its LANDING, so the steps after a hop validate from the right tile),
    # scanned linearly with no node expansion -- far cheaper than rerunning A*.
    def self.path_walkable?(px, py, path)
      return true if path.nil? || path.empty?
      x = px; y = py
      path.each do |d|
        fx, fy = step_tile(x, y, d)
        if (PokeAccess::Terrain.ledge_at?(fx, fy) rescue false)
          x = x + 2 * (fx - x); y = y + 2 * (fy - y)
          next
        end
        return false unless ($game_player.passable?(x, y, d) rescue true)
        x = fx; y = fy
      end
      true
    end
  end
end
PokeAccess::Caches.register(:guide_jump) { PokeAccess::Guide.forget_jump }

module PokeAccess
  # Spatial navigation audio, kept sparse: a footstep on movement (water variant while surfing) and a
  # wall cue when pushing into an impassable tile, panned to the wall's side. Target location is the
  # guide cane's job (see Locator). Pre-panned files give the direction since old mkxp-z cannot pan a
  # mono sound at playback.
  module Spatial
    DIR = PokeAccess::Paths::SOUNDS
    @flip = false
    @last_x = nil
    @last_y = nil
    @was_blocked = false
    @bump_time = nil
    @radar_key = nil
    @radar_pos = nil
    @surf_here = nil
    @surf_front = nil
    @surf_pos = nil
    @lens_key = nil

    # Drops everything tied to the map the player just left: every ivar here is an "already said this" memo
    # keyed on coordinates or on a terrain label, neither of which survives a map change. Its twin Audio3D
    # puts the map id inside its keys instead, which this module cannot do, because @surf_here holds a
    # LABEL and not a position and would match itself through a door onto water.
    def self.reset_map_state
      @radar_key = nil; @radar_pos = nil
      @surf_here = nil; @surf_front = nil; @surf_pos = nil
      @lens_key = nil
      @last_x = nil; @last_y = nil
      @was_blocked = false
    rescue StandardError
      nil
    end

    # Plays a cue file at a 0-100 volume (skips silence), with an optional playback pitch.
    def self.cue(name, volume, pitch = 100)
      return if volume.nil? || volume <= 0
      Audio.se_play("#{DIR}/#{name}", volume, pitch) rescue nil
    end

    # The rate factor a family's tone applies to a flat cue, held inside what mkxp accepts for an SE (50 to
    # 150): the factor is reduced until the highest pitch the cue uses fits under 150 and the lowest stays
    # over 50, so a pair like the guide's 140 ahead and 70 behind keeps its ratio, and its meaning, at any
    # tone. low and high are that cue's extreme base pitches.
    def self.tone_factor(key, low = 100, high = 100)
      f = PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) / 100.0
      f = 150.0 / high if high * f > 150
      f = 50.0 / low if low * f < 50
      f
    rescue StandardError
      1.0
    end

    # The guide family's tone factor, one for every path. The cane's ahead/behind code (140 and 70) lives on
    # the flat channel by design, because HRTF cannot place front and back on plain stereo headphones; so
    # the whole family, the engine's left and right included, moves by the factor that keeps that pair
    # inside 50-150. The guide tone therefore goes down almost half an octave and up about a semitone, and
    # its four directions never disagree.
    def self.guide_tone_factor
      tone_factor(:guide_tone, 70, 140)
    end

    # The named NON-positional earcons: symbol => [file, default pitch]. One vocabulary so a sound keeps a
    # single meaning across readers -- the 3D/panned cues (walls, guide cane, puzzle tones) already mean
    # "wall", "npc" or "control" and stay out of this table on purpose: reusing one here would read as the
    # sonar firing in the middle of a minigame. pa_mg_tick is a short 60 ms percussive blip made to repeat
    # every frame without smearing when pitch-shifted.
    EARCONS = {
      :minigame_tick => ["pa_mg_tick", 100],
      :radar_blip    => ["pa_guide_c", 150]
    }

    # Plays a named earcon at a 0-100 volume; pitch overrides the table's default.
    def self.earcon(name, volume, pitch = nil)
      e = EARCONS[name]
      return unless e
      cue(e[0], volume, pitch || e[1])
    end

    # The pitch range a gauge sweeps: it starts at LOW and spans SPAN, reaching 150, the most the flat SE
    # channel plays (mkxp pins anything above it, which is what let an older top of 180 flatten the last
    # third of every approach). Low enough to read as "far" and high enough to read as "now" without
    # leaving the range where the 60 ms tick still sounds like the same sound. A base and a span rather
    # than a low and a high, so the mapping below needs no subtraction: the MTS guard cannot prove a
    # constant minus a constant is scalar.
    GAUGE_LOW = 80
    GAUGE_SPAN = 70

    # A cue whose PITCH carries a magnitude: 0.0 at the low end, 1.0 at the high end. The shared answer to
    # "how close am I to the good moment", which every timing minigame needs, defined here alongside the
    # vocabulary it belongs to.
    #
    # A fraction outside 0..1 is clamped rather than refused: callers derive it from live game state that
    # can overshoot by a frame, and going quiet at the moment the player most needs the cue is the worst
    # failure this sound has.
    def self.gauge(fraction, volume = 60, name = :minigame_tick)
      f = fraction.to_f
      f = 0.0 if f < 0.0
      f = 1.0 if f > 1.0
      earcon(name, volume, GAUGE_LOW + (f * GAUGE_SPAN).to_i)
    rescue StandardError
      nil
    end

    # True while the player is NOT under free control (message, menu, battle, selection/picture screen, a
    # forced move route, or a blocking event), so audio/cues/guide fall silent. Gates on the active scene
    # (some fangame menus don't set in_menu) plus a registered reader for Scene_Map-overlay menus. The
    # locator KEYS use keys_locked? instead, which ignores the interpreter so the npc list stays usable
    # during a walkable cutscene.
    def self.busy?
      !busy_reason.nil?
    end

    # WHICH condition is holding the player out of free control, or nil when none is. Same order and same
    # tests as busy? (which is just this, as a boolean) -- split out so a soundscape that keeps cutting out
    # can name its cause in the diagnostic instead of leaving "busy" as an opaque true.
    def self.busy_reason
      return :other_scene if (defined?(::Scene_Map) && $scene && !$scene.is_a?(::Scene_Map))
      return :battle if (PokeAccess::Battle.in_battle? rescue false)
      return :remin_menu if ((defined?(PokeAccess::ReminMenu) && PokeAccess::ReminMenu.active?) rescue false)
      return :appearance if (PokeAccess::Appearance.selecting? rescue false)
      return :picture_menu if (PokeAccess::PictureCues.menu_showing? rescue false)
      if $game_temp
        return :message if $game_temp.message_window_showing
        return :in_menu if ($game_temp.in_menu rescue false)
        return :in_battle if ($game_temp.in_battle rescue false)
      end
      return :move_route if ($game_player && $game_player.move_route_forcing rescue false)
      return :interpreter if ($game_system && $game_system.map_interpreter && $game_system.map_interpreter.running? rescue false)
      nil
    rescue StandardError
      nil
    end

    # True only while another screen genuinely owns the arrows/action keys (character selection, a picture
    # menu, an open menu or a battle). Unlike busy? this is NOT true for a plain message or a running
    # interpreter, so the locator keys keep working during a parallel-event cutscene the player can walk through.
    def self.keys_locked?
      return true if (PokeAccess::Appearance.selecting? rescue false)
      return true if (PokeAccess::PictureCues.menu_showing? rescue false)
      if $game_temp
        return true if ($game_temp.in_menu rescue false)
        return true if ($game_temp.in_battle rescue false)
      end
      false
    rescue StandardError
      false
    end

    # Runs once per map frame: footstep on movement, panned wall feedback, radar, surface cues and the
    # hidden-area notice.
    def self.tick
      return unless $game_map && $game_player
      return if busy?
      footstep
      wall_cue
      radar
      surfaces
      announce_lens_tile
    end

    # The tile directly in front of the player, by facing direction.
    def self.front_tile
      x = $game_player.x; y = $game_player.y
      case $game_player.direction
      when 2 then [x, y + 1]
      when 4 then [x - 1, y]
      when 6 then [x + 1, y]
      when 8 then [x, y - 1]
      else [x, y]
      end
    end

    # The map event occupying a tile, if any.
    def self.event_at(x, y)
      return nil unless $game_map
      $game_map.events.values.detect { |ev| ev.x == x && ev.y == y }
    end

    # Optional proximity radar: a discreet tick when an interactable event lines up directly in front of
    # the player, edge-triggered so it does not repeat while you keep facing it.
    def self.radar
      unless PokeAccess::Config.proximity_radar && (PokeAccess::Audio3D.nav_full? rescue true)
        @radar_key = nil; @radar_pos = nil
        return
      end
      pos = [$game_player.x, $game_player.y, $game_player.direction]
      return if pos == @radar_pos
      @radar_pos = pos
      fx, fy = front_tile
      ev = event_at(fx, fy)
      hit = ev && (PokeAccess::Locator.interactable?(ev) rescue false)
      key = hit ? [fx, fy] : nil
      if key && key != @radar_key
        v = PokeAccess::Config.event_volume
        pitch = [(EARCONS[:radar_blip][1] * guide_tone_factor).round, 150].min
        earcon(:radar_blip, (v * 0.45).to_i, pitch) if v && v > 0
      end
      @radar_key = key
    end

    # Optional surface awareness: announces the terrain under the player when it changes and flags
    # surfable water directly ahead. Resolved through Terrain, so it works on gen-6 and modern tags.
    def self.surfaces
      return unless PokeAccess::Config.surface_cues
      pos = [$game_player.x, $game_player.y, $game_player.direction]
      return if pos == @surf_pos
      @surf_pos = pos
      here = PokeAccess::Terrain.label($game_player.x, $game_player.y)
      if here != @surf_here
        @surf_here = here
        PokeAccess.speak(PokeAccess::I18n.t(here), false) if here
      end
      fx, fy = front_tile
      ahead = PokeAccess::Terrain.surfable_at?(fx, fy)
      surfing = ($PokemonGlobal && $PokemonGlobal.surfing rescue false)
      if ahead && !surfing && @surf_front != [fx, fy]
        @surf_front = [fx, fy]
        PokeAccess.speak(PokeAccess::I18n.t(:surf_ahead), true)
      end
      @surf_front = nil if !ahead || surfing
    end

    # Announces a generic "hidden area" cue when the player steps onto a tile holding a Lens-of-Truth (#EOT)
    # event, so a place invisible without the lens is still noticeable on foot. Deduped per tile, and worded
    # generically because the revealing item is named differently per game. Driven from tick and not from
    # the terrain cues, which are off by default and whose help line promises terrain.
    def self.announce_lens_tile
      px = $game_player.x; py = $game_player.y
      ev = event_at(px, py)
      on = ev && (PokeAccess::Locator.lens_tile?(ev) rescue false)
      key = on ? [px, py] : nil
      if key && key != @lens_key
        PokeAccess.speak(PokeAccess::I18n.t(:lens_tile_here), false)
      end
      @lens_key = key
    rescue StandardError
      nil
    end

    # Plays a footstep when the player tile changes: water-flavoured when surfing, grass on tall/short
    # grass, else the normal step.
    def self.footstep
      x = $game_player.x; y = $game_player.y
      if @last_x && (x != @last_x || y != @last_y)
        (PokeAccess::Keys.mark_focused rescue nil)
        v = PokeAccess::Config.footstep_volume
        if v && v > 0 && !(PokeAccess::Audio3D.nav_off? rescue false)
          water = ($PokemonGlobal && ($PokemonGlobal.surfing || $PokemonGlobal.diving)) rescue false
          kind = water ? :fstep_water : (on_grass?(x, y) ? :grass : :step)
          routed = (PokeAccess::Audio3D.footstep(kind, v) rescue false)
          unless routed
            file = (kind == :fstep_water) ? "pa_water" : (kind == :grass ? "pa_grass" : "pa_step")
            f = tone_factor(:footstep_tone, 90, 100)
            cue(file, v, ((@flip ? 90 : 100) * f).round)
            @flip = !@flip
          end
        end
      end
      @last_x = x; @last_y = y
    end

    # True if a tile is tall grass or grass (so footsteps there use the grass sound).
    def self.on_grass?(x, y)
      PokeAccess::Terrain.grass?(PokeAccess::Terrain.raw(x, y))
    rescue StandardError
      false
    end

    # Plays a wall cue panned to the wall's side when the player pushes into an impassable tile. The
    # costly passability test runs only while a direction is held and the player is not already moving,
    # so idle/free-walking frames stay cheap.
    def self.wall_cue
      return if (PokeAccess::Audio3D.nav_off? rescue false)
      v = PokeAccess::Config.wall_volume
      return if v.nil? || v <= 0
      if (Input.dir4 rescue 0) == 0 || ($game_player.moving? rescue false)
        @was_blocked = false
        return
      end
      dir = $game_player.direction
      blocked = !($game_player.passable?($game_player.x, $game_player.y, dir) rescue true)
      cd = (PokeAccess::Config.bump_cooldown rescue 16).to_f / PokeAccess::FPS
      cooled = @bump_time.nil? || (PokeAccess.clock - @bump_time) >= cd
      if blocked && (!@was_blocked || cooled)
        fx, fy = front_tile
        ev = event_at(fx, fy)
        interact = !ev.nil? && (PokeAccess::Locator.interactable?(ev) rescue false)
        unless (PokeAccess::Audio3D.bump(dir, interact) rescue false)
          f = tone_factor(:wall_tone, 80, 120)
          case dir
          when 4 then cue("pa3d_wall_l", v, (100 * f).round)
          when 6 then cue("pa3d_wall_r", v, (100 * f).round)
          when 8 then cue("pa3d_wall_c", v, (120 * f).round)
          else        cue("pa3d_wall_c", v, (80 * f).round)
          end
        end
        @bump_time = PokeAccess.clock
      end
      @was_blocked = blocked
    end
  end
end

# Drop the previous map's "already said this" memos on map change or load (Caches.reset_all), the same way
# Audio3D does. Without it a terrain label or a cursor coordinate carried across the door.
PokeAccess::Caches.register(:spatial) { PokeAccess::Spatial.reset_map_state }

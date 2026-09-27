module PokeAccess
  # Footsteps, the wall cue, radar, surface and hidden-tile notices, earcons and the busy? gate. Flat cues give
  # direction with pre-panned files, since old mkxp-z cannot pan a mono sound at playback.
  module Spatial
    DIR = PokeAccess::Paths::SOUNDS
    @flip = false
    @last_x = nil
    @last_y = nil
    @was_blocked = false
    @bump_time = nil
    @bump_heard = false
    @radar_key = nil
    @radar_pos = nil
    @surf_here = nil
    @surf_front = nil
    @surf_pos = nil
    @lens_pos = nil

    # Drops the "already said this" memos, keyed on coordinates or a terrain label, when the map changes.
    def self.reset_map_state
      @radar_key = nil; @radar_pos = nil
      @surf_here = nil; @surf_front = nil; @surf_pos = nil
      @lens_pos = nil
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

    # The rate factor a family's tone applies to a flat cue, clamped so the cue's base pitches low and high stay
    # within the 50-150 an SE accepts (a pitch pair keeps its ratio).
    def self.tone_factor(key, low = 100, high = 100)
      f = PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) / 100.0
      f = 150.0 / high if high * f > 150
      f = 50.0 / low if low * f < 50
      f
    rescue StandardError
      1.0
    end

    # The guide family's tone factor for every path, the engine's included: the one that keeps the flat 140 (ahead)
    # and 70 (behind) pitches inside 50-150.
    def self.guide_tone_factor
      tone_factor(:guide_tone, 70, 140)
    end

    # The named non-positional earcons: symbol => [file, default pitch].
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

    # The pitch range a gauge sweeps: from LOW up by SPAN to 150, the most the flat SE channel plays. A base and a
    # span, not a low and a high: the MTS guard cannot prove a constant minus a constant is scalar.
    GAUGE_LOW = 80
    GAUGE_SPAN = 70

    # A cue whose pitch carries a magnitude, 0.0 low to 1.0 high, for timing minigames; a fraction outside 0..1 is
    # clamped, not refused (live state can overshoot by a frame).
    def self.gauge(fraction, volume = 60, name = :minigame_tick)
      f = fraction.to_f
      f = 0.0 if f < 0.0
      f = 1.0 if f > 1.0
      earcon(name, volume, GAUGE_LOW + (f * GAUGE_SPAN).to_i)
    rescue StandardError
      nil
    end

    # True while the player is not under free control (see busy_reason), so the cues and the guide fall silent. The
    # locator keys use keys_locked? instead.
    def self.busy?
      !busy_reason.nil?
    end

    # Which condition holds the player out of free control (a scene, battle, menu, message, mini update, forced move
    # route or running interpreter), or nil when none does.
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
      return :mini_update if mini_update?
      return :move_route if ($game_player && $game_player.move_route_forcing rescue false)
      return :interpreter if ($game_system && $game_system.map_interpreter && $game_system.map_interpreter.running? rescue false)
      nil
    rescue StandardError
      nil
    end

    # True while another screen owns the arrows and action keys (selection, a picture menu, a menu, a battle, or a
    # mini update with no message up); unlike busy?, not for a message or a running interpreter.
    def self.keys_locked?
      return true if (PokeAccess::Appearance.selecting? rescue false)
      return true if (PokeAccess::PictureCues.menu_showing? rescue false)
      if $game_temp
        return true if ($game_temp.in_menu rescue false)
        return true if ($game_temp.in_battle rescue false)
        return true if mini_update? && !$game_temp.message_window_showing
      end
      false
    rescue StandardError
      false
    end

    # True while a message or menu loop updates the map: $game_temp.in_mini_update (v21) or $PokemonTemp.miniupdate.
    def self.mini_update?
      return true if ($game_temp.in_mini_update rescue false)
      ($PokemonTemp.miniupdate rescue false) ? true : false
    end

    # Runs once per map frame: the 3D listener onto the player's tile first, then footstep on movement, panned wall
    # feedback, radar, surface cues and the hidden-area notice.
    def self.tick
      return unless $game_map && $game_player
      return if busy?
      PokeAccess::Audio3D.follow_player
      footstep
      wall_cue
      radar
      surfaces
      announce_lens_tile
    end

    # The tile directly in front of the player, by facing direction.
    def self.front_tile
      d = PokeAccess::DIR_DELTA[$game_player.direction] || [0, 0]
      [$game_player.x + d[0], $game_player.y + d[1]]
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

    # Says a generic "hidden area" line on arriving at a tile that holds a Lens-of-Truth (#EOT) event; generic because
    # each game names the lens differently.
    def self.announce_lens_tile
      pos = [$game_player.x, $game_player.y]
      return if pos == @lens_pos
      @lens_pos = pos
      ev = event_at(pos[0], pos[1])
      PokeAccess.speak(PokeAccess::I18n.t(:lens_tile_here), false) if ev && (PokeAccess::Locator.lens_tile?(ev) rescue false)
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

    # Plays a wall cue toward the wall when the player pushes into an impassable tile: on the push, on turning to
    # another wall and once per cooldown; records the push, direction and audibility for just_cued?.
    def self.wall_cue
      return if (PokeAccess::Audio3D.nav_off? rescue false)
      v = PokeAccess::Config.wall_volume
      return if v.nil? || v <= 0
      if (Input.dir4 rescue 0) == 0 || walking?
        @was_blocked = false
        return
      end
      dir = $game_player.direction
      blocked = !($game_player.passable?($game_player.x, $game_player.y, dir) rescue true)
      @push_seen = PokeAccess.clock if blocked
      cooled = @bump_time.nil? || (PokeAccess.clock - @bump_time) >= cue_cooldown
      if blocked && (@was_blocked != dir || cooled)
        interact = interact_ahead?
        handled = (PokeAccess::Audio3D.bump(dir, interact) rescue false)
        unless handled
          f = tone_factor(:wall_tone, 80, 120)
          case dir
          when 4 then cue("pa3d_wall_l", v, (100 * f).round)
          when 6 then cue("pa3d_wall_r", v, (100 * f).round)
          when 8 then cue("pa3d_wall_c", v, (120 * f).round)
          else        cue("pa3d_wall_c", v, (80 * f).round)
          end
        end
        @bump_time = PokeAccess.clock
        @bump_dir = dir
        @bump_heard = !handled || (PokeAccess::Config.audio3d_volume rescue 80).to_i > 0
      end
      @was_blocked = blocked ? dir : false
    end

    # The game's own bump by file name, lowercased: "bump" in the gen-6 era, "Player bump" from v18 on. Every era
    # plays it through pbSEPlay, whose param is the name or an RPG::AudioFile carrying it.
    GAME_BUMP_NAMES = ["bump", "player bump"]

    def self.game_bump?(param)
      name = param.is_a?(String) ? param : (param.name rescue nil)
      return false if name.nil?
      GAME_BUMP_NAMES.include?(File.basename(name.to_s, ".*").downcase.strip)
    rescue StandardError
      false
    end

    # Whether the mod's wall cue answers for this bump: wall_cue's test (a held push into a wall, not walking), minus
    # the cooldown on purpose, so only wall bumps are muted.
    def self.wall_cue_takes_over?
      return false if (Input.dir4 rescue 0) == 0
      return false if walking?
      return false if ($game_player.passable?($game_player.x, $game_player.y, $game_player.direction) rescue true)
      cue_audible?(interact_ahead?)
    rescue StandardError
      false
    end

    # Whether the tile ahead holds something to interact with, which the cue sounds apart from a wall.
    def self.interact_ahead?
      fx, fy = front_tile
      ev = event_at(fx, fy)
      !ev.nil? && (PokeAccess::Locator.interactable?(ev) rescue false)
    end

    # Whether the player is really taking a step; a v21 bump's one-step animation (@bumping) does not count.
    def self.walking?
      return false unless ($game_player.moving? rescue false)
      !($game_player.instance_variable_get(:@bumping) rescue false)
    end

    # Whether the mod's wall cue can be heard: sound navigation on, wall volume above zero and, when the positional
    # engine would play it, the engine's master volume above zero.
    def self.cue_audible?(interact = false)
      return false if (PokeAccess::Audio3D.nav_off? rescue false)
      return false if (PokeAccess::Config.wall_volume rescue 0).to_i <= 0
      return true unless (PokeAccess::Audio3D.bump_ready?(interact) rescue false)
      (PokeAccess::Config.audio3d_volume rescue 80).to_i > 0
    end

    # The wall cue's cooldown in seconds: a held push repeats the cue at this pace.
    def self.cue_cooldown
      (PokeAccess::Config.bump_cooldown rescue 16).to_f / PokeAccess::FPS
    end

    # Whether the game's bump is muted: game_bump off, on the map, the bump file, and the wall cue just answered
    # this push or is about to (it plays only while Locator.polling? and not busy?). One bump, never zero or two.
    def self.mute_game_bump?(param)
      return false if (PokeAccess::Config.game_bump rescue true)
      return false unless ($scene.is_a?(Scene_Map) rescue false)
      return false unless game_bump?(param)
      return true if just_cued?
      return false unless (PokeAccess::Locator.polling? rescue false)
      return false if busy?
      wall_cue_takes_over?
    end

    # Seconds past the cue's cooldown, and past releasing the arrow, during which a game bump still counts as the same
    # push: a touch event on a solid tile bumps one frame after the push.
    SAME_PUSH = 0.25

    # Whether a game bump now repeats a push the wall cue answered audibly, toward the wall still faced, within the
    # cooldown plus SAME_PUSH, with the arrow held or let go less than SAME_PUSH ago.
    def self.just_cued?
      return false if @bump_time.nil? || !@bump_heard
      return false if @bump_dir && @bump_dir != ($game_player.direction rescue nil)
      held = (Input.dir4 rescue 0) != 0 || (!@push_seen.nil? && PokeAccess.clock - @push_seen < SAME_PUSH)
      held && (PokeAccess.clock - @bump_time) < cue_cooldown + SAME_PUSH
    end
  end
end

# Mutes the game's own bump at pbSEPlay (the around body skips nxt); every other sound goes through.
PokeAccess::Hooks.wrap_kernel("pbSEPlay", "game_bump", :around) do |args, nxt|
  PokeAccess::Spatial.mute_game_bump?(args[0]) ? nil : nxt.call
end

# Drops the previous map's "already said this" memos on map change or load (Caches.reset_all).
PokeAccess::Caches.register(:spatial) { PokeAccess::Spatial.reset_map_state }

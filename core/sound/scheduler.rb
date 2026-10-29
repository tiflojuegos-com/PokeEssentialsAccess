module PokeAccess
  module Sound
    # The soundscape's map frame (Frame's :sound stage): on a tile change it places the loops (the nearest water, a wind
    # toward each near wall), else re-reads the emitters when a walking event changes tile nearby; then it pings one
    # emitter at most and, afloat, cues the nearest shore. Losing map, control, the mod or sound navigation silences it.
    module Scheduler
      # The window (seconds) after a ping in which emitters within alt_dist of it hold back.
      PING_GAP = 0.25
      # The shortest time (seconds) between two readings brought by events that walk.
      MOVER_GAP = 0.25
      # How much a source behind a wall is muffled, 0-100, in the "occlude" mode.
      OCCLUDE_AMOUNT = 80
      # The seconds between two of the shore's cues afloat.
      SHORE_PERIOD = 1.8

      @active = false
      @scan_pos = nil
      @ptime = {}
      @ping_idx = {}
      @last_ping_any = nil
      @last_ping_pos = nil
      @shore_time = nil
      @mover_time = nil
      @bgm_restored = false
      @basic_silenced = false

      # Whether the soundscape plays (not silenced since its last frame that played).
      def self.active?; @active; end

      # Sound navigation in full (every emitter), and off (nothing, the engine not even booted).
      def self.nav_full?; (PokeAccess::Config.sound_nav rescue :full) == :full; end
      def self.nav_off?; (PokeAccess::Config.sound_nav rescue :full) == :off; end

      # Within how many tiles two emitters take turns rather than sound together.
      def self.alt_dist; (PokeAccess::Config.audio3d_alt_dist rescue 5).to_i; end

      # One map frame of the soundscape. Booting the engine mutes the game's music, so what it plays is played again
      # once booted. The mod switched off stops every channel, the guide's held tone too, which plays with the
      # soundscape silent (a channel already stopped is not sent again).
      def self.tick
        gate(:total)
        unless $game_map && $game_player
          gate(:no_map)
          silence_all if @active
          return
        end
        unless (PokeAccess::Keys.enabled rescue true)
          gate(:mod_off)
          silence_all
          @scan_pos = nil
          return
        end
        if nav_off?
          gate(:nav_off)
          silence_all if @active
          return
        end
        return unless Pa3d.boot
        unless @bgm_restored
          @bgm_restored = true
          replay_music
        end
        busy = PokeAccess::Control.reason(:hold)
        if busy
          gate(busy)
          silence_all if @active
          @scan_pos = nil
          return
        end
        gate(:playing)
        @active = true
        Pa3d.master((PokeAccess::Config.audio3d_volume rescue 80).to_i)
        Pa3d.reach(reach)
        tones
        Pa3d.air((PokeAccess::Config.audio3d_air rescue false) ? true : false)
        Pa3d.hrtf((PokeAccess::Config.audio3d_hrtf rescue true) ? true : false)
        unless nav_full?
          unless @basic_silenced
            silence_emitters
            @basic_silenced = true
          end
          return
        end
        @basic_silenced = false
        scan_and_ping($game_player.x, $game_player.y)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        PokeAccess::Sound.log(:tick, e)
      end

      # The distance in tiles at which the engine silences a source (one value for every channel): Scene::FADE past the
      # farthest a sound is placed, the sonar's range, the wall range or the guide's distance to the side.
      def self.reach
        [Scene.range, Scene.wall_range, Sound.guide_distance].max + Scene::FADE
      end

      # Plays again the music and the background sound the game plays now (a surf's or an event's as well as the
      # map's).
      def self.replay_music
        sys = $game_system
        return unless sys
        bgm = sys.playing_bgm
        bgs = sys.playing_bgs
        sys.bgm_play(bgm) if bgm
        sys.bgs_play(bgs) if bgs
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Gives each channel its family's tone, save the sounds placed to the side or by heading (the guide's and the
      # jump), which set theirs as they play.
      def self.tones
        Catalog.channels.each do |id, _file, _loops|
          place = Catalog.entry(id).place
          Pa3d.tone(id, Mixer.pitch3d(id)) unless place == :side || place == :heading
        end
      end

      # The frame's reading and ping: on a tile change the scene, the walls, the winds, the water and the shore; else the
      # emitters again when an event that walks changed tile near the player, MOVER_GAP after the last reading at the
      # soonest; then one ping and the shore's cue. An ice slide is read once, where it stops.
      def self.scan_and_ping(px, py)
        key = [px, py, $game_map.map_id]
        now = PokeAccess.clock
        unless PokeAccess::Control.sliding?
          if @scan_pos != key
            @scan_pos = key
            step(:rescan) { Scene.scan(px, py) }
            step(:walls) { Scene.read_walls(px, py) }
            step(:winds) { winds(px, py) }
            step(:water) { place_loop(:water, Scene.read_water(px, py), Mixer.volume(:water)) }
            step(:shore) { Scene.read_shore(px, py) }
            @mover_time = now
          elsif (@mover_time.nil? || (now - @mover_time) >= MOVER_GAP) && Scene.moved?(px, py)
            @mover_time = now
            step(:movers) { Scene.scan(px, py) }
          end
        end
        step(:ping) { ping(now) }
        step(:shore_cue) { shore(now) }
      end

      # Runs one part of the frame so its failure is logged without stopping the others.
      def self.step(key)
        yield
      rescue StandardError => e
        PokeAccess.swallowed(e)
        PokeAccess::Sound.log(key, e)
      end

      # Pings one emitter at most: of the kinds due, the one waiting longest, round-robin over its nearest tiles; within
      # PING_GAP of the last ping, a tile within alt_dist of it holds back. A kind switched off or at volume 0 takes no
      # turn.
      def self.ping(now)
        due = []
        Catalog.pings.each do |e|
          list = Scene.emitters[e.id]
          next unless list && !list.empty?
          next if (Mixer.volume(e.id) || 0) <= 0
          last = @ptime[e.id]
          due.push(e.id) if last.nil? || (now - last) >= Mixer.ping_seconds(e.id)
        end
        return if due.empty?
        ad = alt_dist
        gapped = @last_ping_any && (now - @last_ping_any) < PING_GAP
        due.sort_by { |x| @ptime[x] || -1_000_000.0 }.each do |t|
          list = Scene.emitters[t]
          i = (@ping_idx[t] || 0) % list.length
          pos = list[i]
          next if gapped && @last_ping_pos && (pos[0] - @last_ping_pos[0]).abs + (pos[1] - @last_ping_pos[1]).abs <= ad
          @ptime[t] = now
          @last_ping_any = now
          @last_ping_pos = pos
          @ping_idx[t] = i + 1
          if Pa3d.channel(t)
            occlude(t, pos)
            Pa3d.start(t, pos[0], pos[1], Mixer.volume(t))
          end
          return
        end
      end

      # Muffles an emitter before it pings when a wall stands between, in the "occlude" mode; clear otherwise.
      def self.occlude(id, pos)
        return unless $game_player
        occ = 0
        if Scene.occlusion_mode == :occlude && !Scene.line_clear?($game_player.x, $game_player.y, pos[0], pos[1])
          occ = OCCLUDE_AMOUNT
        end
        Pa3d.occlude(id, occ)
      end

      # Plays each wind at its wall at the wind's volume / dist ** (falloff / 50), or stops it with no wall in range or
      # the wind silent.
      def self.winds(px, py)
        exp = (PokeAccess::Config.audio3d_wall_falloff rescue 50).to_f / 50.0
        Catalog.winds.each do |e|
          dist = Scene.walls[e.id]
          base = Mixer.volume(e.id) || 0
          if dist.nil? || base <= 0
            Pa3d.stop(e.id)
          else
            vol = (base.to_f / (dist ** exp)).to_i
            Pa3d.hold(e.id, px + e.side[1] * dist, py + e.side[2] * dist, vol)
          end
        end
      end

      # Plays the shore's cue on the shore the scene read, SHORE_PERIOD after the last at the soonest; none on land, with
      # no shore in range, at volume 0 or with the surf's sound reverted (Config.revert_surf_sound).
      def self.shore(now)
        pos = Scene.shore
        return if pos.nil? || (PokeAccess::Config.revert_surf_sound rescue false)
        return if @shore_time && (now - @shore_time) < SHORE_PERIOD
        vol = Mixer.volume(:shore) || 0
        return if vol <= 0
        @shore_time = now
        Pa3d.start(:shore, pos[0], pos[1], vol)
      end

      # Plays a loop on a tile, or stops it with none or no volume.
      def self.place_loop(id, pos, vol)
        pos && vol.to_i > 0 ? Pa3d.hold(id, pos[0], pos[1], vol) : Pa3d.stop(id)
      end

      # Stops the pings and the loops but keeps the engine for steps and bumps (sound navigation basic).
      def self.silence_emitters
        Pa3d.silence(Catalog.pings.map { |e| e.id } + [:water] + Catalog.winds.map { |e| e.id })
        Scene.forget
        @scan_pos = nil
      end

      # Stops every channel.
      def self.silence_all
        Pa3d.silence
        @active = false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Silences every channel and drops the scan position, so the loops come back without a step: for a screen that
      # takes over without the map loop running. The soundscape silent or not, as the guide's held tone plays without
      # it (a channel already stopped is not sent again).
      def self.suspend
        silence_all
        @scan_pos = nil
      end

      # Drops what was read for the map; the engine, its channels and the ping timers stay.
      def self.reset_map_state
        Scene.forget
        @scan_pos = nil
      end

      # Reads the scene again on the next frame.
      def self.forget_scan
        @scan_pos = nil
      end

      # Counts, by reason, why each frame played or fell silent, for the diagnostic.
      def self.gate(reason)
        @gates ||= {}
        @gates[reason] = (@gates[reason] || 0) + 1
      end

      # The count as "played/total by=reason:n ..." (most frequent first), then starts it again.
      def self.gate_report
        g = (@gates || {})
        total = g[:total] || 0
        return "(sin datos)" if total == 0
        by = g.reject { |k, _| k == :total || k == :playing }.sort_by { |_, v| -v }
        @gates = {}
        "#{g[:playing] || 0}/#{total} playing" + (by.empty? ? "" : " by=" + by.map { |k, v| "#{k}:#{v}" }.join(" "))
      end
    end
  end
end

# Losing control silences the soundscape at once (suspend rather than silence_all, so the loops return without a step).
PokeAccess::Events.on(:control_lost) { |_reason| PokeAccess::Sound::Scheduler.suspend }

# A map change or a load drops what was read of the last map (Caches.reset_all).
PokeAccess::Caches.register(:sound) { PokeAccess::Sound::Scheduler.reset_map_state }

# The settings that only positional sound plays need it (Config's :needs).
PokeAccess::Config.capability(:positional) { PokeAccess::Sound::Pa3d.positional? }

# Reads the scene again on the next frame when a mark or a tag override changes.
PokeAccess::Events.on(:tags_changed) { PokeAccess::Sound::Scheduler.forget_scan }

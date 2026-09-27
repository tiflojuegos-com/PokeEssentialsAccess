module PokeAccess
  # Binaural soundscape through PA3D_steam.dll (Steam Audio HRTF + miniaudio), which also plays footsteps and bumps.
  # Config.sound_nav: :full plays everything (emitter pings, a water loop, a wind loop per wall); :basic only the
  # footsteps and bumps; :off nothing (tick returns before boot).
  module Audio3D
    DIR = PokeAccess::Paths::SOUNDS
    RANGE = 12
    WALL_RANGE = 3
    # Steam Audio world units per map tile; every position sent to the dll is scaled by it.
    TILE_UNITS = 100
    # Wall-side symbol => its RPG Maker direction code, for raycasting toward that side.
    SIDE_DIR = { :w => 4, :e => 6, :n => 8, :s => 2 }
    # Nearest emitters kept per type, and the window (seconds) after a ping during which emitters within alt_dist
    # of it stay quiet.
    NEAR_MAX = 3
    PING_GAP = 0.25
    # Seconds between re-reads of the moving obstacles, on maps that declare them.
    MOVER_SECONDS = 1.0
    # Wall side => [wind channel, dx, dy] for the four directional wind loops.
    WIND_SIDES = { :w => [:wind_w, -1, 0], :e => [:wind_e, 1, 0],
                   :n => [:wind_n, 0, -1], :s => [:wind_s, 0, 1] }

    # Backend dll: Steam Audio binaural HRTF (needs phonon.dll of the matching arch in accessibility/lib).
    DLL = "PA3D_steam.dll"

    INIT = (Win32API.new(DLL, "PA3D_Init",     [],                  "i") rescue nil)
    CHAN = (Win32API.new(DLL, "PA3D_Channel",  ["p", "i"],          "i") rescue nil)
    LIS  = (Win32API.new(DLL, "PA3D_Listener", ["i", "i"],          "v") rescue nil)
    SET  = (Win32API.new(DLL, "PA3D_Set",      ["i", "i", "i", "i", "i"], "v") rescue nil)
    MAST = (Win32API.new(DLL, "PA3D_Master",   ["i"],               "v") rescue nil)
    RATE_FN = (Win32API.new(DLL, "PA3D_Rate",    [], "i") rescue nil)
    LAT_FN  = (Win32API.new(DLL, "PA3D_Latency", [], "i") rescue nil)
    OCCL = (Win32API.new(DLL, "PA3D_Occl", ["i", "i"], "v") rescue nil)
    AIR  = (Win32API.new(DLL, "PA3D_Air",  ["i"],      "v") rescue nil)
    PITCH = (Win32API.new(DLL, "PA3D_Pitch", ["i", "i"], "v") rescue nil)
    # How much a source behind a wall is muffled, 0-100, when the occlusion mode is "occlude".
    OCCLUDE_AMOUNT = 80

    # The 48000 Hz copies of the sounds (the 44100 originals live in DIR), used when the device runs at 48000.
    SND48 = "#{DIR}/48000"

    # Discrete emitter => the config frequency key that paces its ping.
    PING_DEFS = { :npc => :audio3d_freq_npc, :object => :audio3d_freq_object, :door => :audio3d_freq_door,
                  :hazard => :audio3d_freq_object, :trap => :audio3d_freq_object, :control => :audio3d_freq_object,
                  :push => :audio3d_freq_object, :teleporter => :audio3d_freq_door, :mark => :audio3d_freq_mark }

    @ready = false
    @boot_tried = false
    @active = false
    @ptime = {}
    @ch = {}
    @frame = 0
    @scan_pos = nil
    @near = {}
    @wall = {}
    @emitters = {}
    @ping_idx = {}
    @last_ping_any = nil
    @last_ping_pos = nil
    @mover_time = nil
    @rate = nil
    @latency = nil
    @tone_sent = {}

    # Emitter (sonar) detection radius in tiles, user-tunable.
    def self.range; (PokeAccess::Config.audio3d_range rescue RANGE).to_i; end

    # Wall/wind detection range in tiles, user-tunable.
    def self.wall_range; (PokeAccess::Config.audio3d_wall_range rescue WALL_RANGE).to_i; end

    # Distance (tiles) within which two emitters take turns to ping rather than sound together; user-tunable.
    def self.alt_dist; (PokeAccess::Config.audio3d_alt_dist rescue 5).to_i; end

    # What to do with emitters behind a wall: :hear (normal), :occlude (muffled) or :hide (dropped).
    def self.occlusion_mode; (PokeAccess::Config.audio3d_occlusion rescue :hide); end

    # True if the positional-audio dll is present and its entry points resolved.
    def self.available?; INIT && CHAN && LIS && SET && MAST; end

    # The device's native sample rate (Hz) and output latency (ms), set at boot; nil until then.
    def self.device_rate; @rate; end
    def self.device_latency; @latency; end

    # The rate-matched path for a sound file: the 48000 copy when the device runs at 48000 and it exists,
    # else the 44100 original (played at the device rate via the engine's resampler).
    def self.wav(name)
      if @rate == 48000
        p = "#{SND48}/#{name}"
        return p if (File.exist?(p) rescue false)
      end
      "#{DIR}/#{name}"
    end

    # Loads one channel from its rate-matched file; rescued so a missing wav never aborts boot.
    def self.load_ch(name, loop)
      (CHAN.call("#{wav(name)}\0", loop) rescue -1)
    end

    # Every positional channel: [symbol, sound file, 1 when it loops]; the sound glossary previews these same files.
    CHANNEL_FILES = [
      [:npc, "pa3d_npc.wav", 0], [:object, "pa3d_object.wav", 0], [:door, "pa3d_door.wav", 0],
      [:teleporter, "pa3d_teleporter.wav", 0], [:hazard, "pa3d_hazard.wav", 0],
      [:wall, "pa3d_wall.wav", 0], [:interact, "pa3d_interact.wav", 0],
      [:control, "pa3d_control.wav", 0], [:trap, "pa3d_boop.wav", 0], [:push, "pa3d_boing.wav", 0],
      [:mark, "pa3d_mark.wav", 0],
      [:water, "pa3d_water.wav", 1], [:wind_w, "pa3d_wind_w.wav", 1], [:wind_e, "pa3d_wind_e.wav", 1],
      [:wind_n, "pa3d_wind_n.wav", 1], [:wind_s, "pa3d_wind_s.wav", 1],
      [:step, "pa_step.wav", 0], [:grass, "pa_grass.wav", 0], [:fstep_water, "pa_water.wav", 0],
      [:guide, "pa_guide_c.wav", 0], [:guide_hold, "pa3d_guide_hold.wav", 1]
    ]

    # Channel => the tone setting that pitches it: the tone of the family whose volume it plays at.
    TONE_KEYS = {
      :npc => :audio3d_tone_npc, :object => :audio3d_tone_object, :hazard => :audio3d_tone_object,
      :trap => :audio3d_tone_object, :control => :audio3d_tone_object, :push => :audio3d_tone_object,
      :door => :audio3d_tone_door, :teleporter => :audio3d_tone_teleporter, :water => :audio3d_tone_water,
      :mark => :audio3d_tone_mark, :wind_w => :audio3d_tone_wind, :wind_e => :audio3d_tone_wind, :wind_n => :audio3d_tone_wind,
      :wind_s => :audio3d_tone_wind, :wall => :wall_tone, :interact => :wall_tone,
      :step => :footstep_tone, :grass => :footstep_tone, :fstep_water => :footstep_tone, :guide => :guide_tone,
      :guide_hold => :guide_tone
    }

    # Boots the engine and loads its channels, trying only once; returns whether it is ready.
    def self.boot
      return @ready if @ready
      return false if @boot_tried
      @boot_tried = true
      unless available?
        log3d(:boot, "native PA3D dll unavailable (arch mismatch or missing native/)")
        return false
      end
      unless INIT.call == 1
        log3d(:boot, "INIT failed (Steam Audio returned != 1)")
        return false
      end
      @rate    = (RATE_FN.call rescue nil); @rate = nil if @rate && @rate <= 0
      @latency = (LAT_FN.call rescue nil)
      CHANNEL_FILES.each { |sym, file, looping| @ch[sym] = load_ch(file, looping) }
      @ready = true
    rescue StandardError => e
      log3d(:boot, e)
      false
    end

    # Counts, per reason, why each tick played or fell silent, for the diagnostic.
    def self.gate(reason)
      @gates ||= {}
      @gates[reason] = (@gates[reason] || 0) + 1
    end

    # The tally as "played/total by=reason:n ..." (most frequent first), then clears the window.
    def self.gate_report
      g = (@gates || {})
      total = g[:total] || 0
      return "(sin datos)" if total == 0
      by = g.reject { |k, _| k == :total || k == :playing }.sort_by { |_, v| -v }
      @gates = {}
      "#{g[:playing] || 0}/#{total} playing" + (by.empty? ? "" : " by=" + by.map { |k, v| "#{k}:#{v}" }.join(" "))
    end

    # Stops every channel (when the feature is off, or during messages/menus).
    def self.silence_all
      @ch.each_value { |c| SET.call(c, 0, 0, 0, 0) if c && c >= 0 }
      @active = false
    rescue StandardError
      nil
    end

    # Silences the soundscape and drops the scan position, so the loops come back without waiting for a step; for a
    # screen that takes over without the map loop running.
    def self.suspend
      return unless @active
      silence_all
      @scan_pos = nil
    end

    # Drops the per-map scan state (emitters, walls, nearest water, scan position); channels and boot state stay.
    def self.reset_map_state
      @emitters = {}
      @wall = {}
      @near = {}
      @scan_pos = nil
    rescue StandardError
      nil
    end

    # Configured 0-100 volume for an emitter type.
    def self.type_vol(t)
      key = (t == :hazard || t == :trap || t == :control || t == :push) ? :audio3d_object : "audio3d_#{t}"
      (PokeAccess::Config.send(key) rescue 80).to_i
    end

    # True for a channel that loops (water, the winds) rather than plays once.
    def self.loop?(sym)
      row = CHANNEL_FILES.find { |r| r[0] == sym }
      row ? row[2] == 1 : false
    end

    # Playback rate percent for a channel from its family's tone setting; 100 when the channel has no family.
    def self.tone_pitch(sym)
      key = TONE_KEYS[sym]
      return 100 unless key
      PokeAccess.tone_to_pitch(PokeAccess::Config.send(key))
    rescue StandardError
      100
    end

    # Sends the dll each channel's tone pitch when it changed; the guide's channels set their own pitch.
    def self.sync_tones
      return unless PITCH
      @ch.each do |sym, ch|
        next if TONE_KEYS[sym] == :guide_tone || ch.nil? || ch < 0
        p = tone_pitch(sym)
        next if @tone_sent[sym] == p
        PITCH.call(ch, p)
        @tone_sent[sym] = p
      end
    rescue StandardError
      nil
    end

    # Pushes the master volume to the dll only when it changed (the dll keeps it).
    def self.send_master
      v = (PokeAccess::Config.audio3d_volume rescue 80).to_i
      return if v == @master_sent
      MAST.call(v)
      @master_sent = v
    end

    # Plays one channel on the player at a volume and pitch, the config menu's audition of a volume or tone row;
    # false when the engine is down or the channel did not load.
    def self.preview(sym, vol, pitch)
      return false unless @ready && $game_player
      ch = @ch[sym]
      return false unless ch && ch >= 0
      send_master
      if PITCH
        PITCH.call(ch, pitch)
        @tone_sent[sym] = pitch
      end
      SET.call(ch, $game_player.x * TILE_UNITS, $game_player.y * TILE_UNITS, vol.to_i, 1)
      true
    rescue StandardError
      false
    end

    # Stops a channel a preview started (the water and wind loops would otherwise play on under the menu).
    def self.preview_stop(sym)
      ch = @ch[sym]
      SET.call(ch, 0, 0, 0, 0) if @ready && ch && ch >= 0
    rescue StandardError
      nil
    end

    # Whether bump would play: the engine is ready and active and the interact (or wall) channel loaded.
    def self.bump_ready?(interact = false)
      ch = @ch[interact ? :interact : :wall]
      !!(@ready && @active && ch && ch >= 0)
    end

    # Plays a collision sound at the bumped tile so HRTF pans it to that side: the wall sound for
    # terrain, or a distinct interact sound when bumping an npc/object. Returns true if it handled the cue.
    def self.bump(dir, interact = false)
      return false unless bump_ready?(interact) && $game_player
      ch = @ch[interact ? :interact : :wall]
      dx, dy = PokeAccess::DIR_DELTA[dir] || [0, 0]
      vol = (PokeAccess::Config.wall_volume rescue 80).to_i
      SET.call(ch, ($game_player.x + dx) * TILE_UNITS, ($game_player.y + dy) * TILE_UNITS, vol, 1)
      true
    rescue StandardError
      false
    end

    # Plays the guide chime guide_distance tiles left or right of the player; true if handled. Ahead and behind are
    # left to the caller's flat cue on purpose: HRTF cannot place front and back on stereo headphones.
    def self.guide(dir, vol)
      return false unless @ready && $game_player && (dir == 4 || dir == 6)
      ch = @ch[:guide]
      return false unless ch && ch >= 0
      PITCH.call(ch, (100 * PokeAccess::Spatial.guide_tone_factor).round) if PITCH
      gd = guide_distance
      bx, by = PokeAccess::DIR_DELTA[dir] || [0, 0]
      SET.call(ch, ($game_player.x + bx * gd) * TILE_UNITS, ($game_player.y + by * gd) * TILE_UNITS, vol.to_i, 1)
      true
    rescue StandardError
      false
    end

    # Keeps the held-key guide loop sounding toward dir at a pitch, or stops it when dir is nil; true if handled.
    # Left and right sit guide_distance tiles off, ahead and behind on the player (told apart by pitch).
    def self.guide_hold(dir, vol = 0, pitch = 100)
      ch = @ch[:guide_hold]
      return false unless @ready && $game_player && ch && ch >= 0
      if dir.nil?
        SET.call(ch, 0, 0, 0, 0)
        return true
      end
      side = (dir == 4 || dir == 6) ? guide_distance : 0
      dx, dy = PokeAccess::DIR_DELTA[dir] || [0, 0]
      PITCH.call(ch, pitch) if PITCH
      SET.call(ch, ($game_player.x + dx * side) * TILE_UNITS, ($game_player.y + dy * side) * TILE_UNITS, vol.to_i, 1)
      true
    rescue StandardError
      false
    end

    # How many tiles to the side the guide's cues sound (at least one).
    def self.guide_distance
      [(PokeAccess::Config.guide_distance rescue 3).to_i, 1].max
    end

    # Puts the listener on the player's tile at once, so what the map frame places from a new tile (the footstep,
    # the guides' cues) is heard from where the player stands, however long the frame's work before tick; true if set.
    def self.follow_player
      return false unless @ready && $game_player
      LIS.call($game_player.x * TILE_UNITS, $game_player.y * TILE_UNITS)
      true
    rescue StandardError
      false
    end

    # Plays a footstep through the positional engine, centred on the player. Returns true if handled.
    def self.footstep(kind, vol)
      return false unless @ready && $game_player
      ch = @ch[kind]
      return false unless ch && ch >= 0
      SET.call(ch, $game_player.x * TILE_UNITS, $game_player.y * TILE_UNITS, vol.to_i, 1)
      true
    rescue StandardError
      false
    end

    # True when sound navigation is in full mode (all emitters); other modes keep only footsteps/bumps.
    def self.nav_full?; (PokeAccess::Config.sound_nav rescue :full) == :full; end

    # True when sound navigation is off: tick silences everything and does not boot the engine.
    def self.nav_off?; (PokeAccess::Config.sound_nav rescue :full) == :off; end

    # Stops the pings and ambience loops but keeps the engine for footsteps and bumps: sound_nav :basic.
    def self.silence_emitters
      emitter_channels.each do |k|
        c = @ch[k]
        (SET.call(c, 0, 0, 0, 0) rescue nil) if c && c >= 0
      end
      @emitters = {}
      @scan_pos = nil
    end

    # Every emitter channel: the ping types of PING_DEFS, the water loop and the winds.
    def self.emitter_channels
      PING_DEFS.keys + [:water] + WIND_SIDES.values.map { |side| side[0] }
    end

    # One frame: keeps the listener on the player, rescans emitters, walls, winds and water on a tile change, and
    # pings emitters on a timer. Replays the BGM once booted (opening the device mutes it until the next map change).
    # Going busy or mod-off also drops the scan position, so the loops come back without waiting for a step.
    def self.tick
      gate(:total)
      unless $game_map && $game_player
        gate(:no_map)
        silence_all if @active
        return
      end
      unless (PokeAccess::Keys.enabled rescue true)
        gate(:mod_off)
        silence_all if @active
        @scan_pos = nil
        return
      end
      if (nav_off? rescue false)
        gate(:nav_off)
        silence_all if @active
        return
      end
      return unless boot
      unless @bgm_restored
        @bgm_restored = true
        ($game_map.autoplay rescue nil)
      end
      busy = (PokeAccess::Spatial.busy_reason rescue nil)
      if busy
        gate(busy)
        silence_all if @active
        @scan_pos = nil
        return
      end
      gate(:playing)
      @active = true
      send_master
      sync_tones
      if AIR
        a = (PokeAccess::Config.audio3d_air rescue false) ? 1 : 0
        if a != @air_sent
          AIR.call(a)
          @air_sent = a
        end
      end
      px = $game_player.x; py = $game_player.y
      LIS.call(px * TILE_UNITS, py * TILE_UNITS)
      unless nav_full?
        unless @basic_silenced
          silence_emitters
          @basic_silenced = true
        end
        return
      end
      @basic_silenced = false
      one_answer_per_step { scan_and_ping(px, py) }
    rescue StandardError => e
      log3d(:tick, e)
    end

    # The tick's scan and ping: on a tile change the emitters, walls, winds and water; else the moving obstacles when
    # due; then one ping.
    def self.scan_and_ping(px, py)
      key = [px, py, $game_map.map_id]
      now = PokeAccess.clock
      if @scan_pos != key && !slide_hold?
        @scan_pos = key
        step3d(:rescan) { rescan(px, py) }
        step3d(:walls)  { update_walls(px, py) }
        step3d(:winds)  { set_winds(px, py) }
        step3d(:water)  { set_loop(:water, @near[:water], type_vol(:water)) }
        @mover_time = now
      elsif (PokeAccess::Puzzles.has_movers? rescue false) &&
            (@mover_time.nil? || (now - @mover_time) >= MOVER_SECONDS)
        @mover_time = now
        step3d(:movers) { refresh_movers(px, py) }
      end
      step3d(:ping) { ping_types }
    end

    # Runs a block with the engine's passability asked once per step (step_open?): nothing the game runs can change it
    # within one tick, and a scan's rays share most of their steps.
    def self.one_answer_per_step
      @step_memo = {}
      yield
    ensure
      @step_memo = nil
    end

    # The offset that keeps a step's memo key positive for a ray starting at the map's edge.
    STEP_EDGE = 1024

    # True if the engine lets the player step from (x,y) in direction d, an error reading as open; asked once per
    # step within one_answer_per_step.
    def self.step_open?(x, y, d)
      memo = @step_memo
      return engine_step_open?(x, y, d) if memo.nil?
      k = ((x + STEP_EDGE) * 4096 + (y + STEP_EDGE)) * 16 + d
      v = memo[k]
      return v unless v.nil?
      memo[k] = engine_step_open?(x, y, d)
    end

    # The engine's own answer for a step, as the rays have always read it: an error counts as open.
    def self.engine_step_open?(x, y, d)
      ($game_player.passable?(x, y, d) rescue true) ? true : false
    end

    # Whether the rescan waits for the end of an ice slide (route cache on), to run once where it stops.
    def self.slide_hold?
      return false unless (PokeAccess::Config.route_cache rescue false)
      (PokeAccess::Locator.sliding? rescue false) ? true : false
    end

    # Runs one scan step so its failure is logged without aborting the other steps.
    def self.step3d(key)
      yield
    rescue StandardError => e
      log3d(key, e)
    end

    # Writes the first failure of each scan step to the diagnostic marker.
    def self.log3d(key, e)
      @logged3d ||= {}
      return if @logged3d[key]
      @logged3d[key] = true
      PokeAccess.write_marker("audio3d #{key}: #{PokeAccess.format_error(e)}\n")
    rescue StandardError
      nil
    end

    # Re-reads the moving obstacles in range and replaces the cached trap tiles, so the boop follows them.
    def self.refresh_movers(px, py)
      r = range
      hide = occlusion_mode == :hide
      out = []
      $game_map.events.each_value do |ev|
        next unless ev.x && ev.y
        next unless type_of(ev) == :trap
        d = (ev.x - px).abs + (ev.y - py).abs
        next if d > r
        next if hide && !line_clear?(px, py, ev.x, ev.y)
        out.push([ev.x, ev.y, d, (ev.character_name.to_s rescue "")])
      end
      @emitters[:trap] = cluster(out).sort_by { |e| e[2] }[0, NEAR_MAX].map { |e| [e[0], e[1]] }
    rescue StandardError
      nil
    end

    # The soundscape channel of an event, or nil when it does not ping: a tag override first, then the locator's and
    # puzzles' kinds mapped onto channels (derive no kinds here); npc and object need an interactable event.
    def self.type_of(ev)
      return nil if (PokeAccess::Locator.tag_hidden?(ev) rescue false)
      ov = (PokeAccess::Locator.tag_override(ev) rescue nil)
      if ov
        return :door if ov == :exits
        return :npc if ov == :people
        return :object if ov == :objects
        return nil
      end
      po = (PokeAccess::Puzzles.obstacle_kind(ev) rescue nil)
      return :hazard if po == :wall
      return :trap if po == :mover
      return :control if (PokeAccess::Puzzles.control?(ev) rescue false)
      return :hazard if (PokeAccess::Locator.hazard?(ev) rescue false)
      return :push if (PokeAccess::Locator.push_tile?(ev) rescue false)
      return :teleporter if (PokeAccess::Locator.teleporter_event?(ev) rescue false)
      return :door if (PokeAccess::Locator.transfer_event?(ev) rescue false)
      return nil unless (PokeAccess::Locator.has_graphic?(ev) rescue false)
      return nil unless (PokeAccess::Locator.interactable?(ev) rescue true)
      return nil unless reachable_by_keys?(ev)
      ((PokeAccess::Locator.event_category(ev) rescue :objects) == :people) ? :npc : :object
    end

    # Whether the event passes the optional sonar_only_locatable filter (only what the locator keys reach); type_of
    # asks it last, so it can only drop a plain npc or object.
    def self.reachable_by_keys?(ev)
      return true unless (PokeAccess::Config.sonar_only_locatable rescue false)
      (PokeAccess::Locator.in_category?(ev, :all) rescue true)
    end

    # How many events on this map ping and how many the locator keys cannot reach, counted with the filter off.
    def self.reach_census
      return "sin mapa" unless $game_map
      pings = 0
      gap = 0
      $game_map.events.values.each do |ev|
        next if type_of_unfiltered(ev).nil?
        pings += 1
        gap += 1 unless (PokeAccess::Locator.in_category?(ev, :all) rescue true)
      end
      "#{pings} pingan, #{gap} fuera del localizador"
    rescue StandardError
      "?"
    end

    # type_of as if the filter were off, for the census.
    def self.type_of_unfiltered(ev)
      prev = (PokeAccess::Config.sonar_only_locatable rescue false)
      PokeAccess::Config.sonar_only_locatable = false
      type_of(ev)
    ensure
      (PokeAccess::Config.sonar_only_locatable = prev rescue nil)
    end

    # True if no wall blocks a straight-ish walk from (x0, y0) to (x1, y1), stepping on the axis with more distance
    # left (a raycast, not a path search); errors read as clear.
    def self.line_clear?(x0, y0, x1, y1)
      x = x0; y = y0; guard = 0
      until x == x1 && y == y1
        guard += 1
        break if guard > 48
        dx = x1 - x; dy = y1 - y
        if dx.abs >= dy.abs && dx != 0
          d = (dx > 0) ? 6 : 4; nx = x + ((dx > 0) ? 1 : -1); ny = y
        elsif dy != 0
          d = (dy > 0) ? 2 : 8; nx = x; ny = y + ((dy > 0) ? 1 : -1)
        else
          break
        end
        break if nx == x1 && ny == y1
        return false unless step_open?(x, y, d)
        x = nx; y = ny
      end
      true
    rescue StandardError
      true
    end

    # Merges emitter tiles that touch (8-connected) and share a sprite into their tile nearest the player, so a
    # multi-tile structure pings once.
    def self.cluster(list)
      n = list.length
      return list if n <= 1
      groups = PokeAccess::Util.union_groups(n) do |i, j|
        (list[i][0] - list[j][0]).abs <= 1 && (list[i][1] - list[j][1]).abs <= 1 && list[i][3] == list[j][3]
      end
      groups.map { |idxs| idxs.map { |i| list[i] }.min_by { |e| e[2] } }
    end

    # Whether a service desk NPC within audio3d_desk_range tiles (0 = off) is heard through walls in hide mode.
    def self.desk_bypass?(ev, d)
      dk = (PokeAccess::Config.audio3d_desk_range rescue 2).to_i
      return false if dk <= 0 || d > dk
      (PokeAccess::Locator.service_desk?(ev) rescue false)
    end

    # Rebuilds the nearest emitter tiles per type (events and marks in range) and the nearest water; in hide mode
    # emitters behind a wall are skipped, save a near service desk.
    def self.rescan(px, py)
      lists = {}
      r = range
      hide = occlusion_mode == :hide
      $game_map.events.each_value do |ev|
        next unless ev.x && ev.y
        d = (ev.x - px).abs + (ev.y - py).abs
        next if d > r
        t = type_of(ev)
        next unless t
        next if hide && !line_clear?(px, py, ev.x, ev.y) && !desk_bypass?(ev, d)
        (lists[t] ||= []).push([ev.x, ev.y, d, (ev.character_name.to_s rescue "")])
      end
      mark_emitters(px, py, r, hide).each { |e| (lists[:mark] ||= []).push(e) }
      @emitters = {}
      lists.each { |t, arr| @emitters[t] = cluster(arr).sort_by { |e| e[2] }[0, NEAR_MAX].map { |e| [e[0], e[1]] } }
      @near = { :water => nearest_water(px, py, r) }
    end

    # The player's marks in range as emitter tiles, under the same line-of-sight rule; each carries its name so two
    # adjacent marks are not clustered into one.
    def self.mark_emitters(px, py, r, hide)
      out = []
      PokeAccess::Marks.on_map($game_map.map_id).each do |x, y, name|
        d = (x - px).abs + (y - py).abs
        next if d > r
        next if hide && !line_clear?(px, py, x, y)
        out.push([x, y, d, name])
      end
      out
    rescue StandardError
      []
    end

    # Drops the scan position so the next tick rescans where the player stands.
    def self.forget_scan
      @scan_pos = nil
    end

    # The nearest water tile within r, or nil, searched ring by ring outward so the first hit is the nearest.
    def self.nearest_water(px, py, r)
      mw = ($game_map.width rescue 0); mh = ($game_map.height rescue 0)
      memo = water_memo
      bit = PokeAccess::Terrain.bridge_height > 0 ? 1 : 0
      d = 0
      while d <= r
        ring_offsets(d).each do |off|
          x = px + off[0]; y = py + off[1]
          next if x < 0 || y < 0 || x >= mw || y >= mh
          return [x, y] if water_kept?(x, y, memo, bit)
        end
        d += 1
      end
      nil
    rescue StandardError
      nil
    end

    # water_at? for a tile inside the map, kept in memo (water_memo) per bridge state bit, as the terrain it is read
    # from is; asked afresh with no memo.
    def self.water_kept?(x, y, memo, bit)
      return water_at?(x, y) if memo.nil?
      k = (x * 65536 + y) * 2 + bit
      v = memo[k]
      return v unless v.nil?
      memo[k] = water_at?(x, y)
    end

    # The sonar's water answers for this map: a fresh table whenever the terrain memo they are read from is a fresh one
    # (a new map, an event's end, the route cache switched on again), none while there is no terrain memo.
    def self.water_memo
      tm = PokeAccess::Terrain.map_memo
      if tm.nil?
        @water_owner = nil
        return (@water_memo = nil)
      end
      unless @water_owner.equal?(tm)
        @water_owner = tm
        @water_memo = {}
      end
      @water_memo
    end

    # Water for the sonar: any surface label containing "water" (still, deep, the foot of a waterfall).
    def self.water_at?(x, y)
      lbl = PokeAccess::Terrain.label(x, y)
      !lbl.nil? && !lbl.to_s.index("water").nil?
    rescue StandardError
      false
    end

    # The offsets at exactly manhattan distance d, memoized.
    def self.ring_offsets(d)
      @rings ||= {}
      return @rings[d] if @rings[d]
      out = []
      if d == 0
        out.push([0, 0])
      else
        i = 0
        while i < d
          j = d - i
          out.push([i, j], [j, -i], [-i, -j], [-j, i])
          i += 1
        end
      end
      @rings[d] = out
    end

    # Pings at most one emitter per call: of the due types, the most overdue, round-robin over its nearest tiles;
    # within PING_GAP of the last ping, a tile within alt_dist of it is held back.
    def self.ping_types
      now = PokeAccess.clock
      due = []
      PING_DEFS.each do |t, fkey|
        list = @emitters[t]
        next unless list && !list.empty?
        f = (PokeAccess::Config.send(fkey) rescue 70)
        last = @ptime[t]
        due.push(t) if last.nil? || (now - last) >= PokeAccess.freq_to_seconds(f)
      end
      return if due.empty?
      ad = alt_dist
      gapped = @last_ping_any && (now - @last_ping_any) < PING_GAP
      due.sort_by { |x| @ptime[x] || -1_000_000.0 }.each do |t|
        list = @emitters[t]
        i = (@ping_idx[t] || 0) % list.length
        pos = list[i]
        if gapped && @last_ping_pos &&
           (pos[0] - @last_ping_pos[0]).abs + (pos[1] - @last_ping_pos[1]).abs <= ad
          next
        end
        @ptime[t] = now
        @last_ping_any = now
        @last_ping_pos = pos
        @ping_idx[t] = i + 1
        if @ch[t] && @ch[t] >= 0
          set_occlusion(@ch[t], pos)
          SET.call(@ch[t], pos[0] * TILE_UNITS, pos[1] * TILE_UNITS, type_vol(t), 1)
        end
        return
      end
    end

    # Sets a channel's occlusion before it pings: muffled behind a wall in occlude mode, clear otherwise.
    def self.set_occlusion(ch, pos)
      return unless OCCL && $game_player
      occ = 0
      occ = OCCLUDE_AMOUNT if occlusion_mode == :occlude && !line_clear?($game_player.x, $game_player.y, pos[0], pos[1])
      OCCL.call(ch, occ)
    rescue StandardError
      nil
    end

    # Probes the four sides for the nearest wall (only on a tile change; passability tests are costly).
    def self.update_walls(px, py)
      @wall = {}
      WIND_SIDES.each_key { |side| @wall[side] = ray(px, py, side) }
    end

    # Distance (1..wall_range) to the first impassable tile on a side, or nil if open.
    def self.ray(px, py, side)
      info = WIND_SIDES[side]
      dx = info[1]; dy = info[2]
      dir = SIDE_DIR[side]
      (1..wall_range).detect do |i|
        cx = px + dx * (i - 1); cy = py + dy * (i - 1)
        !step_open?(cx, cy, dir)
      end
    end

    # Plays each wind loop at its wall at vol / dist**(falloff / 50), or stops it when no wall is in range.
    def self.set_winds(px, py)
      vol = (PokeAccess::Config.audio3d_wind rescue 55).to_i
      exp = (PokeAccess::Config.audio3d_wall_falloff rescue 50).to_f / 50.0
      wr = wall_range
      WIND_SIDES.each do |side, info|
        ch = info[0]; dx = info[1]; dy = info[2]; dist = @wall[side]
        c = @ch[ch]
        next unless c && c >= 0
        if dist.nil?
          SET.call(c, (px + dx * wr) * TILE_UNITS, (py + dy * wr) * TILE_UNITS, 0, 0)
        else
          v = (vol.to_f / (dist ** exp)).to_i
          SET.call(c, (px + dx * dist) * TILE_UNITS, (py + dy * dist) * TILE_UNITS, v, 1)
        end
      end
    end

    # Positions and plays a looping emitter at a tile, or stops it when pos is nil.
    def self.set_loop(ch, pos, vol)
      c = @ch[ch]
      return unless c && c >= 0
      if pos
        SET.call(c, pos[0] * TILE_UNITS, pos[1] * TILE_UNITS, vol, 1)
      else
        SET.call(c, 0, 0, 0, 0)
      end
    end
  end
end

# Per-frame driver on Game_Player#update. A frame_hook, not an after_hook: gen 6 runs a whole wild battle inside
# that method, and a guarded hook would mute every battle reader for the fight.
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:audio3d) { PokeAccess::Audio3D.tick }
end

# Suspends the soundscape when a battle starts (suspend rather than silence_all, so the loops return without a step).
PokeAccess::Hooks.after_hook("Game_Temp", :in_battle=) do |_t, _r, args|
  PokeAccess::Audio3D.suspend if args[0]
end

# Same when a menu opens, off the flag Scene_Map sets: tick does not run under a menu that never updates the map.
PokeAccess::Hooks.after_hook("Game_Temp", :in_menu=) do |_t, _r, args|
  PokeAccess::Audio3D.suspend if args[0]
end

# Drop the previous map's emitter/wall scan state on map change or load (Caches.reset_all).
PokeAccess::Caches.register(:audio3d) { PokeAccess::Audio3D.reset_map_state }

# Rescans on the next frame when a mark or tag override changes.
PokeAccess::Events.on(:tags_changed) { (PokeAccess::Audio3D.forget_scan rescue nil) }

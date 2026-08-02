module PokeAccess
  # Binaural soundscape: drives PA3D_steam.dll (Steam Audio HRTF + miniaudio) for true 3D audio. It is
  # the single audio engine, so footsteps and wall bumps also go through it. Config.sound_nav :full is
  # the whole soundscape (npc/object/door pings, a water loop, a wind loop per wall); :basic keeps only
  # the footsteps and wall bumps; :off silences everything, this engine included -- tick returns before
  # boot, so nothing is even started.
  module Audio3D
    DIR = PokeAccess::Paths::SOUNDS
    RANGE = 12
    WALL_RANGE = 3
    # Tile-to-engine scale: one map tile is this many Steam Audio world units. Positions are multiplied by
    # it before being passed to the dll so the HRTF distance model matches the on-screen layout.
    TILE_UNITS = 100
    # RPG Maker direction code => [dx, dy] one tile that way, for placing a cue toward a facing/step.
    DIR_DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # Wall-side symbol => its RPG Maker direction code, for raycasting toward that side.
    SIDE_DIR = { :w => 4, :e => 6, :n => 8, :s => 2 }
    # How many nearest emitters of each type to keep (so a close one does not mask the rest), and the
    # window (seconds) after a ping during which emitters within alt_dist of it stay quiet; farther
    # ones may still ping inside the window (HRTF panning already tells them apart).
    NEAR_MAX = 3
    PING_GAP = 0.25
    # Moving obstacles (e.g. ship sharpedos) move while you stand still, so their tiles go stale between
    # tile-change rescans. Re-read just the movers on this cadence (seconds), only on maps that declare them.
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
    # How much a source behind a wall is muffled, 0-100, when the occlusion mode is "occlude".
    OCCLUDE_AMOUNT = 80

    # Per-rate sound sets: the engine opens the device at its native rate, so assets are loaded already at
    # that rate to avoid runtime resampling. 44100 lives in sounds/, 48000 in sounds/48000/.
    SND48 = "#{DIR}/48000"

    # Discrete emitter => the config frequency key that paces its ping.
    PING_DEFS = { :npc => :audio3d_freq_npc, :object => :audio3d_freq_object, :door => :audio3d_freq_door,
                  :hazard => :audio3d_freq_object, :trap => :audio3d_freq_object, :control => :audio3d_freq_object,
                  :push => :audio3d_freq_object, :teleporter => :audio3d_freq_door }

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

    # Emitter (sonar) detection radius in tiles, user-tunable.
    def self.range; (PokeAccess::Config.audio3d_range rescue RANGE).to_i; end

    # Wall/wind detection range in tiles, user-tunable.
    def self.wall_range; (PokeAccess::Config.audio3d_wall_range rescue WALL_RANGE).to_i; end

    # How close (tiles) two emitters must be for their pings to alternate rather than sound at once;
    # farther apart they ping freely (HRTF panning already tells them apart). User-tunable.
    def self.alt_dist; (PokeAccess::Config.audio3d_alt_dist rescue 5).to_i; end

    # What to do with emitters behind a wall: :hear (normal), :occlude (muffled) or :hide (dropped).
    def self.occlusion_mode; (PokeAccess::Config.audio3d_occlusion rescue :occlude); end

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

    # Every positional channel: [symbol, sound file, 1 when it loops]. A table rather than a run of
    # load_ch calls because it is also the ANSWER to "which file does this cue play?" -- the sound
    # glossary previews these same sounds, and a spec cross-checks it against this list, so renaming a
    # wav here can never leave the glossary teaching a sound the engine no longer plays.
    CHANNEL_FILES = [
      [:npc, "pa3d_npc.wav", 0], [:object, "pa3d_object.wav", 0], [:door, "pa3d_door.wav", 0],
      [:teleporter, "pa3d_teleporter.wav", 0], [:hazard, "pa3d_hazard.wav", 0],
      [:wall, "pa3d_wall.wav", 0], [:interact, "pa3d_interact.wav", 0],
      [:control, "pa3d_control.wav", 0], [:trap, "pa3d_boop.wav", 0], [:push, "pa3d_boing.wav", 0],
      [:water, "pa3d_water.wav", 1], [:wind_w, "pa3d_wind_w.wav", 1], [:wind_e, "pa3d_wind_e.wav", 1],
      [:wind_n, "pa3d_wind_n.wav", 1], [:wind_s, "pa3d_wind_s.wav", 1],
      [:step, "pa_step.wav", 0], [:grass, "pa_grass.wav", 0], [:fstep_water, "pa_water.wav", 0],
      [:guide, "pa_guide_c.wav", 0]
    ]

    # Initialises the engine and its channels once (a missing dll/wav must not re-init every frame).
    # Returns whether it is ready.
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

    # Tallies why each tick either played or fell silent. The soundscape is built of LOOPS that only get
    # (re)positioned on a tile change, so a gate that is shut most frames leaves them muted and they are
    # only heard for the instant a step reopens it -- "it sounds when I walk and goes quiet when I stand
    # still". A count per reason turns that into a number the diagnostic can name.
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

    # Drops the per-map scan state (emitters, wall cache, near set, scan cursor) so a new map starts clean
    # and never inherits the previous map's emitters. The audio channels and engine boot state are kept.
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

    # Plays a collision sound at the bumped tile so HRTF pans it to that side: the wall sound for
    # terrain, or a distinct interact sound when bumping an npc/object. Returns true if it handled the cue.
    def self.bump(dir, interact = false)
      ch = @ch[interact ? :interact : :wall]
      return false unless @ready && @active && ch && ch >= 0 && $game_player
      dx, dy = DIR_DELTA[dir] || [0, 0]
      vol = (PokeAccess::Config.wall_volume rescue 80).to_i
      SET.call(ch, ($game_player.x + dx) * TILE_UNITS, ($game_player.y + dy) * TILE_UNITS, vol, 1)
      true
    rescue StandardError
      false
    end

    # Plays the guide cue one tile toward the next step so HRTF pans it that way; works in any sound-nav
    # mode (the guide is explicit navigation). Returns true if handled.
    def self.guide(dir, vol)
      return false unless @ready && $game_player
      ch = @ch[:guide]
      return false unless ch && ch >= 0
      gd = (PokeAccess::Config.guide_distance rescue 3).to_i
      gd = 1 if gd < 1
      bx, by = DIR_DELTA[dir] || [0, 0]
      SET.call(ch, ($game_player.x + bx * gd) * TILE_UNITS, ($game_player.y + by * gd) * TILE_UNITS, vol.to_i, 1)
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

    # True when sound navigation is fully off: nothing plays and the engine is never even booted.
    def self.nav_off?; (PokeAccess::Config.sound_nav rescue :full) == :off; end

    # Stops the looping and discrete emitters while keeping the engine active, which is what :basic
    # means: no pings, no ambience, but footsteps and wall bumps still play (and still panned). In :off
    # the engine never boots at all, so nothing reaches here.
    def self.silence_emitters
      [:npc, :object, :door, :teleporter, :hazard, :trap, :control, :push,
       :water, :wind_w, :wind_e, :wind_n, :wind_s].each do |k|
        c = @ch[k]
        (SET.call(c, 0, 0, 0, 0) rescue nil) if c && c >= 0
      end
      @emitters = {}
      @scan_pos = nil
    end

    # One frame: keeps the listener on the player; on a tile change re-scans the nearby emitters, walls
    # and water/wind loops; pings the discrete emitters on a timer. Called from the Game_Player#update hook.
    # Opening the audio device at boot mutes the game's BGM until the next map change, so the first frame
    # after a successful boot re-plays the map BGM (autoplay) to bring the music straight back.
    def self.tick
      gate(:total)
      unless $game_map && $game_player
        gate(:no_map)
        silence_all if @active
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
        if @active
          silence_all
          # Forget WHERE the soundscape was built. silence_all stopped the looping emitters (the winds,
          # the water) and only the "the player moved to a new tile" branch below ever starts them
          # again -- so without this, closing a message or a menu while standing still left the ambience
          # muted until the next step, which is exactly the "it goes quiet and only comes back when I
          # walk" the gate tally was added to chase. This used to live in a dedicated in_menu branch
          # that was unreachable: busy_reason reports :in_menu itself, so this branch always won first.
          @scan_pos = nil
        end
        return
      end
      gate(:playing)
      @active = true
      v = (PokeAccess::Config.audio3d_volume rescue 80).to_i
      if v != @master_sent
        MAST.call(v)
        @master_sent = v
      end
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
        silence_emitters
        return
      end
      key = [px, py, $game_map.map_id]
      now = PokeAccess.clock
      if @scan_pos != key
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
    rescue StandardError => e
      log3d(:tick, e)
    end

    # Runs one scan step in isolation: a failure in a single step (e.g. a game whose event structure the
    # classifier chokes on) is logged once and never aborts the others, so walls and wind keep working even
    # if the emitter rescan throws -- the old blanket rescue silenced the whole soundscape with no trace.
    def self.step3d(key)
      yield
    rescue StandardError => e
      log3d(key, e)
    end

    # Writes the first failure of each scan step to the diagnostic marker (deduped per step) so a silent
    # spatial-audio outage becomes traceable instead of an empty soundscape with no clue.
    def self.log3d(key, e)
      @logged3d ||= {}
      return if @logged3d[key]
      @logged3d[key] = true
      PokeAccess.write_marker("audio3d #{key}: #{PokeAccess.format_error(e)}\n")
    rescue StandardError
      nil
    end

    # Re-reads only the moving obstacles (movers) near the player and replaces their cached tiles, so the
    # boop tracks them while you stand still. Mirrors rescan's trap filter; called on MOVER_SECONDS only
    # when the current puzzle declares movers.
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

    # Classifies an event into a soundscape channel, or nil if it is not an emitter. This is a PROJECTION of
    # the locator's single source of event classification (Locator's transfer_event?/hazard?/push_tile?/
    # teleporter_event?/event_category and the player tag override) onto the sound vocabulary
    # (npc/object/door/hazard/trap/control/push/teleporter). The classification rules live in Locator; this
    # only maps them to channels, so the two never diverge -- do not re-derive event kinds here. Only
    # interactable events ping as npc/object (a graphic alone is not enough, or decorative sprites would ping
    # as phantom NPCs). A player tag override wins.
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
      ((PokeAccess::Locator.event_category(ev) rescue :objects) == :people) ? :npc : :object
    end

    # True if a straight-ish path from the player to a tile is not blocked by a wall. A cheap direct
    # raycast (walks one tile at a time toward the target on whichever axis has more distance left,
    # checking each move with the engine's passable?), NOT a flood-fill, so it is cheap per emitter per
    # frame. Used to drop emitters behind a wall. Fail-safe: errors read as "clear".
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
        return false unless ($game_player.passable?(x, y, d) rescue true)
        x = nx; y = ny
      end
      true
    rescue StandardError
      true
    end

    # Merges emitter tiles that touch (8-connected) AND share the same sprite identity into one cluster,
    # represented by the tile nearest the player -- so a multi-tile structure (a wide warp door, a long
    # counter) pings once, but distinct NPCs standing together stay separate and still alternate.
    def self.cluster(list)
      n = list.length
      return list if n <= 1
      groups = PokeAccess::Util.union_groups(n) do |i, j|
        (list[i][0] - list[j][0]).abs <= 1 && (list[i][1] - list[j][1]).abs <= 1 && list[i][3] == list[j][3]
      end
      groups.map { |idxs| idxs.map { |i| list[i] }.min_by { |e| e[2] } }
    end

    # Whether a counter NPC (nurse/mart/PC) stays audible through a wall in hide mode, so the player can
    # still find the clerk across a desk. Gated by audio3d_desk_range: 0 disables it, 1-3 keeps it within that range.
    def self.desk_bypass?(ev, d)
      dk = (PokeAccess::Config.audio3d_desk_range rescue 2).to_i
      return false if dk <= 0 || d > dk
      (PokeAccess::Locator.service_desk?(ev) rescue false)
    end

    # Scans events within range for emitter tiles by type, plus the nearest water surface, caching per
    # player tile. With line-of-sight on, emitters behind a wall are skipped (unless a near service desk).
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
      @emitters = {}
      lists.each { |t, arr| @emitters[t] = cluster(arr).sort_by { |e| e[2] }[0, NEAR_MAX].map { |e| [e[0], e[1]] } }
      st = (PokeAccess::Locator.surface_targets rescue [])
      w = st.find { |s| (s.key.to_s.include?("water") rescue false) }
      @near = { :water => (w && ((w.x - px).abs + (w.y - py).abs) <= r) ? [w.x, w.y] : nil }
    end

    # Fires at most one discrete emitter per call. Within PING_GAP of the last ping, only candidates
    # within alt_dist of that ping's position are held back (a farther one still fires; HRTF panning
    # already tells them apart). Among the types whose own frequency timer is due, it fires the MOST
    # OVERDUE one (fair scheduling, so a high-frequency type cannot monopolise every slot); within a
    # type it round-robins its nearest few so they alternate.
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

    # Sets a channel's occlusion before it pings: muffled when the emitter sits behind a wall and the
    # mode is "occlude", clear otherwise (one raycast for the emitter about to sound).
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
        !($game_player.passable?(cx, cy, dir) rescue true)
      end
    end

    # Positions and plays/stops the four wind loops at their walls. Volume falls off with distance so a
    # wall beside you dominates and a one-tile gap (which pushes the wall further away) drops the level,
    # making narrow openings audible. Steepness is user-tunable: v = vol / dist**(falloff/50).
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

# Per-frame driver; hooks Game_Player#update so the whole feature lives in this one file. frame_hook (not
# after_hook) because gen-6 runs a whole wild battle inside Game_Player#update: guarding it would pin the
# reentrancy stack for the entire fight and mute every battle reader.
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:audio3d) { PokeAccess::Audio3D.tick }
end

# Battle suspends the map scene, so the looping channels would keep sounding through the fight; silence
# everything the moment battle begins. It resumes on its own when the map scene comes back.
PokeAccess::Hooks.after_hook("Game_Temp", :in_battle=) do |_t, _r, args|
  PokeAccess::Audio3D.silence_all if args[0]
end

# Drop the previous map's emitter/wall scan state on map change or load (Caches.reset_all).
PokeAccess::Caches.register(:audio3d) { PokeAccess::Audio3D.reset_map_state }

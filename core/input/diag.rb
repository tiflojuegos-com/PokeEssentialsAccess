module PokeAccess
  # The diagnostic half of Keys, split from the orchestrator half (input.rb): everything here answers "why
  # did it go quiet / what is the game showing", and none of it runs on the per-frame hot path except the
  # two edge-triggered key polls. The module is reopened, so @enabled, @typing_ttl and the callers are
  # shared; the window handle and the chord edges are read through their owners, Focus and Keyboard.
  module Keys
    # Writes a diagnostic snapshot with Ctrl+Alt+F9, so the real in-game values can be inspected.
    def self.diag_poll
      diag_dump if hotkey?(:diag_dump, PokeAccess::Keyboard::VK_F9)
    end

    # Speaks a short "where am I / what was read" status with Ctrl+Alt+F10. Unlike diag_poll (which writes a
    # full snapshot to a file a screen-reader user would then have to open), this voices the essentials right
    # away: the active scene, the map and position when on the field, the last line spoken, and the count of
    # hooks that never bound -- the fast answer to "it went quiet, why?".
    def self.spoken_diag_poll
      PokeAccess.speak(spoken_diag, true) if hotkey?(:spoken_diag, PokeAccess::Keyboard::VK_F10)
    end

    # The spoken diagnostic line (see spoken_diag_poll).
    def self.spoken_diag
      parts = []
      parts.push("scene #{dv { $scene ? $scene.class.to_s.split('::').last : 'nil' }}")
      if $game_map && $game_player
        parts.push("map #{dv { PokeAccess::Locator.map_name($game_map.map_id) }} #{dv { $game_player.x }},#{dv { $game_player.y }}")
      end
      last = (PokeAccess.last_spoken rescue nil)
      parts.push("last #{last}") if last && !last.to_s.empty?
      miss = (PokeAccess::Hooks.missing.length rescue 0)
      parts.push("#{miss} hooks missing") if miss > 0
      parts.join(". ")
    rescue StandardError => e
      "diag err #{e.class}"
    end

    # Yields a value for a diagnostics line, returning "ERR(class)" if it raises.
    def self.dv; yield; rescue Exception => e; "ERR(#{e.class})"; end

    # The installed mod version, off the stamp the installer leaves, so a report says which build produced
    # it. Parsed by hand rather than with a JSON library, since the mod runs under Ruby 1.8.7.
    #
    # installed.json is asked FIRST because it is the one that exists in a played game: version.json lives
    # at the repo root and the installer does not deploy it, so it only answers when running from source.
    def self.mod_version
      [["#{PokeAccess::Paths::DATA}/installed.json", /"mod_version"\s*:\s*"([^"]+)"/],
       [File.join(PokeAccess::Paths::ROOT, "version.json"), /"version"\s*:\s*"([^"]+)"/]].each do |path, re|
        txt = (File.read(path) rescue nil)
        m = txt ? txt.match(re) : nil
        return m[1] if m
      end
      "?"
    end

    # Caps a diagnostics field, SAYING SO when it cuts. The caps keep the dump readable; without the mark
    # a cut line is indistinguishable from a complete one, and a reader counts entries that were never
    # there -- a real recording ended a hash at ":roc", which reads as a value rather than as a cut.
    def self.cut(text, limit)
      s = text.to_s
      s.length > limit ? s[0, limit] + "...[cortado]" : s
    end

    # The diagnostic section helpers, in order. The full dump runs them all; the debug menu copies named
    # subsets to the clipboard so a tester can paste just the part that matters.
    DIAG_ALL = [:diag_perf, :diag_focus, :diag_map, :diag_locator, :diag_pathfinder, :diag_surface,
                :diag_audio3d, :diag_scene, :diag_runtime, :diag_polls]
    # Named subsets for the debug menu (small enough to read off the clipboard).
    DIAG_SECTIONS = {
      :audio  => [:diag_audio3d],
      :events => [:diag_locator, :diag_focus],
      :perf   => [:diag_perf, :diag_polls],
      :map    => [:diag_map, :diag_pathfinder, :diag_surface],
      :scene  => [:diag_scene, :diag_runtime]
    }

    # Registers a diagnostic section a PROFILE contributes (the core stays game-agnostic; a fangame with
    # its own mechanics diagnoses them itself). The block receives the output array and pushes lines,
    # exactly like the built-in sections; it joins the full dump and the debug-menu group (default the
    # :scene subset), guarded like every other section so a failing profile diag never loses the rest.
    def self.register_diag_section(name, group = :scene, &body)
      name = name.to_sym
      (@extra_diags ||= {})[name] = body
      DIAG_ALL.push(name) unless DIAG_ALL.include?(name)
      g = DIAG_SECTIONS[group]
      g.push(name) if g && !g.include?(name)
    end

    # Builds a diagnostic snapshot for the given section helpers, returning it as a string (each section
    # guarded so one failing line never loses the rest). Names registered by a profile resolve to their
    # block; the rest are the built-in diag_* methods.
    def self.diag_build(sections)
      o = ["=== PokeAccess diag #{Time.now} ==="]
      sections.each do |m|
        begin
          extra = @extra_diags && @extra_diags[m]
          extra ? extra.call(o) : send(m, o)
        rescue Exception => e
          o.push("#{m}: ERR #{e.class}: #{e.message}")
        end
      end
      o.join("\n")
    end

    # Dumps the full snapshot to accessibility/data/diag.txt (Ctrl+Alt+F9 and the debug menu's "complete" item).
    def self.diag_dump
      text = diag_build(DIAG_ALL)
      saved = ((File.open("#{PokeAccess::Paths::DATA}/diag.txt", "a") { |f| f.write(text + "\n\n") }; true) rescue false)
      PokeAccess.speak(diag_spoken_summary(saved), true)
    rescue Exception => e
      (PokeAccess.speak(PokeAccess::I18n.t(:diag_error, :err => e.class.to_s), true) rescue nil)
    end

    # Copies a named diagnostic subset (see DIAG_SECTIONS) to the clipboard, for the debug menu. Speaks
    # whether it was copied. Small subsets go to the clipboard; the full dump still goes to the file.
    def self.diag_section_to_clip(group)
      secs = DIAG_SECTIONS[group]
      return (PokeAccess.speak(PokeAccess::I18n.t(:diag_unknown_section), true) rescue nil) unless secs
      ok = (PokeAccess::Clipboard.set_text(diag_build(secs)) rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(ok ? :diag_copied : :diag_not_copied), true)
    rescue Exception => e
      (PokeAccess.speak(PokeAccess::I18n.t(:diag_error, :err => e.class.to_s), true) rescue nil)
    end

    # The spoken status: only whether the snapshot was written (the detail goes to diag.txt).
    def self.diag_spoken_summary(saved)
      PokeAccess::I18n.t(saved ? :diag_saved : :diag_not_saved)
    end

    # Per-frame hook timings (avg/max ms over the window since the last diag), then resets the window so each
    # capture measures fresh -- to chase a laggy map, press the diag key on entering it, walk a bit, press
    # again, and compare map_poll vs audio3d ms.
    def self.diag_perf(o)
      o.push("perf: #{PokeAccess::Perf.report}")
      PokeAccess::Perf.reset
    end

    # Which Essentials the mod believes it is running on, plus the capabilities the readers actually gate on.
    # Readers bind by capability, never by version, so this line is for diagnosis: on an unknown fangame it
    # says at a glance whether it is the gen-6 or the GameData era, which battle/UI generation it exposes and
    # whether the player global is the old or the new one -- the facts that decide which readers can bind.
    def self.diag_engine(o)
      e = PokeAccess::Engine
      o.push("mod: #{dv { mod_version }}")
      o.push("engine: kind=#{dv { e.kind }} version=#{dv { e.version }} fork=#{dv { e.fork.inspect }} caps=[#{dv { visible_caps(e).join(', ') }}]")
      o.push("voice: prism=#{dv { !PokeAccess::PEA_SPEAK.nil? }} ready=#{dv { PokeAccess.speech_ready? }} backend=#{dv { PokeAccess.speech_backend.inspect }} speaking=#{dv { PokeAccess.speaking?.inspect }}")
      diag_timing(o)
    end

    # Every registered capability that answers true, plus the raw globals no capability covers. Built from
    # the registry rather than listed by hand so a capability added later -- a third-party plugin probe, say
    # -- turns up in recordings without anyone remembering to come back here. The three the engine line
    # already states (:gamedata and :gen6 as kind=, :sky_fork as fork=) are left out instead of repeated.
    def self.visible_caps(e)
      stated = [:gamedata, :gen6, :sky_fork]
      caps = PokeAccess::Engine::CAPABILITIES.keys.reject { |k| stated.include?(k) }
      out = caps.map { |k| k.to_s }.sort.select { |k| e.has?(k.to_sym) }
      out.push("PokeBattle_Scene") unless PokeAccess.const_at("PokeBattle_Scene").nil?
      out.push("$player") if defined?($player) && $player
      out.push("$Trainer") if defined?($Trainer) && $Trainer
      out
    end

    # The cue-pacing clock next to the engine clocks it is NOT built on, so "everything fires at once" and
    # "nothing ever fires" can be told apart at a glance. uptime_scale is how many System.uptime units make
    # one real second (1 where it counts seconds, 1000000 on a microsecond mkxp-z build); render_fps is
    # measured between two consecutive diags and should sit at frame_rate.
    def self.diag_timing(o)
      now = PokeAccess.clock
      fc = dv { Graphics.frame_count }
      scale = dv { PokeAccess.uptime_scale }
      fps = "n/a"
      if @diag_t0 && fc.is_a?(Numeric) && @diag_fc && (now - @diag_t0) > 0.5
        fps = sprintf("%.1f", (fc - @diag_fc) / (now - @diag_t0))
      end
      o.push("timing: clock=#{sprintf('%.1f', now)}s uptime_scale=#{scale.inspect} render_fps=#{fps} frame_rate=#{dv { Graphics.frame_rate }}")
      @diag_t0 = now
      @diag_fc = fc if fc.is_a?(Numeric)
    end

    # Focus, scene state, hook health and the audio/pathfinder config flags. fn_absent is informative
    # (functions no wrapper found anywhere -- usually legitimate cross-game variance, though a typo'd
    # function name shows up here and nowhere else). caches and data_err name the modules that registered a
    # reset and the data lookups that fell back, which is how "module X forgot to register" becomes visible
    # from a session report; sin_declarar names a third-party plugin this game HAS and the profile never
    # declared a reader for, so its mute screen is visible too.
    def self.diag_focus(o)
      diag_engine(o)
      o.push("enabled=#{@enabled} focused?=#{dv { focused? }} game_hwnd=#{PokeAccess::Focus.hwnd.inspect} typing_ttl=#{@typing_ttl}")
      o.push("focus: GFW=#{dv { GFW.call }} GAW=#{dv { GAW.call }} pid=#{dv { GCPID.call }}")
      o.push("scene=#{dv { $scene.class }} in_menu=#{dv { $game_temp.in_menu }} msg=#{dv { $game_temp.message_window_showing }} interp=#{dv { $game_system.map_interpreter.running? }} surfing=#{dv { $PokemonGlobal.surfing }}")
      o.push("hooks: missing=#{cut(dv { PokeAccess::Hooks.missing.inspect }, 200)} fn_absent=#{cut(dv { PokeAccess::Hooks.fn_absent.inspect }, 200)} overrides=#{cut(dv { PokeAccess::Hooks.overrides.inspect }, 200)}")
      o.push("guard_suppressed=#{cut(dv { PokeAccess::Hooks.suppressed.inspect }, 300)}")
      o.push("caches=#{cut(dv { PokeAccess::Caches.names.inspect }, 200)} data_err=#{cut(dv { PokeAccess::Data.errors.inspect }, 200)}")
      o.push("plugins: cargados=#{cut(dv { PokeAccess::Plugins.loaded.inspect }, 200)} sin_declarar=#{cut(dv { PokeAccess::Plugins.undeclared.inspect }, 200)}")
      gp = dv { PokeAccess::Plugins.game_plugins }
      o.push("plugins_juego: #{gp.is_a?(Array) ? (gp.empty? ? 'ninguno registrado' : cut(gp.join(', '), 400)) : 'sin PluginManager'}")
      c = PokeAccess::Config
      o.push("config: sound_nav=#{dv { c.sound_nav }} auto_guide=#{dv { c.auto_guide }} radar=#{dv { c.proximity_radar }} surface_cues=#{dv { c.surface_cues }} vols=#{dv { c.footstep_volume }}/#{dv { c.wall_volume }}/#{dv { c.event_volume }}")
      o.push("filters: hide_unreachable=#{dv { c.hide_unreachable }} hide_noninteractive=#{dv { c.hide_noninteractive }}")
      o.push("rebinds=#{dv { c.rebinds.inspect }}")
    end

    # The current map, player position and the four neighbouring terrain tags.
    def self.diag_map(o)
      if $game_map && $game_player
        px = $game_player.x; py = $game_player.y
        o.push("map=#{dv { $game_map.map_id }} '#{dv { PokeAccess::Locator.map_name($game_map.map_id) }}' w=#{dv { $game_map.width }} h=#{dv { $game_map.height }} player=#{px},#{py} dir=#{dv { $game_player.direction }} events=#{dv { $game_map.events.size }}")
        tt = lambda { |x, y| dv { $game_map.terrain_tag(x, y) } }
        o.push("terrain here=#{tt.call(px, py)} up=#{tt.call(px, py - 1)} down=#{tt.call(px, py + 1)} left=#{tt.call(px - 1, py)} right=#{tt.call(px + 1, py)}")
      else
        o.push("no game_map/player (probably a menu/title)")
      end
    end

    # A player attribute by name, or nil where this engine does not have it. The trainer type is trainertype
    # in gen-6 and trainer_type in the GameData era, and the wrong one prints ERR(NoMethodError) in the diag,
    # which reads like a fault when it is just the other engine.
    def self.pl_attr(name)
      p = PokeAccess::Engine.player
      (p && p.respond_to?(name)) ? p.send(name) : nil
    rescue StandardError
      nil
    end

    # The locator's category, target list and selected target.
    def self.diag_locator(o)
      l = PokeAccess::Locator
      cats = dv { PokeAccess::Config.categories }
      ci = dv { l.instance_variable_get(:@cat) }
      o.push("categories(#{dv { cats.size }})=#{cats.inspect}")
      o.push("locator: cat=#{ci} (#{dv { cats[ci] }}) ti=#{dv { l.instance_variable_get(:@ti) }} targets=#{dv { l.instance_variable_get(:@targets).size }} target=#{dv { (t = l.instance_variable_get(:@target)) ? t.name : 'none' }} guide=#{dv { l.instance_variable_get(:@guide) }}")
      o.push("targetlist=#{cut(dv { l.instance_variable_get(:@targets)[0, 10].map { |t| "#{t.name rescue '?'}@#{t.x},#{t.y}" } }.inspect, 300)}")
    end

    # The reachable-tiles flood bounds and the route to the selected target.
    def self.diag_pathfinder(o)
      return unless $game_map && $game_player
      c = PokeAccess::Config
      l = PokeAccess::Locator
      pf = PokeAccess::Pathfinder
      o.push("pathfinder: reach=#{dv { c.route_reach }} astar=#{dv { c.astar_max }} algo=#{dv { pf.path_algorithm }} cache=#{dv { c.route_cache }} edge_relax=#{dv { c.edge_relax }}")
      rs = dv { pf.reachable_set }
      if rs.is_a?(Hash) && !rs.empty?
        st = PokeAccess::Pathfinder::PKEY_STRIDE
        xs = rs.keys.map { |k| k / st }; ys = rs.keys.map { |k| k % st }
        o.push("reachable: #{rs.size} tiles, x #{xs.min}..#{xs.max}, y #{ys.min}..#{ys.max}")
      else
        o.push("reachable: #{dv { rs.class }} (empty)")
      end
      tg = dv { l.instance_variable_get(:@target) }
      if tg.respond_to?(:x)
        md = (tg.x - $game_player.x).abs + (tg.y - $game_player.y).abs
        o.push("target_route: to #{tg.x},#{tg.y} manhattan=#{md} over_reach=#{md > (c.route_reach rescue 0)} find_path=#{dv { p = pf.find_path(tg.x, tg.y); p.nil? ? 'NIL' : p.length.to_s + 'steps' }} surf_launch=#{dv { pf.surf_launch(tg.x, tg.y) ? 'shore' : 'nil' }}")
        o.push("  walk_only=#{dv { pf.find_path_to(tg.x, tg.y, false).nil? ? 'NIL(ruta usa ledges/parcial)' : 'ok' }} target_reachable=#{dv { s = pf.reachable_set; [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].any? { |dx, dy| s[pf.pkey(tg.x + dx, tg.y + dy)] } }}")
        o.push("  route=#{cut(dv { pf.path_to_text(pf.find_path(tg.x, tg.y)) }.to_s, 220)}")
      end
    end

    # The surface-cue label map and its targets.
    def self.diag_surface(o)
      l = PokeAccess::Locator
      o.push("surface_label_map=#{dv { l.surface_label_map.size }}: #{cut(dv { l.surface_label_map.inspect }, 250)}")
      o.push("surface_targets=#{dv { l.surface_targets.size }}: #{cut(dv { l.surface_targets.map { |t| "#{t.name}@#{t.x},#{t.y}" } }.inspect, 250)}")
      if $game_map && $game_player
        here = dv { PokeAccess::Terrain.kind($game_player.x, $game_player.y, true) }
        label = dv { PokeAccess::Terrain.label($game_player.x, $game_player.y) }
        front = dv { f = PokeAccess::Spatial.front_tile; PokeAccess::Terrain.kind(f[0], f[1], true) }
        surfable = dv { f = PokeAccess::Spatial.front_tile; PokeAccess::Terrain.surfable_at?(f[0], f[1]) }
        o.push("surf_cue: cues=#{dv { PokeAccess::Config.surface_cues }} here=#{here} label=#{label} front=#{front} surfable_front=#{surfable} surfing=#{dv { $PokemonGlobal.surfing }}")
      end
    end

    # The positional-audio state and the nearby events with their classification/line-of-sight.
    def self.diag_audio3d(o)
      c = PokeAccess::Config
      a3 = PokeAccess::Audio3D
      o.push("audio3d: engine=Steam Audio (phonon+miniaudio) available=#{dv { a3.available? }} sound_nav=#{dv { c.sound_nav }} ready=#{dv { a3.instance_variable_get(:@ready) }} boot_tried=#{dv { a3.instance_variable_get(:@boot_tried) }} active=#{dv { a3.instance_variable_get(:@active) }}")
      o.push("audio3d device: rate=#{dv { a3.device_rate }}Hz latency=#{dv { a3.device_latency }}ms asset_set=#{dv { a3.device_rate == 48000 ? '48000' : '44100' }}")
      o.push("audio3d cfg: master=#{dv { c.audio3d_volume }} occlusion=#{dv { c.audio3d_occlusion }} air=#{dv { c.audio3d_air }} range=#{dv { a3.range }} wall_range=#{dv { a3.wall_range }} alt_dist=#{dv { a3.alt_dist }} wind=#{dv { c.audio3d_wind }} falloff=#{dv { c.audio3d_wall_falloff }}")
      o.push("audio3d vols: npc=#{dv { c.audio3d_npc }} object=#{dv { c.audio3d_object }} door=#{dv { c.audio3d_door }} water=#{dv { c.audio3d_water }}")
      o.push("audio3d chans=#{dv { a3.instance_variable_get(:@ch).inspect }}")
      o.push("audio3d state: scan_pos=#{dv { a3.instance_variable_get(:@scan_pos).inspect }} walls=#{dv { a3.instance_variable_get(:@wall).inspect }} near=#{dv { a3.instance_variable_get(:@near).inspect }}")
      o.push("audio3d gate: now=#{dv { PokeAccess::Spatial.busy_reason.inspect }} #{dv { a3.gate_report }}")
      o.push("sonar reach: #{dv { PokeAccess::Audio3D.reach_census }}")
      o.push("audio3d emitters=#{cut(dv { a3.instance_variable_get(:@emitters).inspect }, 300)}")
      o.push("audio3d movers: has=#{dv { PokeAccess::Puzzles.has_movers? }} cached=#{dv { (a3.instance_variable_get(:@emitters)[:trap]).inspect }} last_scan=#{dv { a3.instance_variable_get(:@mover_time) }} now=#{dv { PokeAccess.clock }}")
      o.push("paths: data=#{dv { PokeAccess::Paths::DATA }} cwd=#{dv { Dir.pwd }} lib=#{dv { PokeAccess::Paths::LIB }}")
      return unless $game_map && $game_player
      o.push("nearby_events=" + cut(dv {
        px = $game_player.x; py = $game_player.y
        near = $game_map.events.values.select { |e| ((e.x - px).abs + (e.y - py).abs) <= 12 }
        near = near.sort_by { |e| (e.x - px).abs + (e.y - py).abs }[0, 12]
        near.map do |e|
          t = (a3.type_of(e) rescue '?'); g = (PokeAccess::Locator.has_graphic?(e) rescue nil)
          int = (PokeAccess::Locator.interactable?(e) rescue nil); los = (a3.line_clear?(px, py, e.x, e.y) rescue nil)
          rch = (PokeAccess::Locator.reachable?(e) rescue nil)
          "#{(e.name rescue '?')}@#{e.x},#{e.y}:#{t.inspect}/g#{g ? 1 : 0}/i#{int ? 1 : 0}/los#{los ? 1 : 0}/R#{rch ? 1 : 0}"
        end.join(" | ")
      }.to_s, 600))
    end

    # Battle/trainer state, player-sprite selection, on-screen pictures, choices and live command windows.
    # The selection line asks character_ID before playerID: playerID is the gen-6 name and raises
    # NoMethodError on a modern game, which is exactly where the field is 1-based and worth checking.
    def self.diag_scene(o)
      o.push("battle_ref=#{dv { PokeAccess::Battle.instance_variable_get(:@battle_ref) ? 'present' : 'nil' }} trainer=#{dv { p = PokeAccess::Engine.player; p ? p.name : 'nil' }}")
      o.push("player_sel: playerID=#{dv { pl_attr(:character_ID) || ($PokemonGlobal.playerID rescue nil) }} charset='#{dv { $game_player.character_name }}' tt=#{dv { pl_attr(:trainertype) || pl_attr(:trainer_type) }} outfit=#{dv { pl_attr(:outfit) }} gender=#{dv { pl_attr(:gender) }}")
      o.push("pictures=" + dv { (1..50).map { |i| n = ($game_screen.pictures[i].name rescue nil); (n && !n.to_s.empty?) ? "#{i}:#{n}" : nil }.compact.join(",") }.to_s)
      o.push("choice=#{dv { $game_temp.respond_to?(:choice_max) ? $game_temp.choice_max : 'n/a' }} choices=#{dv { $game_temp.respond_to?(:choices) ? $game_temp.choices.inspect : 'n/a' }}")
      o.push("scene=#{dv { $scene.class }}")
      o.push("live_cmd_windows=" + cut(dv {
        out = []
        if defined?(ObjectSpace) && defined?(Window_DrawableCommand)
          ObjectSpace.each_object(Window_DrawableCommand) do |w|
            next if (w.disposed? rescue true)
            cmds = PokeAccess.ivar(w, :@commands)
            n = cmds.is_a?(Array) ? cmds.length : "-"
            s0 = (cmds.is_a?(Array) && cmds[0]) ? cmds[0].class.to_s : "-"
            out.push("#{w.class} act=#{w.active rescue '?'} vis=#{w.visible rescue '?'} idx=#{w.index rescue '?'} n=#{n} c0=#{s0}")
          end
        end
        out
      }.inspect, 600))
    end

    # Names of the instance methods a class defines itself (not inherited), sorted, capped. The candidate
    # hook points: the per-cursor-move and per-open methods a reader would bind. param klass any Class.
    def self.own_methods(klass)
      return [] unless klass.is_a?(Module)
      pub = (klass.public_instance_methods(false) rescue [])
      prv = (klass.private_instance_methods(false) rescue [])
      (pub + prv).map { |m| m.to_s }.sort
    end

    # Instance-variable names and a short, safe preview of each value, for one object. The ivar holding the
    # cursor index / data array is what a reader needs; this surfaces it without opening the game's scripts.
    def self.ivar_preview(obj)
      (obj.instance_variables rescue []).sort.map do |iv|
        v = dv { obj.instance_variable_get(iv) }
        s = case v
            when Numeric, Symbol, true, false, nil then v.inspect
            when String then v.length > 40 ? "\"#{v[0, 40]}...\"" : v.inspect
            when Array then "Array(#{v.length})" + (v[0] ? "[#{dv { v[0].class }}...]" : "")
            when Hash then "Hash(#{v.length})"
            else (v.class.to_s rescue "?")
            end
      "#{iv}=#{s}"
      end
    end

    # Runtime introspection of whatever screen is open, so a dev facing a SILENT custom screen can learn to
    # read it without extracting the game's Scripts.rxdata: the live $scene class with its methods and
    # ivars, plus every non-disposed Window/Sprite-based scene object found via ObjectSpace with its index
    # and commands. Heavy (ObjectSpace walk), so it only runs on the diag key.
    def self.diag_runtime(o)
      o.push("--- runtime introspection (for silent screens) ---")
      sc = dv { $scene }
      if sc && !(sc.is_a?(String) && sc.index("ERR") == 0)
        o.push("$scene=#{dv { sc.class }} methods=#{cut(own_methods(sc.class).inspect, 400)}")
        o.push("  ivars: #{cut(ivar_preview(sc).inspect, 500)}")
        spr = dv { sc.instance_variable_get(:@sprites) }
        if spr.is_a?(Hash)
          o.push("  @sprites keys=#{cut(dv { spr.keys.inspect }, 300)}")
          spr.each do |k, w|
            next unless w
            idx = (w.respond_to?(:index) rescue false) ? dv { w.index } : "-"
            o.push("    @sprites[#{k.inspect}]=#{dv { w.class }} idx=#{idx}")
          end
        end
      else
        o.push("$scene unavailable (title/transition?)")
      end
      o.push("live_selectables=" + cut(dv {
        out = []
        if defined?(ObjectSpace)
          [:SpriteWindow_Selectable, :Window_CommandPokemon].each do |cn|
            klass = PokeAccess.const_at(cn)
            next if klass.nil?
            ObjectSpace.each_object(klass) do |w|
              next if (w.disposed? rescue true)
              next unless (w.visible rescue false)
              out.push("#{w.class} idx=#{w.index rescue '?'} act=#{w.active rescue '?'}")
              break if out.length >= 12
            end
          end
        end
        out.uniq
      }.inspect, 500))
    end

    # The per-frame input layers. No poller BENCH here: a bench belongs with whichever reader it measures,
    # and the core is what every Essentials game has, so it must not name a plugin. A plugin that wants one
    # registers its own diagnostic section, exactly as a profile does.
    def self.diag_polls(o)
      aliases = ((class << Input; self; end).instance_methods(false).select { |m| m.to_s =~ /update__access/ } rescue [])
      o.push("input_update_layers: #{aliases.inspect} frame_pollers=#{(@frame_pollers || []).length}")
    rescue Exception => e
      o.push("diag_polls: ERR #{e.class}: #{e.message}")
    end
  end
end

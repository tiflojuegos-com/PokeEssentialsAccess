# What the soundscape leaves playing per sound_nav mode and while another screen owns the game. The harness has no
# dll, so suites set @ready and the @ch table boot would build, record the native calls, and give $Trainer a
# stand-in (with it nil, Spatial.busy_reason reports :appearance and tick bails).
module A3DModes
  IVARS = [:@ready, :@ch, :@active, :@emitters, :@near, :@wall, :@scan_pos, :@ptime, :@ping_idx,
           :@last_ping_any, :@last_ping_pos, :@mover_time, :@gates, :@bgm_restored, :@master_sent, :@air_sent]
  FNS = [:SET, :LIS]

  # The channel handle table boot() fills in, one handle per declared channel.
  def self.channels
    h = {}
    PokeAccess::Audio3D::CHANNEL_FILES.each_with_index { |row, i| h[row[0]] = i }
    h
  end

  # The engine ivars a suite is about to overwrite (Reset.between_suites does not touch this module).
  def self.snapshot
    IVARS.inject({}) { |h, k| h[k] = PokeAccess::Audio3D.instance_variable_get(k); h }
  end

  def self.restore(saved)
    saved.each { |k, v| PokeAccess::Audio3D.instance_variable_set(k, v) }
    stop_recording
  end

  # Records every native call as [entry point, arguments] instead of reaching the (stubbed) dll.
  def self.record(log)
    FNS.each do |c|
      fn = PokeAccess::Audio3D.const_get(c)
      fn.define_singleton_method(:call) { |*a| log.push([c, a]); 0 }
    end
  end

  def self.stop_recording
    FNS.each do |c|
      sc = (class << PokeAccess::Audio3D.const_get(c); self; end)
      sc.send(:remove_method, :call) if sc.instance_methods(false).map { |m| m.to_s }.include?("call")
    end
  end

  # The last state written to each channel, as {channel symbol => playing flag}.
  def self.states(log, chans)
    inv = {}
    chans.each { |k, v| inv[v] = k }
    out = {}
    log.each { |c, a| out[inv[a[0]]] = a[4] if c == :SET }
    out
  end
end

# sound_nav's three values: basic is neither full nor off.
Suite.define("audio3d: the sound_nav setting reads as three distinct modes") do
  a3d = PokeAccess::Audio3D
  PokeAccess::Config.sound_nav = :full
  truthy "full is full", a3d.nav_full?
  falsy "full is not off", a3d.nav_off?
  PokeAccess::Config.sound_nav = :basic
  falsy "basic is not full", a3d.nav_full?
  falsy "and basic is not off either", a3d.nav_off?
  PokeAccess::Config.sound_nav = :off
  falsy "off is not full", a3d.nav_full?
  truthy "off is off", a3d.nav_off?
  PokeAccess::Config.sound_nav = :full
end

# One tick per mode over the same map: full plays the soundscape, basic keeps the engine for steps and bumps but no
# emitters, off stops every channel.
Suite.define("audio3d: sound_nav decides what a tick leaves playing") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  prev_trainer = $Trainer
  log = []
  begin
    $Trainer = Object.new
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@scan_pos, nil)
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@ping_idx, {})
    a3d.instance_variable_set(:@last_ping_any, nil)
    $game_map.load_grid(["#########", "#@......#", "#########"])
    World.clear_events
    npc = World.event(:kind => :trainer, :id => 1, :x => 4, :y => 1)
    npc.character_name = "ana"
    A3DModes.record(log)

    PokeAccess::Config.sound_nav = :full
    a3d.tick
    st = A3DModes.states(log, chans)
    truthy "full mode keeps the engine active", a3d.instance_variable_get(:@active)
    eq "the listener sits on the player, scaled to engine units",
       log.detect { |c, _a| c == :LIS }[1], [1 * a3d::TILE_UNITS, 1 * a3d::TILE_UNITS]
    eq "the person in the corridor pings", st[:npc], 1
    eq "the wall beside the player blows wind", st[:wind_w], 1
    eq "and the water loop is stopped where there is no water", st[:water], 0

    log.clear
    PokeAccess::Config.sound_nav = :basic
    a3d.instance_variable_set(:@scan_pos, nil)
    a3d.tick
    st = A3DModes.states(log, chans)
    truthy "basic keeps the engine active, so steps and bumps still pan", a3d.instance_variable_get(:@active)
    silenced = (a3d::PING_DEFS.keys + [:water] + a3d::WIND_SIDES.values.map { |i| i[0] })
    eq "every emitter and ambience channel is stopped", silenced.reject { |k| st[k] == 0 }, []
    eq "and nothing is left scanned to ping next frame", a3d.instance_variable_get(:@emitters), {}
    eq "the footstep channel was not touched at all", st[:step], nil

    log.clear
    PokeAccess::Config.sound_nav = :off
    a3d.tick
    st = A3DModes.states(log, chans)
    falsy "off deactivates the engine, so even a wall bump stops routing through it",
          a3d.instance_variable_get(:@active)
    eq "and every single channel, footsteps included, is stopped",
       chans.keys.reject { |k| st[k] == 0 }, []
  ensure
    PokeAccess::Config.sound_nav = :full
    $Trainer = prev_trainer
    A3DModes.restore(saved)
    World.clear_events
    $game_map.clear_grid
  end
end

# The frame a step lands in moves the listener to the new tile before the footstep sounds there: tick moves it only
# at the end of the frame, after the guides run and any guide re-planning off its route is applied.
Suite.define("audio3d: the listener is on the new tile before the footstep is placed there") do
  a3d = PokeAccess::Audio3D
  sp = PokeAccess::Spatial
  saved = A3DModes.snapshot
  prev_trainer = $Trainer
  log = []
  begin
    $Trainer = Object.new
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    $game_map.load_grid(["######", "#@...#", "######"])
    World.clear_events
    A3DModes.record(log)
    sp.instance_variable_set(:@last_x, 1)
    sp.instance_variable_set(:@last_y, 1)
    $game_player.x = 2
    sp.tick
    here = [2 * a3d::TILE_UNITS, 1 * a3d::TILE_UNITS]
    lis = log.index { |c, a| c == :LIS && a == here }
    step = log.index { |c, a| c == :SET && a[0] == chans[:step] }
    truthy "the step is placed on the new tile", step && log[step][1][1, 2] == here
    truthy "with the listener already moved there", lis && step && lis < step
  ensure
    $game_player.x = 1
    $Trainer = prev_trainer
    A3DModes.restore(saved)
    World.clear_events
    $game_map.clear_grid
  end
end

# silence_emitters, the basic-mode gate: stops every emitter type, water and wind, and leaves the footstep, bump
# and guide channels alone.
Suite.define("audio3d: silence_emitters stops the emitters and spares the footsteps") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  log = []
  begin
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@emitters, { :npc => [[3, 3]], :door => [[4, 4]] })
    a3d.instance_variable_set(:@scan_pos, [3, 3, 1])
    A3DModes.record(log)

    a3d.silence_emitters
    st = A3DModes.states(log, chans)
    expected = a3d::PING_DEFS.keys + [:water] + a3d::WIND_SIDES.values.map { |i| i[0] }
    eq "every emitter type the classifier can produce is silenced", expected.reject { |k| st[k] == 0 }, []
    eq "the footstep channels are left untouched",
       [:step, :grass, :fstep_water, :wall, :interact, :guide].reject { |k| st[k].nil? }, []
    eq "the scanned emitters are dropped", a3d.instance_variable_get(:@emitters), {}
    eq "and the scan cursor is armed, so switching back to full rescans at once",
       a3d.instance_variable_get(:@scan_pos), nil
  ensure
    A3DModes.restore(saved)
  end
end

# bump, guide and footstep sound on the tile they mean, and return false when declining, for Spatial's flat fallback.
Suite.define("audio3d: the bump, guide and step cues are placed on the tile they mean") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  prev_gd = PokeAccess::Config.guide_distance
  prev_wv = PokeAccess::Config.wall_volume
  log = []
  begin
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@active, true)
    a3d.instance_variable_set(:@ch, chans)
    PokeAccess::Config.wall_volume = 64
    $game_player.x = 5
    $game_player.y = 5
    u = a3d::TILE_UNITS
    A3DModes.record(log)

    truthy "bumping a wall to the east is handled", a3d.bump(6)
    eq "and sounds one tile east, at the wall volume", log[0][1], [chans[:wall], 6 * u, 5 * u, 64, 1]
    log.clear
    a3d.bump(8)
    eq "bumping north sounds north", log[0][1], [chans[:wall], 5 * u, 4 * u, 64, 1]

    log.clear
    a3d.bump(4, true)
    eq "bumping into someone plays the interact cue there instead",
       log[0][1], [chans[:interact], 4 * u, 5 * u, 64, 1]

    log.clear
    a3d.instance_variable_set(:@active, false)
    falsy "an inactive engine declines the bump", a3d.bump(6)
    eq "and plays nothing", log.length, 0

    log.clear
    PokeAccess::Config.guide_distance = 3
    truthy "the guide still answers while the engine is inactive", a3d.guide(6, 70)
    eq "and sounds guide_distance tiles ahead, so the route has a direction",
       log[0][1], [chans[:guide], 8 * u, 5 * u, 70, 1]
    log.clear
    PokeAccess::Config.guide_distance = 0
    a3d.guide(6, 70)
    eq "a zero distance is clamped to one tile, never onto the player", log[0][1],
       [chans[:guide], 6 * u, 5 * u, 70, 1]

    log.clear
    truthy "a footstep is handled", a3d.footstep(:grass, 55)
    eq "and sounds on the player's own tile", log[0][1], [chans[:grass], 5 * u, 5 * u, 55, 1]
    log.clear
    falsy "a kind with no channel declines instead of playing the wrong sound", a3d.footstep(:nope, 55)
    eq "playing nothing", log.length, 0
  ensure
    PokeAccess::Config.guide_distance = prev_gd
    PokeAccess::Config.wall_volume = prev_wv
    A3DModes.restore(saved)
  end
end

# A message on screen stops every channel and marks the engine inactive; the frame after it closes is not asserted.
Suite.define("audio3d: a message on screen mutes the whole soundscape") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  prev_trainer = $Trainer
  log = []
  begin
    $Trainer = Object.new
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@active, true)
    a3d.instance_variable_set(:@gates, {})
    PokeAccess::Config.sound_nav = :full
    A3DModes.record(log)

    eq "with nothing on screen the tick is free to play", PokeAccess::Spatial.busy_reason, nil
    $game_temp.message_window_showing = true
    a3d.tick
    st = A3DModes.states(log, chans)
    eq "every channel is stopped while the message is up", chans.keys.reject { |k| st[k] == 0 }, []
    falsy "and the engine is marked inactive", a3d.instance_variable_get(:@active)
    truthy "the reason is counted for the diagnostic", a3d.instance_variable_get(:@gates)[:message].to_i > 0
  ensure
    $game_temp.message_window_showing = nil
    $Trainer = prev_trainer
    A3DModes.restore(saved)
  end
end

# Ctrl+Alt+F8 off stops every channel and keeps it quiet; back on rebuilds the scan at once where the player stands.
Suite.define("audio3d: switching the mod off with Ctrl+Alt+F8 silences the sonar, and on rebuilds it") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  prev_trainer = $Trainer
  prev_enabled = PokeAccess::Keys.instance_variable_get(:@enabled)
  log = []
  begin
    $Trainer = Object.new
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@scan_pos, nil)
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@ping_idx, {})
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.instance_variable_set(:@gates, {})
    PokeAccess::Config.sound_nav = :full
    $game_map.load_grid(["#########", "#@......#", "#########"])
    World.clear_events
    npc = World.event(:kind => :trainer, :id => 1, :x => 4, :y => 1)
    npc.character_name = "ana"
    A3DModes.record(log)

    a3d.tick
    eq "with the mod on, the person in the corridor pings", A3DModes.states(log, chans)[:npc], 1

    log.clear
    PokeAccess::Keys.instance_variable_set(:@enabled, false)
    a3d.tick
    eq "switched off, every channel is stopped", chans.keys.reject { |k| A3DModes.states(log, chans)[k] == 0 }, []
    falsy "the engine is marked inactive", a3d.instance_variable_get(:@active)
    truthy "the reason is counted for the diagnostic", a3d.instance_variable_get(:@gates)[:mod_off].to_i > 0

    log.clear
    a3d.tick
    eq "and it stays quiet while the mod is off", log.select { |c, a| c == :SET && a[4] == 1 }, []

    npc.x = 6
    log.clear
    PokeAccess::Keys.instance_variable_set(:@enabled, true)
    a3d.tick
    eq "switched back on, the scan is rebuilt where the player stands without a step (the person who moved " \
       "meanwhile is where they are now)", a3d.instance_variable_get(:@emitters)[:npc], [[6, 1]]
    eq "and the wall beside the player blows wind again", A3DModes.states(log, chans)[:wind_w], 1

    log.clear
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.tick
    eq "so the person pings again at the next beat of its pace", A3DModes.states(log, chans)[:npc], 1
  ensure
    PokeAccess::Keys.instance_variable_set(:@enabled, prev_enabled)
    PokeAccess::Config.sound_nav = :full
    $Trainer = prev_trainer
    A3DModes.restore(saved)
    World.clear_events
    $game_map.clear_grid
  end
end

# With route_cache on, the tick keeps the old scan during an ice slide and rescans once where it stops; with it off
# every tile is scanned.
Suite.define("audio3d: with the route cache on, a slide is scanned where it stops, not on every tile") do
  a3d = PokeAccess::Audio3D
  saved = A3DModes.snapshot
  prev_trainer = $Trainer
  begin
    $Trainer = Object.new
    chans = A3DModes.channels
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@scan_pos, nil)
    a3d.instance_variable_set(:@gates, {})
    PokeAccess::Config.sound_nav = :full
    PokeAccess::Config.route_cache = true
    $game_map.load_grid(["##########", "#@.......#", "##########"])
    World.clear_events
    (2..6).each { |x| $game_map.set_terrain(x, 1, 12) }
    $game_player.x = 1; $game_player.y = 1
    a3d.tick
    eq "standing still, the scan is where the player is", a3d.instance_variable_get(:@scan_pos)[0, 2], [1, 1]

    $PokemonGlobal.sliding = true
    [2, 3, 4].each { |x| $game_player.x = x; a3d.tick }
    eq "while the slide carries the player the scan stays where it was", a3d.instance_variable_get(:@scan_pos)[0, 2], [1, 1]

    $PokemonGlobal.sliding = false
    $game_player.x = 7
    a3d.tick
    eq "and it is redone once, where the slide stops", a3d.instance_variable_get(:@scan_pos)[0, 2], [7, 1]

    PokeAccess::Config.route_cache = false
    $PokemonGlobal.sliding = true
    $game_player.x = 3
    a3d.tick
    eq "with the cache off every tile of a slide is scanned", a3d.instance_variable_get(:@scan_pos)[0, 2], [3, 1]
  ensure
    $PokemonGlobal.sliding = false
    PokeAccess::Config.sound_nav = :full
    $Trainer = prev_trainer
    A3DModes.restore(saved)
    World.clear_events
    $game_map.clear_grid
  end
end

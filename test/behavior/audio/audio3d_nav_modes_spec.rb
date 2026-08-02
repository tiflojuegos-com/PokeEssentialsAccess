# What the soundscape actually leaves PLAYING, per sound_nav mode and while another screen owns the game.
# Getting a mode wrong is silent in the worst sense: a player who picked "basic" to quiet the pings would
# lose their footsteps too, and a soundscape that survives a battle or a menu talks over the reader.
#
# Why this suite forces engine state: the harness ships no PA3D dll. Win32API is a stub class whose #call
# returns 0, so Audio3D.available? is TRUE (the entry points "resolve") but boot() fails on `INIT.call == 1`
# and leaves @ready false with no channels, which every play path refuses with `return false unless @ready`.
# The suite therefore sets @ready and the @ch handle table boot would have built, and restores both. Nothing
# native is reached either way: each entry point is one of those Win32API stubs, and the ones observed here
# get their #call replaced by a recorder, so the asserts read exactly the arguments the real dll would take.
# $Trainer is given a stand-in for the same reason: with it nil the harness's Spatial.busy_reason reports
# :appearance (the character-selection screen), and tick would bail before ever reaching the nav gate.
module A3DModes
  IVARS = [:@ready, :@ch, :@active, :@emitters, :@near, :@wall, :@scan_pos, :@ptime, :@ping_idx,
           :@last_ping_any, :@last_ping_pos, :@mover_time, :@gates, :@bgm_restored, :@master_sent, :@air_sent]
  FNS = [:SET, :LIS]

  # The channel handle table boot() would have filled in, one handle per declared channel.
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

# The three-way setting every other module gates on. nav_full? and nav_off? are asked with a `rescue`
# default at a dozen call sites, so their meaning for the middle value matters: "basic" is NOT off.
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

# One tick per mode over the same map, reading what each left playing. This is the headline contract of the
# whole feature: off = nothing, basic = the engine alive for steps and bumps but no emitters, full = the
# soundscape. The three run back to back so no assert can pass by a state left over from the mode before.
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

# silence_emitters is the basic-mode gate, called every frame: it must stop exactly the emitters and leave
# the footstep/bump/guide channels alone -- those are one-shots the game re-triggers, and re-stopping them
# every frame would cut a step short. The list of channels it stops is written out INSIDE the method, so
# this is the assert that catches a new emitter type added to PING_DEFS and forgotten there (it would keep
# pinging in basic mode, which is precisely the mode the player chose to stop pings).
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

# Steps, wall bumps and the guide are the cues that survive basic mode, so they are the last thing a player
# who turned the pings off still navigates by. Each is placed on the tile it MEANS -- the bumped wall, the
# next step of the route -- because that is what makes HRTF pan it to the right ear; a cue centred on the
# player would say "something happened" and nothing more. All three also report whether they handled the
# cue, and Spatial falls back to flat non-positional stereo when they say no, so the false cases matter too.
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

    # Bumping a person is a different sound on a different channel: "you cannot pass" vs "someone is here".
    log.clear
    a3d.bump(4, true)
    eq "bumping into someone plays the interact cue there instead",
       log[0][1], [chans[:interact], 4 * u, 5 * u, 64, 1]

    # With the engine inactive (off mode, or a menu up) the bump must decline so Spatial can fall back.
    log.clear
    a3d.instance_variable_set(:@active, false)
    falsy "an inactive engine declines the bump", a3d.bump(6)
    eq "and plays nothing", log.length, 0

    # The guide is explicit navigation: it answers even with the engine inactive, unlike the bump above.
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

# Another screen owning the game (a message box, a menu, a battle) must mute the whole soundscape: the
# looping channels would otherwise play under the screen reader for the entire conversation. The frame
# AFTER the message closes is deliberately NOT asserted here -- today the loops only return on the next
# tile change, which is reported as a bug rather than pinned as a contract.
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

# WHEN and WHERE each emitter sounds: the ping scheduler, the occlusion pass and the loop placement. This
# is the layer that keeps the soundscape readable -- one cue at a time, taking turns, panned to the right
# tile. Its failures are all "too much at once" or "the wrong ear", neither of which any other suite sees.
#
# Why this suite forces engine state: the harness ships no PA3D dll. Win32API is a stub class whose #call
# returns 0, so boot() fails on `INIT.call == 1` and leaves @ready false with no channels, and every play
# path refuses with `ch >= 0`. The suite seeds @ch with the handle table boot would have built and replaces
# the #call of the entry points it watches with a recorder, so the asserts read exactly the arguments the
# real dll would have received. Everything is restored afterwards.
module A3DPace
  IVARS = [:@ch, :@emitters, :@ptime, :@ping_idx, :@last_ping_any, :@last_ping_pos, :@wall]
  FNS = [:SET, :OCCL]

  # The channel handle table boot() would have filled in, one handle per declared channel.
  def self.channels
    h = {}
    PokeAccess::Audio3D::CHANNEL_FILES.each_with_index { |row, i| h[row[0]] = i }
    h
  end

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

  # The [x, y] tiles that were played (volume > 0), in the order they sounded.
  def self.played(log)
    log.select { |c, a| c == :SET && a[4] == 1 }.map { |_c, a| [a[1] / PokeAccess::Audio3D::TILE_UNITS,
                                                                a[2] / PokeAccess::Audio3D::TILE_UNITS] }
  end
end

# At most ONE emitter per tick, and the type chosen is the one whose own timer has been waiting longest.
# Without the fairness sort a high-frequency type would win every slot and the player would never hear the
# doors; without the one-per-call rule every type due on the same frame would fire at once and blur into
# noise. The two halves are asserted with the same two types in both orders, so neither can pass by luck.
Suite.define("audio3d: one ping per tick, and the most overdue type gets it") do
  a3d = PokeAccess::Audio3D
  saved = A3DPace.snapshot
  log = []
  begin
    a3d.instance_variable_set(:@ch, A3DPace.channels)
    a3d.instance_variable_set(:@emitters, { :npc => [[4, 4]], :door => [[16, 16]] })
    A3DPace.record(log)

    now = PokeAccess.clock
    a3d.instance_variable_set(:@ptime, { :npc => now - 10.0, :door => now - 1.0 })
    a3d.instance_variable_set(:@ping_idx, {})
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.instance_variable_set(:@last_ping_pos, nil)
    a3d.ping_types
    eq "exactly one emitter sounded", A3DPace.played(log).length, 1
    eq "the type that had waited longest", A3DPace.played(log), [[4, 4]]

    log.clear
    now = PokeAccess.clock
    a3d.instance_variable_set(:@ptime, { :npc => now - 1.0, :door => now - 10.0 })
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.instance_variable_set(:@last_ping_pos, nil)
    a3d.ping_types
    eq "swap who waited longest and the other type gets the slot", A3DPace.played(log), [[16, 16]]

    # A type inside its own frequency window must stay quiet: this timer IS the player's frequency slider.
    log.clear
    now = PokeAccess.clock
    a3d.instance_variable_set(:@emitters, { :npc => [[4, 4]] })
    a3d.instance_variable_set(:@ptime, { :npc => now })
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.ping_types
    eq "a type that just pinged waits for its next slot", A3DPace.played(log), []

    log.clear
    a3d.instance_variable_set(:@emitters, {})
    a3d.instance_variable_set(:@ptime, {})
    a3d.ping_types
    eq "and an empty soundscape plays nothing at all", log.length, 0
  ensure
    A3DPace.restore(saved)
  end
end

# Within one type the nearest few take turns, so three people in a room are heard as three positions
# instead of the closest one masking the rest. The cursor must ADVANCE on every ping and wrap: a cursor
# stuck at 0 is the "only one of them ever sounds" bug the alternation was written to fix.
Suite.define("audio3d: the nearest few of a type take turns, wrapping round") do
  a3d = PokeAccess::Audio3D
  saved = A3DPace.snapshot
  log = []
  begin
    a3d.instance_variable_set(:@ch, A3DPace.channels)
    a3d.instance_variable_set(:@emitters, { :npc => [[4, 4], [4, 12], [12, 4]] })
    a3d.instance_variable_set(:@ping_idx, {})
    A3DPace.record(log)

    # Each ping is isolated from the previous one (its timer and the global gap cleared) so the only thing
    # deciding WHICH of the three sounds is the round-robin cursor.
    4.times do
      a3d.instance_variable_set(:@ptime, {})
      a3d.instance_variable_set(:@last_ping_any, nil)
      a3d.instance_variable_set(:@last_ping_pos, nil)
      a3d.ping_types
    end
    eq "the three alternate in order and wrap back to the first",
       A3DPace.played(log), [[4, 4], [4, 12], [12, 4], [4, 4]]
  ensure
    A3DPace.restore(saved)
  end
end

# Two cues landing on top of each other are unreadable, so a ping within PING_GAP of the last one is held
# back -- but ONLY if it is close to it. A far emitter still fires because HRTF panning already separates
# them, and that exception is what keeps the soundscape alive in a busy room. Three asserts: near waits,
# far fires, and the hold-back expires with the window rather than muting the tile for good.
Suite.define("audio3d: a ping beside the last one waits, a distant one fires anyway") do
  a3d = PokeAccess::Audio3D
  saved = A3DPace.snapshot
  prev_alt = PokeAccess::Config.audio3d_alt_dist
  log = []
  begin
    a3d.instance_variable_set(:@ch, A3DPace.channels)
    a3d.instance_variable_set(:@ping_idx, {})
    PokeAccess::Config.audio3d_alt_dist = 5
    A3DPace.record(log)

    a3d.instance_variable_set(:@emitters, { :npc => [[6, 5]] })
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@last_ping_any, PokeAccess.clock)
    a3d.instance_variable_set(:@last_ping_pos, [5, 5])
    a3d.ping_types
    eq "an emitter one tile from the last ping holds back", A3DPace.played(log), []

    log.clear
    a3d.instance_variable_set(:@emitters, { :npc => [[18, 18]] })
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@last_ping_any, PokeAccess.clock)
    a3d.instance_variable_set(:@last_ping_pos, [5, 5])
    a3d.ping_types
    eq "one across the room fires inside the same window", A3DPace.played(log), [[18, 18]]

    log.clear
    a3d.instance_variable_set(:@emitters, { :npc => [[6, 5]] })
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@last_ping_any, PokeAccess.clock - (a3d::PING_GAP * 4))
    a3d.instance_variable_set(:@last_ping_pos, [5, 5])
    a3d.ping_types
    eq "and once the window has passed the near one sounds too", A3DPace.played(log), [[6, 5]]

    # The hold-back radius is the player's own setting: shrink it and the same pair stops colliding.
    log.clear
    PokeAccess::Config.audio3d_alt_dist = 1
    a3d.instance_variable_set(:@emitters, { :npc => [[7, 5]] })
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@last_ping_any, PokeAccess.clock)
    a3d.instance_variable_set(:@last_ping_pos, [5, 5])
    a3d.ping_types
    eq "a tighter alternation distance lets a two-tile neighbour through", A3DPace.played(log), [[7, 5]]
  ensure
    PokeAccess::Config.audio3d_alt_dist = prev_alt
    A3DPace.restore(saved)
  end
end

# Occlude mode is the middle setting: an emitter behind a wall is MUFFLED, not deleted, so the player still
# knows it is there but hears that something is in the way. If the occlusion were left from the previous
# ping, a cue would stay muffled after the player steps into the open (or the reverse), so every ping sets
# it explicitly -- including back to 0.
Suite.define("audio3d: occlude mode muffles a ping behind a wall and clears it in the open") do
  a3d = PokeAccess::Audio3D
  saved = A3DPace.snapshot
  prev_occ = PokeAccess::Config.audio3d_occlusion
  log = []
  begin
    chans = A3DPace.channels
    a3d.instance_variable_set(:@ch, chans)
    $game_map.load_grid(["#########", "#@..#...#", "#########"])
    A3DPace.record(log)
    occ = lambda { log.select { |c, _a| c == :OCCL }.map { |_c, a| a[1] } }

    PokeAccess::Config.audio3d_occlusion = :occlude
    a3d.set_occlusion(chans[:npc], [6, 1])
    eq "a walled-off emitter is muffled", occ.call, [a3d::OCCLUDE_AMOUNT]
    log.clear
    a3d.set_occlusion(chans[:npc], [3, 1])
    eq "one in the open is explicitly cleared", occ.call, [0]

    log.clear
    PokeAccess::Config.audio3d_occlusion = :hear
    a3d.set_occlusion(chans[:npc], [6, 1])
    eq "hear mode never muffles anything", occ.call, [0]

    # And the ping path really does run it: the muffling would be dead code if ping_types skipped it.
    log.clear
    PokeAccess::Config.audio3d_occlusion = :occlude
    a3d.instance_variable_set(:@emitters, { :npc => [[6, 1]] })
    a3d.instance_variable_set(:@ptime, {})
    a3d.instance_variable_set(:@ping_idx, {})
    a3d.instance_variable_set(:@last_ping_any, nil)
    a3d.ping_types
    eq "a real ping behind the wall goes out muffled", occ.call, [a3d::OCCLUDE_AMOUNT]
    eq "and still sounds, at its tile", A3DPace.played(log), [[6, 1]]
  ensure
    PokeAccess::Config.audio3d_occlusion = prev_occ
    A3DPace.restore(saved)
    $game_map.clear_grid
  end
end

# The wind loops ARE the wall-proximity sense: their volume is the distance and their position is the side.
# A sign flip pans a wall to the wrong ear, a missing stop leaves wind blowing from an open corridor, and a
# broken falloff makes a wall two tiles away as loud as one you are touching -- which is the whole cue.
Suite.define("audio3d: wind volume falls off with distance and an open side is stopped") do
  a3d = PokeAccess::Audio3D
  saved = A3DPace.snapshot
  prev = [PokeAccess::Config.audio3d_wind, PokeAccess::Config.audio3d_wall_falloff,
          PokeAccess::Config.audio3d_wall_range]
  log = []
  begin
    chans = A3DPace.channels
    a3d.instance_variable_set(:@ch, chans)
    PokeAccess::Config.audio3d_wind = 60
    PokeAccess::Config.audio3d_wall_falloff = 50
    PokeAccess::Config.audio3d_wall_range = 3
    a3d.instance_variable_set(:@wall, { :w => 1, :e => 3, :n => nil, :s => 2 })
    A3DPace.record(log)

    a3d.set_winds(5, 5)
    by_ch = {}
    log.each { |c, a| by_ch[a[0]] = a if c == :SET }
    u = a3d::TILE_UNITS
    eq "the wall you are touching is placed one tile west, at full volume",
       by_ch[chans[:wind_w]], [chans[:wind_w], 4 * u, 5 * u, 60, 1]
    eq "a wall three tiles east is placed there and much quieter",
       by_ch[chans[:wind_e]], [chans[:wind_e], 8 * u, 5 * u, 20, 1]
    eq "two tiles south sits in between", by_ch[chans[:wind_s]], [chans[:wind_s], 5 * u, 7 * u, 30, 1]
    eq "and an open side is parked at the range limit and stopped",
       by_ch[chans[:wind_n]], [chans[:wind_n], 5 * u, 2 * u, 0, 0]

    # The falloff slider must actually steepen the curve, or the "narrow openings are audible" cue is flat.
    log.clear
    PokeAccess::Config.audio3d_wall_falloff = 100
    a3d.set_winds(5, 5)
    by_ch = {}
    log.each { |c, a| by_ch[a[0]] = a if c == :SET }
    eq "a steeper falloff drops the distant wall further", by_ch[chans[:wind_e]][3], 6
    eq "while the one you are touching is unaffected", by_ch[chans[:wind_w]][3], 60

    log.clear
    a3d.set_loop(:water, [7, 9], 44)
    a3d.set_loop(:wind_n, nil, 44)
    eq "a looping emitter is placed at its tile", log[0][1], [chans[:water], 7 * u, 9 * u, 44, 1]
    eq "and stopped, not just muted, when there is nothing to place",
       log[1][1], [chans[:wind_n], 0, 0, 0, 0]
  ensure
    PokeAccess::Config.audio3d_wind = prev[0]
    PokeAccess::Config.audio3d_wall_falloff = prev[1]
    PokeAccess::Config.audio3d_wall_range = prev[2]
    A3DPace.restore(saved)
  end
end

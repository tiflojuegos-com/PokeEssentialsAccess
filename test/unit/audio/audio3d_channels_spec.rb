# The lookup tables of the positional engine (core/audio/audio3d.rb) and the two file-facing helpers.
# Everything here is a table or a string: a hole in CHANNEL_FILES is a MUTE emitter (the classifier hands
# back a type the engine has no sound for and the tick simply skips it), a wrong loop flag is a wind that
# plays once and dies, and a wav() that stops preferring the 48000 set silently resamples every cue.
require "tmpdir"
require "fileutils"

# Every type the classifier can return must have a channel, a ping timer and a volume slider that actually
# moves it. The generic slider assert is the one that catches a NEW emitter type: type_vol rescues an
# unknown config key to a hardcoded 80, so a type wired without its slider would look fine in game and
# quietly ignore the player's volume settings forever.
Suite.define("audio3d: every emitter type has a channel, a ping timer and a live volume slider") do
  a3d = PokeAccess::Audio3D
  chan = {}
  a3d::CHANNEL_FILES.each { |sym, file, looping| chan[sym] = [file, looping] }
  eq "no channel symbol is declared twice", chan.length, a3d::CHANNEL_FILES.length

  # The sound vocabulary: keep in sync with type_of, whose classification suite proves it returns each one.
  eq "the ping table is exactly the classifier's vocabulary", a3d::PING_DEFS.keys.map { |k| k.to_s }.sort,
     %w[control door hazard npc object push teleporter trap]
  missing = a3d::PING_DEFS.keys.reject { |t| chan[t] }
  eq "no emitter type is left without a sound file", missing, []
  bad_freq = a3d::PING_DEFS.values.uniq.reject { |k| PokeAccess::Config.respond_to?(k) }
  eq "every ping timer names a real config key", bad_freq, []

  # Cues the footstep/bump/guide helpers look up by name: a missing entry makes them return false and the
  # cue silently falls back to flat non-positional stereo, which is exactly the bug the engine exists to fix.
  [:wall, :interact, :step, :grass, :fstep_water, :guide].each do |sym|
    truthy "the #{sym} cue has a channel", !chan[sym].nil?
  end

  loops = chan.keys.select { |k| chan[k][1] == 1 }.map { |k| k.to_s }.sort
  eq "only the ambience channels loop", loops, %w[water wind_e wind_n wind_s wind_w]
  one_shots = a3d::PING_DEFS.keys.select { |t| chan[t][1] == 1 }
  eq "no discrete ping is loaded as a loop", one_shots, []
end

# Volumes: the four object-family types deliberately share ONE slider (the config menu offers a single
# "objects" volume), while people/doors/teleporters/water have their own. Setting every slider to the same
# value proves no type falls through to the hardcoded 80; then moving one slider proves which types follow it.
Suite.define("audio3d: the volume sliders reach every emitter type, objects sharing one") do
  a3d = PokeAccess::Audio3D
  keys = [:audio3d_npc, :audio3d_object, :audio3d_door, :audio3d_teleporter, :audio3d_water]
  prev = {}
  begin
    keys.each { |k| prev[k] = PokeAccess::Config.send(k) }
    keys.each { |k| PokeAccess::Config.send("#{k}=", 11) }
    stuck = (a3d::PING_DEFS.keys + [:water]).reject { |t| a3d.type_vol(t) == 11 }
    eq "no type ignores its slider and falls back to the built-in default", stuck, []

    PokeAccess::Config.audio3d_object = 62
    follows = [:object, :hazard, :trap, :control, :push].reject { |t| a3d.type_vol(t) == 62 }
    eq "the object slider moves the whole object family", follows, []
    eq "people keep their own slider", a3d.type_vol(:npc), 11
    eq "and so do doors", a3d.type_vol(:door), 11
    eq "and teleporters", a3d.type_vol(:teleporter), 11
  ensure
    prev.each { |k, v| PokeAccess::Config.send("#{k}=", v) }
  end
end

# The four wind loops are placed by WIND_SIDES and raycast by SIDE_DIR. If the two tables ever disagree the
# engine measures the wall on one side and pans its sound to the other -- the worst possible failure for a
# player navigating by ear, and completely invisible to any test that only checks one table.
Suite.define("audio3d: the wind side tables agree with the engine's direction deltas") do
  a3d = PokeAccess::Audio3D
  eq "every wind side is a raycast side", a3d::WIND_SIDES.keys.map { |k| k.to_s }.sort,
     a3d::SIDE_DIR.keys.map { |k| k.to_s }.sort
  wrong = a3d::WIND_SIDES.reject do |side, info|
    a3d::DIR_DELTA[a3d::SIDE_DIR[side]] == [info[1], info[2]]
  end
  eq "each side's offset matches the direction it raycasts", wrong.keys, []
  chan = {}
  a3d::CHANNEL_FILES.each { |sym, _f, _l| chan[sym] = true }
  eq "and each has its own loop channel", a3d::WIND_SIDES.values.reject { |i| chan[i[0]] }, []
end

# wav() is the whole point of shipping two asset sets: the device opens at its native rate and the engine
# must hand it a file already at that rate, or every cue is resampled at runtime. The 48000 tree is looked
# up through a RELATIVE path, so the suite builds a throwaway sound tree in a temp dir and runs there --
# real File.exist?, no stubbing. load_ch is checked in the same place because the NUL terminator it appends
# is what makes the path readable as a C string by the dll; without it the dll gets a garbage filename.
Suite.define("audio3d: wav picks the rate-matched set, load_ch forwards it NUL-terminated") do
  a3d = PokeAccess::Audio3D
  prev_rate = a3d.instance_variable_get(:@rate)
  seen = []
  chan_sc = (class << a3d::CHAN; self; end)
  begin
    Dir.mktmpdir("pa3d_spec") do |tmp|
      snd = File.join(tmp, PokeAccess::Paths::SOUNDS)
      FileUtils.mkdir_p(File.join(snd, "48000"))
      ["pa3d_npc.wav", "pa3d_door.wav"].each { |n| File.open(File.join(snd, n), "w") { |f| f.write("x") } }
      File.open(File.join(snd, "48000", "pa3d_npc.wav"), "w") { |f| f.write("x") }

      Dir.chdir(tmp) do
        a3d.instance_variable_set(:@rate, 48000)
        eq "a 48000 device gets the 48000 copy", a3d.wav("pa3d_npc.wav"),
           "#{PokeAccess::Audio3D::SND48}/pa3d_npc.wav"
        eq "a cue with no 48000 copy falls back instead of naming a missing file",
           a3d.wav("pa3d_door.wav"), "#{PokeAccess::Audio3D::DIR}/pa3d_door.wav"
        a3d.instance_variable_set(:@rate, 44100)
        eq "a 44100 device never looks in the 48000 tree", a3d.wav("pa3d_npc.wav"),
           "#{PokeAccess::Audio3D::DIR}/pa3d_npc.wav"
        a3d.instance_variable_set(:@rate, nil)
        eq "and neither does a device whose rate is still unknown", a3d.wav("pa3d_npc.wav"),
           "#{PokeAccess::Audio3D::DIR}/pa3d_npc.wav"

        # The dll entry point is a Win32API object; here it is the harness stub, so replacing its #call
        # records exactly the bytes the real PA3D_Channel would receive.
        a3d::CHAN.define_singleton_method(:call) { |*a| seen.push(a); 7 }
        a3d.instance_variable_set(:@rate, 48000)
        eq "load_ch returns the channel handle the dll gave back", a3d.load_ch("pa3d_npc.wav", 1), 7
        eq "and passed it the rate-matched path, NUL-terminated",
           seen[0][0], "#{PokeAccess::Audio3D::SND48}/pa3d_npc.wav\0"
        eq "with the loop flag untouched", seen[0][1], 1
      end
    end

    # A missing wav must never abort boot: load_ch swallows the failure and reports "no channel" (-1),
    # which every play path checks with `ch >= 0`.
    chan_sc.send(:remove_method, :call)
    a3d::CHAN.define_singleton_method(:call) { |*_a| raise "no such file" }
    eq "a dll that rejects the file yields no channel instead of raising", a3d.load_ch("nope.wav", 0), -1
  ensure
    chan_sc.send(:remove_method, :call) if chan_sc.instance_methods(false).map { |m| m.to_s }.include?("call")
    a3d.instance_variable_set(:@rate, prev_rate)
  end
end

# gate_report is the only thing that can answer "why is the soundscape silent?" for a blind tester. If it
# invented a number for an empty window, or kept counting across windows, every diagnosis drawn from it
# would be wrong -- so it must say "no data" when there is none, rank the reasons, and reset each read.
Suite.define("audio3d: gate_report ranks why the tick fell silent and clears its window") do
  a3d = PokeAccess::Audio3D
  prev = a3d.instance_variable_get(:@gates)
  begin
    a3d.instance_variable_set(:@gates, nil)
    eq "an empty window says so instead of reporting 0/0", a3d.gate_report, "(sin datos)"

    a3d.instance_variable_set(:@gates, {})
    4.times { a3d.gate(:total) }
    a3d.gate(:playing)
    2.times { a3d.gate(:in_menu) }
    a3d.gate(:message)
    rep = a3d.gate_report
    match "it reports played out of total", rep, /\A1\/4 playing/
    match "most frequent reason first", rep, /by=in_menu:2 message:1/
    falsy "the frame total is not listed as a reason", rep.include?("total:")
    eq "and the window is cleared for the next read", a3d.gate_report, "(sin datos)"
  ensure
    a3d.instance_variable_set(:@gates, prev)
  end
end

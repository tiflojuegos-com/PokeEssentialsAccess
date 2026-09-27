# The positional engine's lookup tables (core/audio/audio3d.rb) and its two file-facing helpers, wav and load_ch.
require "tmpdir"
require "fileutils"

# Every emitter type has a channel and a ping timer on a real config key, the named cues exist, and only the
# ambience and the guide's held tone loop.
Suite.define("audio3d: every emitter type has a channel, a ping timer and a live volume slider") do
  a3d = PokeAccess::Audio3D
  chan = {}
  a3d::CHANNEL_FILES.each { |sym, file, looping| chan[sym] = [file, looping] }
  eq "no channel symbol is declared twice", chan.length, a3d::CHANNEL_FILES.length

  eq "the ping table is the classifier's vocabulary plus the marker tiles", a3d::PING_DEFS.keys.map { |k| k.to_s }.sort,
     %w[control door hazard mark npc object push teleporter trap]
  missing = a3d::PING_DEFS.keys.reject { |t| chan[t] }
  eq "no emitter type is left without a sound file", missing, []
  bad_freq = a3d::PING_DEFS.values.uniq.reject { |k| PokeAccess::Config.respond_to?(k) }
  eq "every ping timer names a real config key", bad_freq, []

  [:wall, :interact, :step, :grass, :fstep_water, :guide, :guide_hold].each do |sym|
    truthy "the #{sym} cue has a channel", !chan[sym].nil?
  end

  loops = chan.keys.select { |k| chan[k][1] == 1 }.map { |k| k.to_s }.sort
  eq "only the ambience channels and the guide's held tone loop", loops, %w[guide_hold water wind_e wind_n wind_s wind_w]
  one_shots = a3d::PING_DEFS.keys.select { |t| chan[t][1] == 1 }
  eq "no discrete ping is loaded as a loop", one_shots, []
end

# Each emitter type follows a volume slider, never type_vol's default; the object family shares the objects slider.
Suite.define("audio3d: the volume sliders reach every emitter type, objects sharing one") do
  a3d = PokeAccess::Audio3D
  keys = [:audio3d_npc, :audio3d_object, :audio3d_door, :audio3d_teleporter, :audio3d_mark, :audio3d_water]
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
    eq "and markers", a3d.type_vol(:mark), 11
  ensure
    prev.each { |k, v| PokeAccess::Config.send("#{k}=", v) }
  end
end

# WIND_SIDES (where each wind loop sounds) and SIDE_DIR (where its wall is raycast) agree side by side.
Suite.define("audio3d: the wind side tables agree with the engine's direction deltas") do
  a3d = PokeAccess::Audio3D
  eq "every wind side is a raycast side", a3d::WIND_SIDES.keys.map { |k| k.to_s }.sort,
     a3d::SIDE_DIR.keys.map { |k| k.to_s }.sort
  wrong = a3d::WIND_SIDES.reject do |side, info|
    PokeAccess::DIR_DELTA[a3d::SIDE_DIR[side]] == [info[1], info[2]]
  end
  eq "each side's offset matches the direction it raycasts", wrong.keys, []
  chan = {}
  a3d::CHANNEL_FILES.each { |sym, _f, _l| chan[sym] = true }
  eq "and each has its own loop channel", a3d::WIND_SIDES.values.reject { |i| chan[i[0]] }, []
end

# wav picks the copy at the device's rate (the 48000 tree, by a relative path, so the suite runs in a temp sound
# tree); load_ch passes it NUL-terminated, as the dll reads a C string, and a rejected file yields -1.
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

        a3d::CHAN.define_singleton_method(:call) { |*a| seen.push(a); 7 }
        a3d.instance_variable_set(:@rate, 48000)
        eq "load_ch returns the channel handle the dll gave back", a3d.load_ch("pa3d_npc.wav", 1), 7
        eq "and passed it the rate-matched path, NUL-terminated",
           seen[0][0], "#{PokeAccess::Audio3D::SND48}/pa3d_npc.wav\0"
        eq "with the loop flag untouched", seen[0][1], 1
      end
    end

    chan_sc.send(:remove_method, :call)
    a3d::CHAN.define_singleton_method(:call) { |*_a| raise "no such file" }
    eq "a dll that rejects the file yields no channel instead of raising", a3d.load_ch("nope.wav", 0), -1
  ensure
    chan_sc.send(:remove_method, :call) if chan_sc.instance_methods(false).map { |m| m.to_s }.include?("call")
    a3d.instance_variable_set(:@rate, prev_rate)
  end
end

# gate_report says why the tick fell silent: no data for an empty window, reasons ranked, cleared on each read.
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

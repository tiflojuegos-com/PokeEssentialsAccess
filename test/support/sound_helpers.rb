# A stand-in for PA3D_steam.dll (Sound::Native.shadow): it answers as the dll does (init 1, the channels numbered in
# load order from 0, the device's rate) and records every other call as [name, args]; the entry points named missing
# are not there, as in an older dll.
class SoundShadow
  attr_reader :log, :loaded

  def initialize(rate = 44100, missing = [])
    @log = []
    @loaded = []
    @rate = rate
    @n = -1
    @missing = missing
  end

  def has?(name); !@missing.include?(name); end

  def call(name, *args)
    return nil if @missing.include?(name)
    case name
    when :init then 1
    when :channel
      @loaded.push(args)
      (@n += 1)
    when :rate then @rate
    when :latency then 20
    else
      @log.push([name, args])
      nil
    end
  end

  # Each channel's sound, from the engine's table.
  def ids
    h = {}
    PokeAccess::Sound::Pa3d.channels.each { |id, n| h[n] = id }
    h
  end

  # The sounds started or placed (a set with play on), as [sound, x tile, y tile, volume], in order.
  def played
    u = PokeAccess::Sound::Pa3d::TILE_UNITS
    map = ids
    @log.select { |n, a| n == :set && a[4] == 1 }.map { |_n, a| [map[a[0]], a[1] / u, a[2] / u, a[3]] }
  end

  # The tiles played, in order.
  def tiles; played.map { |_id, x, y, _v| [x, y] }; end

  # Each sound's last order in the log: 1 playing, 0 stopped (none for a sound never ordered).
  def states
    map = ids
    out = {}
    @log.each { |n, a| out[map[a[0]]] = a[4] if n == :set }
    out
  end

  # The sounds stopped (a set with play off), in order.
  def stopped
    map = ids
    @log.select { |n, a| n == :set && a[4] == 0 }.map { |_n, a| map[a[0]] }
  end

  # The calls to an entry point that takes a channel first (:pitch, :occl), as [sound, value].
  def by_sound(name)
    map = ids
    @log.select { |n, _a| n == name }.map { |_n, a| [map[a[0]], a[1]] }
  end

  # The calls to an entry point, as their arguments.
  def args(name); @log.select { |n, _a| n == name }.map { |_n, a| a }; end
end

# Runs a block with the sound engine or the soundscape booted over the shadow backend.
module SoundHelpers
  # Runs the block with the positional engine on a fresh SoundShadow (yielded) missing the entry points named, booted
  # unless boot is false; the engine's boot state and what it sent are put back after.
  def with_sound_engine(boot = true, rate = 44100, missing = [])
    pa = PokeAccess::Sound::Pa3d
    keys = [:@ready, :@boot_tried, :@ch, :@rate, :@latency]
    saved = keys.map { |k| pa.instance_variable_get(k) }
    shadow = SoundShadow.new(rate, missing)
    PokeAccess::Sound::Native.shadow = shadow
    pa.instance_variable_set(:@ready, false)
    pa.instance_variable_set(:@boot_tried, false)
    pa.instance_variable_set(:@ch, {})
    pa.forget
    pa.boot if boot
    shadow.log.clear
    yield shadow
  ensure
    PokeAccess::Sound::Native.shadow = nil
    keys.each_with_index { |k, i| pa.instance_variable_set(k, saved[i]) }
    pa.forget
  end

  # Runs the block with the soundscape's timers and scene cleared, both put back after.
  def with_soundscape
    sch = PokeAccess::Sound::Scheduler
    sc = PokeAccess::Sound::Scene
    ivs = [:@active, :@scan_pos, :@ptime, :@ping_idx, :@last_ping_any, :@last_ping_pos, :@shore_time, :@mover_time,
           :@basic_silenced]
    saved = ivs.map { |k| sch.instance_variable_get(k) }
    scene = [:@emitters, :@wall, :@water, :@shore, :@watch].map { |k| sc.instance_variable_get(k) }
    { :@ptime => {}, :@ping_idx => {}, :@last_ping_any => nil, :@last_ping_pos => nil, :@shore_time => nil,
      :@scan_pos => nil, :@mover_time => nil }.each { |k, v| sch.instance_variable_set(k, v) }
    sc.forget
    yield sch, sc
  ensure
    ivs.each_with_index { |k, i| sch.instance_variable_set(k, saved[i]) }
    [:@emitters, :@wall, :@water, :@shore, :@watch].each_with_index { |k, i| sc.instance_variable_set(k, scene[i]) }
  end
end

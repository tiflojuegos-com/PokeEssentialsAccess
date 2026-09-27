# PokeAccess.clock, which paces every cue, runs on wall time: a lying System.uptime or a rewritten frame_count cannot
# move it. The fakes are installed inside each suite and removed in ensure.

# Runs the block under a System.uptime that jumps a million per read, removing System after if it had to create it.
def with_lying_uptime
  had = Object.const_defined?(:System)
  mod = had ? System : Object.const_set(:System, Module.new)
  fake = [0.0]
  mod.define_singleton_method(:uptime) { fake[0] += 1_000_000.0 }
  yield
ensure
  mod.singleton_class.send(:remove_method, :uptime)
  Object.send(:remove_const, :System) unless had
end

# Runs the block under a Graphics.frame_count that leaps half a million per read, then removes it.
def with_lying_frame_count
  fake = [0]
  Graphics.define_singleton_method(:frame_count) { fake[0] += 500_000 }
  yield
ensure
  Graphics.singleton_class.send(:remove_method, :frame_count)
end

Suite.define("clock: a lying System.uptime cannot make the clock run away") do
  with_lying_uptime do
    a = PokeAccess.clock
    b = PokeAccess.clock
    truthy "two reads taken back to back stay within a few milliseconds", (b - a) < 0.5
    truthy "even though System.uptime jumped a million between them", (System.uptime - System.uptime).abs >= 1_000_000.0
  end
end

Suite.define("clock: a rewritten frame_count cannot make the clock jump") do
  with_lying_frame_count do
    a = PokeAccess.clock
    Graphics.frame_count
    Graphics.frame_count
    b = PokeAccess.clock
    truthy "half a million frames later the clock has barely moved", (b - a) < 0.5
  end
end

Suite.define("clock: it moves forward, and in seconds") do
  a = PokeAccess.clock
  t0 = Time.now
  sleep 0.05
  b = PokeAccess.clock
  elapsed = Time.now - t0
  truthy "it advanced", b > a
  truthy "by about the wall time that passed, in seconds", ((b - a) - elapsed).abs < 0.05
end

Suite.define("clock: freq_to_seconds still reads the tunables as gen-6 frames") do
  eq "the fastest setting is 6 frames -> 0.15 s", PokeAccess.freq_to_seconds(100), 6 / PokeAccess::FPS
  truthy "the slowest setting is well over a second", PokeAccess.freq_to_seconds(0) > 1.0
end

# uptime_scale measures the System.uptime units per second (for the Bug Contest timer); the epoch is rewound so the
# measurement window (at least 1 s of wall time) is already open.
Suite.define("clock: the System.uptime scale is measured, not assumed") do
  with_lying_uptime do
    prev = [:@epoch, :@uptime0, :@uptime_scale].map { |s| PokeAccess.instance_variable_get(s) }
    begin
      PokeAccess.instance_variable_set(:@epoch, Time.now - 2.0)
      PokeAccess.instance_variable_set(:@uptime0, System.uptime)
      PokeAccess.instance_variable_set(:@uptime_scale, nil)
      scale = PokeAccess.uptime_scale
      truthy "a microsecond uptime is detected as such, not taken for seconds", !scale.nil? && scale > 1000.0
    ensure
      PokeAccess.instance_variable_set(:@epoch, prev[0])
      PokeAccess.instance_variable_set(:@uptime0, prev[1])
      PokeAccess.instance_variable_set(:@uptime_scale, prev[2])
    end
  end
end

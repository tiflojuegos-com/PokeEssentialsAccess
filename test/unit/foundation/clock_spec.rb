# PokeAccess.clock, the single source every cue cadence is paced by (spatial pings, the guide chime, the
# bump cooldown, the profiler). It used to read System.uptime when the runtime offered it and fall back to
# Graphics.frame_count / 40, and BOTH branches turned out to be forgeable by the host game:
#
#   - Infinite Fusion's mkxp-z exposes a System.uptime that does not count seconds. Every interval was
#     therefore already met on the next frame and the whole soundscape fired at frame rate. Its second
#     executable (Game-performance.exe) has no System.uptime at all and sounded correct, which is what
#     identified the branch.
#   - frame_count only tracks real time while the game holds its nominal rate, and Essentials rewrites it
#     outright when a save is loaded, which yanks the clock sideways.
#
# The fakes below deliberately lie the way that runtime does; the clock must ignore them both and stay on
# wall time. Each fake is installed INSIDE its suite and removed in ensure, restoring the base engine stubs
# (which define neither System nor Graphics.frame_count), so no other suite ever runs under a lying source.

# Runs the block under a System.uptime that jumps a million per read (the microsecond mkxp-z build), then
# removes the fake, dropping the System module entirely when this helper had to create it.
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

# Runs the block under a Graphics.frame_count that leaps half a million per read (a save-load rewrite at
# frame-rate scale), then removes the fake, restoring the base stub's Graphics.
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

# Anything comparing two of the ENGINE's own uptime stamps (the Bug Contest timer is the one case) still
# has to know the units, so the scale is measured instead of assumed. The lying uptime stands in for the
# microsecond clock that made every contest read "0:00". The clock's memoized epoch is rewound so the
# measurement window (>= 1 s of wall time) is already open, and every touched ivar is restored in ensure,
# leaving the memoized clock exactly as the suite found it.
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

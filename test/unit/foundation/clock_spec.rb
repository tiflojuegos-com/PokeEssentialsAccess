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
# These stubs deliberately lie the way that runtime does; the clock must ignore them both and stay on wall
# time. Defined after the stub engines load, so nothing else in the suite has to know about them.
module System
  def self.uptime
    @fake = (@fake || 0) + 1_000_000.0
    @fake
  end
end

module Graphics
  def self.frame_count
    @fake_fc = (@fake_fc || 0) + 500_000
    @fake_fc
  end
end

Suite.define("clock: a lying System.uptime cannot make the clock run away") do
  a = PokeAccess.clock
  b = PokeAccess.clock
  truthy "two reads taken back to back stay within a few milliseconds", (b - a) < 0.5
  truthy "even though System.uptime jumped a million between them", (System.uptime - System.uptime).abs >= 1_000_000.0
end

Suite.define("clock: a rewritten frame_count cannot make the clock jump") do
  a = PokeAccess.clock
  Graphics.frame_count
  Graphics.frame_count
  b = PokeAccess.clock
  truthy "half a million frames later the clock has barely moved", (b - a) < 0.5
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
# has to know the units, so the scale is measured instead of assumed. The stub above advances a million per
# read, standing in for the microsecond clock that made every contest read "0:00".
Suite.define("clock: the System.uptime scale is measured, not assumed") do
  scale = PokeAccess.uptime_scale
  truthy "a microsecond uptime is detected as such, not taken for seconds", scale.nil? || scale > 1000.0
end

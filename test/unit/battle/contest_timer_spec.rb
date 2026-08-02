# The timed-contest clock (Battle.contest_time_left), the one reader that compares two of the ENGINE's own
# timestamps instead of the mod's wall clock -- and therefore the one place where the engine's units matter.
# It forks:
#
#   - MODERN (mkxp-z): a System.uptime stamp against BugContestState::TIME_ALLOWED. Some forks ship an
#     mkxp-z whose uptime counts MICROSECONDS, which made the elapsed figure a million times too big and
#     every Bug Contest read "0:00" from the first second. The fix divides by the measured uptime scale, so
#     the suite below runs the same microsecond numbers through both scales and pins that only the scaled
#     one survives.
#   - GEN-6: a Graphics.frame_count stamp against BugContestState::TimerSeconds, divided by the frame rate.
#
# Which fork runs is decided by the STATE object (does it carry timer_start?), not by the engine name, so
# that choice is pinned too -- with both clocks present and both constants set to different lengths, so the
# assertion can only pass for the intended branch. Every fake is installed inside its suite and removed in
# ensure (the base gen-6 stub defines neither System nor Graphics.frame_count), so nothing leaks out.

# Runs the block with a BugContestState module carrying exactly the given constants, restoring (or removing)
# whatever was there, so no other suite ever sees a contest running.
def with_contest_consts(consts)
  prev = (Object.const_defined?(:BugContestState) ? Object.const_get(:BugContestState) : nil)
  Object.send(:remove_const, :BugContestState) if prev
  m = Module.new
  consts.each { |k, v| m.const_set(k, v) }
  Object.const_set(:BugContestState, m)
  yield
ensure
  Object.send(:remove_const, :BugContestState) if Object.const_defined?(:BugContestState)
  Object.const_set(:BugContestState, prev) if prev
end

# Runs the block under a System.uptime frozen at value, dropping the System module again when this helper
# had to create it (the gen-6 stub has none).
def with_fake_uptime(value)
  had = Object.const_defined?(:System)
  mod = had ? System : Object.const_set(:System, Module.new)
  mod.define_singleton_method(:uptime) { value }
  yield
ensure
  mod.singleton_class.send(:remove_method, :uptime)
  Object.send(:remove_const, :System) unless had
end

# Runs the block under a Graphics.frame_count frozen at value, then removes it (the base stub defines the
# frame RATE but no counter, which is what lets the "no counter at all" case be tested).
def with_fake_frame_count(value)
  Graphics.define_singleton_method(:frame_count) { value }
  yield
ensure
  Graphics.singleton_class.send(:remove_method, :frame_count)
end

# Runs the block with the clock's uptime memo pinned (scale = uptime units per real second, boot = the
# stamp taken at load), restoring both so the real clock keeps whatever it had measured.
def with_uptime_memo(scale, boot)
  keys = [:@uptime_scale, :@uptime0]
  prev = keys.map { |k| PokeAccess.instance_variable_get(k) }
  PokeAccess.instance_variable_set(:@uptime_scale, scale)
  PokeAccess.instance_variable_set(:@uptime0, boot)
  yield
ensure
  keys.each_index { |i| PokeAccess.instance_variable_set(keys[i], prev[i]) }
end

# A contest state as the modern engine keeps it: only an uptime stamp.
def uptime_state(stamp)
  s = Object.new
  s.define_singleton_method(:timer_start) { stamp }
  s
end

# A contest state as gen-6 keeps it: only a frame-count stamp.
def frame_state(stamp)
  s = Object.new
  s.define_singleton_method(:timer) { stamp }
  s
end

Suite.define("contest timer: the modern branch counts seconds off the uptime stamp") do
  b = PokeAccess::Battle
  with_contest_consts(:TIME_ALLOWED => 1200) do
    with_uptime_memo(1.0, 0.0) do
      with_fake_uptime(160.0) do
        eq "sixty seconds into a twenty-minute contest, 19 minutes are left",
           b.contest_time_left(uptime_state(100.0)), 1140
        eq "which is what the player hears", b.fmt_mmss(b.contest_time_left(uptime_state(100.0))), "19:00"
        eq "a later start means more time left", b.contest_time_left(uptime_state(150.0)), 1190
        eq "and an overrun clamps at zero instead of going negative",
           b.contest_time_left(uptime_state(-2000.0)), 0
      end
    end
  end

  with_contest_consts(:TIME_ALLOWED => 0) do
    with_uptime_memo(1.0, 0.0) do
      with_fake_uptime(160.0) do
        truthy "a contest with no declared length reads nil, not a bogus number",
               b.contest_time_left(uptime_state(100.0)).nil?
      end
    end
  end
end

Suite.define("contest timer: a microsecond uptime is divided by the measured scale, not taken for seconds") do
  b = PokeAccess::Battle
  # The very numbers the microsecond mkxp-z reports: a contest started 60 real seconds ago.
  state = uptime_state(100_000_000.0)
  with_contest_consts(:TIME_ALLOWED => 1200) do
    with_fake_uptime(160_000_000.0) do
      with_uptime_memo(1.0, 0.0) do
        eq "read as seconds, a minute in already looks like a million: the 0:00 bug",
           b.fmt_mmss(b.contest_time_left(state)), "0:00"
      end
      with_uptime_memo(1_000_000.0, 0.0) do
        eq "divided by the measured microsecond scale it is the real time left",
           b.contest_time_left(state), 1140
        eq "and the player hears 19:00, not 0:00", b.fmt_mmss(b.contest_time_left(state)), "19:00"
      end
    end
    # Same clock, seconds this time, with nothing measured yet: the reader must fall back to 1.0 rather
    # than divide by nil. (Fakes are never nested -- the inner ensure would strip the outer's uptime.)
    with_fake_uptime(160.0) do
      with_uptime_memo(nil, nil) do
        eq "with no scale measurable yet the uptime is taken as seconds (the safe default)",
           b.contest_time_left(uptime_state(100.0)), 1140
      end
    end
  end
end

Suite.define("contest timer: the gen-6 branch counts frames off the frame counter") do
  b = PokeAccess::Battle
  with_contest_consts(:TimerSeconds => 1200) do
    with_fake_frame_count(4000) do
      eq "2400 frames at 40 fps is one minute gone", b.contest_time_left(frame_state(1600)), 1140
      eq "a later start means fewer frames elapsed", b.contest_time_left(frame_state(2400)), 1160
      eq "and an overrun clamps at zero", b.contest_time_left(frame_state(-1_000_000)), 0
    end
    truthy "an engine with no frame counter goes quiet instead of raising",
           b.contest_time_left(frame_state(1600)).nil?
  end

  with_contest_consts(:TimerSeconds => 0) do
    with_fake_frame_count(4000) do
      truthy "a contest with no declared length reads nil here too",
             b.contest_time_left(frame_state(1600)).nil?
    end
    truthy "and a state carrying no stamp at all reads nil", b.contest_time_left(Object.new).nil?
  end
end

Suite.define("contest timer: the state's own stamp picks the branch, not the engine") do
  b = PokeAccess::Battle
  # Both stamps present, and the two lengths differ so the answer names the branch that ran:
  # the uptime branch gives 1200-60 = 1140, the frame branch 600-60 = 540.
  both = Object.new
  both.define_singleton_method(:timer_start) { 100.0 }
  both.define_singleton_method(:timer) { 1600 }

  with_contest_consts(:TIME_ALLOWED => 1200, :TimerSeconds => 600) do
    with_fake_frame_count(4000) do
      with_fake_uptime(160.0) do
        with_uptime_memo(1.0, 0.0) do
          eq "with an uptime clock AND a timer_start, the modern branch wins",
             b.contest_time_left(both), 1140
          eq "but a state with only a frame stamp falls back to the counter",
             b.contest_time_left(frame_state(1600)), 540
        end
      end
      falsy "the base gen-6 stub really has no System to read", Object.const_defined?(:System)
      eq "so with no uptime clock at all, even a both-stamp state uses the frame counter",
         b.contest_time_left(both), 540
    end
  end
end

Suite.define("contest timer: the remaining seconds are spoken as m:ss") do
  b = PokeAccess::Battle
  eq "whole minutes", b.fmt_mmss(1140), "19:00"
  eq "seconds are zero padded", b.fmt_mmss(65), "1:05"
  eq "under a minute keeps the leading zero minute", b.fmt_mmss(9), "0:09"
  eq "an exhausted timer is 0:00", b.fmt_mmss(0), "0:00"
end

# The Bug Contest's clock (Battle.contest_time_left): whole seconds left from the state's own stamp, uptime over the
# measured scale (v21) or frames over the frame rate (earlier), and the contest's balls and m:ss in the field report.
class ContestTimerTest < PokeAccessTest
  Battle = PokeAccess::Battle
  T = PokeAccess::I18n
  # A contest state stamped as v21 stamps it (System.uptime), as earlier engines do (Graphics.frame_count), or both.
  UptimeState = Struct.new(:timer_start)
  FrameState = Struct.new(:timer)
  BothStamps = Struct.new(:timer_start, :timer)
  # A contest as pbBugContestState answers it: whether it runs, the balls left and its frame-count stamp.
  Contest = Struct.new(:running, :ballcount, :timer) do
    def inProgress?
      running
    end
  end
  # A contest whose state cannot tell whether it runs.
  UnsureContest = Struct.new(:ballcount, :timer) do
    def inProgress?
      raise "no contest data"
    end
  end

  test "counts the seconds left off the uptime stamp" do
    on_uptime(160.0, :TIME_ALLOWED => 1200) do
      { 100.0 => 1140, 150.0 => 1190, 160.0 => 1200 }.each do |stamp, left|
        assert_equal left, Battle.contest_time_left(UptimeState.new(stamp)), "stamped at #{stamp}"
      end
    end
  end

  test "truncates the time left to whole seconds" do
    on_uptime(160.5, :TIME_ALLOWED => 1200) do
      assert_equal 1139, Battle.contest_time_left(UptimeState.new(100.0)), "60.5 seconds gone"
    end
  end

  test "divides a microsecond uptime by the measured scale" do
    on_uptime(160_000_000.0, { :TIME_ALLOWED => 1200 }, 1_000_000.0) do
      assert_equal 1140, Battle.contest_time_left(UptimeState.new(100_000_000.0)), "sixty million units, a minute"
    end
  end

  test "takes the uptime for seconds while no scale is measured" do
    on_uptime(160.0, { :TIME_ALLOWED => 1200 }, nil) do
      assert_equal 1140, Battle.contest_time_left(UptimeState.new(100.0))
    end
  end

  test "counts the seconds left off the frame stamp at the engine's frame rate" do
    on_frames(4000, :TimerSeconds => 1200) do
      { [40, 1600] => 1140, [40, 2400] => 1160, [60, 1600] => 1160 }.each do |(fps, stamp), left|
        with_graphics(:frame_rate, fps) do
          assert_equal left, Battle.contest_time_left(FrameState.new(stamp)), "stamped at #{stamp}, #{fps} a second"
        end
      end
    end
  end

  test "counts at the mod's own frame rate on an engine that does not tell its own" do
    on_frames(4000, :TimerSeconds => 1200) do
      with_graphics(:frame_rate, nil) do
        assert_equal 1140, Battle.contest_time_left(FrameState.new(1600)), "2400 frames at 40 a second"
      end
    end
  end

  test "counts a v20 contest's frames against the TIME_ALLOWED it declares" do
    on_frames(4000, :TIME_ALLOWED => 1200) do
      assert_equal 1140, Battle.contest_time_left(FrameState.new(1600)), "2400 frames at 40 a second"
    end
  end

  test "clamps an overrun contest at zero on either clock" do
    on_uptime(160.0, :TIME_ALLOWED => 1200) do
      assert_equal 0, Battle.contest_time_left(UptimeState.new(-2000.0)), "uptime"
    end
    on_frames(4000, :TimerSeconds => 1200) do
      assert_equal 0, Battle.contest_time_left(FrameState.new(-1_000_000)), "frames"
    end
  end

  test "has the whole second left of a one-second contest just begun" do
    on_uptime(160.0, :TIME_ALLOWED => 1) { assert_equal 1, Battle.contest_time_left(UptimeState.new(160.0)), "uptime" }
    on_frames(4000, :TimerSeconds => 1) { assert_equal 1, Battle.contest_time_left(FrameState.new(4000)), "frames" }
  end

  test "has no time to tell for a contest that declares no length" do
    [{}, { :TIME_ALLOWED => 0 }].each do |rules|
      on_uptime(160.0, rules) do
        assert_nil Battle.contest_time_left(UptimeState.new(100.0)), "uptime stamp, #{rules.inspect}"
      end
    end
    [{}, { :TimerSeconds => 0 }].each do |rules|
      on_frames(4000, rules) do
        assert_nil Battle.contest_time_left(FrameState.new(1600)), "frame stamp, #{rules.inspect}"
      end
    end
  end

  test "goes quiet on an engine with no frame counter" do
    with_contest_length(:TimerSeconds => 1200) do
      with_graphics(:frame_count, nil) { assert_nil Battle.contest_time_left(FrameState.new(1600)) }
    end
  end

  test "reads no time from a state that carries no stamp" do
    on_frames(4000, :TimerSeconds => 1200) { assert_nil Battle.contest_time_left(Object.new) }
  end

  test "follows the uptime stamp of a state that has one, on an engine that keeps uptime" do
    on_both_clocks { assert_equal 1140, Battle.contest_time_left(BothStamps.new(100.0, 1600)) }
  end

  test "falls back to the frame stamp of a state that has no uptime one" do
    on_both_clocks { assert_equal 540, Battle.contest_time_left(FrameState.new(1600)) }
  end

  test "counts frames on an engine without an uptime clock, whatever stamps the state carries" do
    { "no System" => nil, "a System without uptime" => Module.new }.each do |engine, system|
      on_both_clocks do
        with_constant(:System, system) do
          assert_equal 540, Battle.contest_time_left(BothStamps.new(100.0, 1600)), engine
        end
      end
    end
  end

  test "says the seconds left as minutes and zero-padded seconds" do
    { 1140 => "19:00", 125 => "2:05", 65 => "1:05", 9 => "0:09", 0 => "0:00", 3600 => "60:00" }.each do |secs, said|
      assert_equal said, Battle.fmt_mmss(secs), "for #{secs} seconds"
    end
  end

  test "reports a running contest's balls and time left" do
    on_frames(4000, :TimerSeconds => 1200) do
      with_contest(Contest.new(true, 15, 1600)) do
        assert_equal [T.t(:contest_balls, :n => 15), T.t(:contest_time, :t => "19:00")].join(", "),
                     Battle.field_event_text
      end
    end
  end

  test "leaves the time out of the report for a contest without a limit" do
    on_frames(4000, :TimerSeconds => 0) do
      with_contest(Contest.new(true, 15, 1600)) { assert_equal T.t(:contest_balls, :n => 15), Battle.field_event_text }
    end
  end

  test "leaves the balls out of the report for a contest that counts none" do
    on_frames(4000, :TimerSeconds => 1200) do
      with_contest(Contest.new(true, nil, 1600)) do
        assert_equal T.t(:contest_time, :t => "19:00"), Battle.field_event_text
      end
    end
  end

  test "reports nothing for a running contest with neither balls nor a limit to tell" do
    on_frames(4000, :TimerSeconds => 0) do
      with_contest(Contest.new(true, nil, 1600)) { assert_nil Battle.field_event_text }
    end
  end

  test "reports nothing for a contest that is not running or cannot tell whether it is" do
    on_frames(4000, :TimerSeconds => 1200) do
      [Contest.new(false, 15, 1600), UnsureContest.new(15, 1600)].each do |contest|
        with_contest(contest) { assert_nil Battle.field_event_text, contest.class.name }
      end
    end
  end

  private

  # Runs the block with System.uptime frozen at now, BugContestState declaring rules (constant => value) and the
  # clock's uptime scale pinned to scale (nil: none measured yet).
  def on_uptime(now, rules, scale = 1.0)
    with_constant(:System, uptime_clock(now)) do
      with_contest_length(rules) { with_uptime_scale(scale) { yield } }
    end
  end

  # Runs the block with Graphics.frame_count frozen at count and BugContestState declaring rules.
  def on_frames(count, rules)
    with_graphics(:frame_count, count) { with_contest_length(rules) { yield } }
  end

  # Runs the block on an engine keeping both clocks (uptime 160, frame 4000 at 40 a second, both a minute past the
  # states' stamps) under a contest of 1200 seconds by TIME_ALLOWED and 600 by TimerSeconds: 1140 left means the
  # uptime stamp was read, 540 the frame one.
  def on_both_clocks
    on_uptime(160.0, :TIME_ALLOWED => 1200, :TimerSeconds => 600) { with_graphics(:frame_count, 4000) { yield } }
  end

  # A System module whose uptime stays at now.
  def uptime_clock(now)
    clock = Module.new
    clock.define_singleton_method(:uptime) { now }
    clock
  end

  # Runs the block with BugContestState declaring exactly rules (constant => value).
  def with_contest_length(rules)
    contest = Module.new
    rules.each { |name, value| contest.const_set(name, value) }
    with_constant(:BugContestState, contest) { yield }
  end

  # Runs the block with pbBugContestState answering state.
  def with_contest(state)
    GameFunctions.with(:pbBugContestState => lambda { state }) { yield }
  end

  # Runs the block with the clock's uptime scale (uptime units per real second) pinned to scale, or for nil to none
  # measurable, as on an engine that had no uptime when the mod loaded; the clock's state is put back after.
  def with_uptime_scale(scale)
    keys = [:@uptime_scale, :@uptime0, :@epoch]
    was = keys.map { |k| PokeAccess.instance_variable_get(k) }
    PokeAccess.instance_variable_set(:@uptime_scale, scale)
    PokeAccess.instance_variable_set(:@uptime0, nil) if scale.nil?
    yield
  ensure
    keys.each_with_index { |k, i| PokeAccess.instance_variable_set(k, was[i]) }
  end

  # Runs the block with Graphics.name answering value, or missing for nil, then puts back the engine's own or none.
  def with_graphics(name, value)
    own = Graphics.singleton_methods(false).include?(name) ? Graphics.method(name) : nil
    Graphics.singleton_class.send(:remove_method, name) if own
    Graphics.define_singleton_method(name) { value } unless value.nil?
    yield
  ensure
    Graphics.singleton_class.send(:remove_method, name) if Graphics.singleton_methods(false).include?(name)
    Graphics.define_singleton_method(name, own) if own
  end

  # Runs the block with the top-level constant name set to value, or missing for nil, then puts back what was there.
  def with_constant(name, value)
    had = Object.const_defined?(name, false)
    was = had ? Object.send(:remove_const, name) : nil
    Object.const_set(name, value) unless value.nil?
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, was) if had
  end
end

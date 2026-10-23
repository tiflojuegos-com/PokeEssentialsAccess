# PokeAccess.clock paces every cue in wall-clock seconds whatever the engine's clocks say; uptime_scale measures
# System.uptime's units against it, and freq_to_seconds turns a 0-100 frequency into the seconds between cues.
class ClockTest < PokeAccessTest
  STATE = [:@epoch, :@uptime0, :@uptime_scale].freeze

  test "counts the seconds of wall time since it started" do
    clock_started(2.0, nil) { assert_in_delta 2.0, PokeAccess.clock, 0.25 }
  end

  test "starts at zero on its first read" do
    clock_started(nil, nil) { assert_in_delta 0.0, PokeAccess.clock, 0.25 }
  end

  test "is not moved by a System.uptime that leaps between two reads" do
    uptime = [0.0]
    with_uptime(lambda { uptime[0] }) do
      clock_started(1.0, nil) do
        before = PokeAccess.clock
        uptime[0] += 1_000_000.0
        assert_operator PokeAccess.clock - before, :<, 0.5
      end
    end
  end

  test "is not moved by a Graphics.frame_count that leaps between two reads" do
    frames = [0]
    with_frame_count(lambda { frames[0] }) do
      clock_started(1.0, nil) do
        before = PokeAccess.clock
        frames[0] += 500_000
        assert_operator PokeAccess.clock - before, :<, 0.5
      end
    end
  end

  test "measures System.uptime's units per second of wall time" do
    builds = { "a build counting seconds" => [100.0, 120.0, 1.0],
               "a build counting microseconds" => [3_000_000.0, 23_000_000.0, 1_000_000.0] }
    builds.each do |build, (origin, now, scale)|
      with_uptime(lambda { now }) do
        clock_started(20.0, origin) { assert_in_delta scale, PokeAccess.uptime_scale, scale * 0.05, build }
      end
    end
  end

  test "measures System.uptime from its reading at the clock's first read" do
    uptime = [7.0]
    with_uptime(lambda { uptime[0] }) do
      clock_started(nil, nil) do
        PokeAccess.clock
        rewind_clock(20.0)
        uptime[0] = 27.0
        assert_in_delta 1.0, PokeAccess.uptime_scale, 0.05
      end
    end
  end

  test "keeps the scale it measured" do
    uptime = [120.0]
    with_uptime(lambda { uptime[0] }) do
      clock_started(20.0, 100.0) do
        first = PokeAccess.uptime_scale
        assert_in_delta 1.0, first, 0.05, "the first answer is measured"
        uptime[0] = 150.0
        assert_equal first, PokeAccess.uptime_scale, "and stays, though the uptime moves on"
      end
    end
  end

  test "gives no scale before a second has passed" do
    with_uptime(lambda { 100.5 }) do
      clock_started(0.5, 100.0) { assert_nil PokeAccess.uptime_scale }
    end
  end

  test "gives no scale without System.uptime" do
    with_uptime(nil) do
      clock_started(2.0, 100.0) { assert_nil PokeAccess.uptime_scale }
    end
  end

  test "gives no scale when System.uptime gave no reading as the clock started" do
    with_uptime(lambda { 102.0 }) do
      clock_started(2.0, nil) { assert_nil PokeAccess.uptime_scale }
    end
  end

  test "turns a 0-100 frequency into the seconds of 60 down to 6 gen-6 frames" do
    { 100 => 6, 99 => 6, 50 => 33, 1 => 59, 0 => 60 }.each do |freq, frames|
      assert_equal frames / PokeAccess::FPS, PokeAccess.freq_to_seconds(freq), "frequency #{freq}"
    end
  end

  test "never paces cues closer than 4 frames, past the top of the scale" do
    [200, 1000].each { |freq| assert_equal 4 / PokeAccess::FPS, PokeAccess.freq_to_seconds(freq), "frequency #{freq}" }
  end

  private

  # Runs the block with the clock started secs seconds ago (nil: not started yet), origin as System.uptime's reading
  # at that start and no scale measured; the clock's state is put back after.
  def clock_started(secs, origin)
    saved = STATE.map { |iv| PokeAccess.instance_variable_get(iv) }
    PokeAccess.instance_variable_set(:@epoch, secs && Time.now - secs)
    PokeAccess.instance_variable_set(:@uptime0, origin)
    PokeAccess.instance_variable_set(:@uptime_scale, nil)
    yield
  ensure
    STATE.each_with_index { |iv, i| PokeAccess.instance_variable_set(iv, saved[i]) }
  end

  # Moves the clock's start secs further back, as if that much more wall time had passed.
  def rewind_clock(secs)
    PokeAccess.instance_variable_set(:@epoch, PokeAccess.instance_variable_get(:@epoch) - secs)
  end

  # Runs the block with System standing for an mkxp-z build whose uptime answers reading's value, or one without
  # uptime for nil; whatever System was before comes back after.
  def with_uptime(reading)
    had = Object.const_defined?(:System)
    was = had ? Object.send(:remove_const, :System) : nil
    fake = Module.new
    fake.define_singleton_method(:uptime) { reading.call } if reading
    Object.const_set(:System, fake)
    yield
  ensure
    Object.send(:remove_const, :System) if Object.const_defined?(:System)
    Object.const_set(:System, was) if had
  end

  # Runs the block with Graphics.frame_count answering reading's value; the engine's own comes back after, or none.
  def with_frame_count(reading)
    meta = Graphics.singleton_class
    had = meta.method_defined?(:frame_count, false) ? Graphics.method(:frame_count) : nil
    Graphics.define_singleton_method(:frame_count) { reading.call }
    yield
  ensure
    had ? Graphics.define_singleton_method(:frame_count, had) : meta.send(:remove_method, :frame_count)
  end
end

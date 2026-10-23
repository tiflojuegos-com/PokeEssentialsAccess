# The rolling profiler behind the diagnostic's perf line (PokeAccess::Perf): each label's average, maximum and count,
# a fresh window after a reset, and one input frame measured in any scene.
class PerfProbeTest < PokeAccessTest
  Perf = PokeAccess::Perf

  test "reports that a fresh window has no data" do
    in_fresh_window do
      assert_equal "(sin datos)", Perf.report
    end
  end

  test "reports a label's average, maximum and count in milliseconds" do
    in_fresh_window do
      with_clock(1.0, 1.004, 2.0, 2.002) do
        2.times { Perf.measure(:probe) { nil } }
      end
      assert_equal "probe avg=3.00ms max=4.00ms n=2", Perf.report, "a 4 ms then a 2 ms run"
    end
  end

  test "reports every label measured with its own figures, the labels set apart by bars" do
    in_fresh_window do
      with_clock(0.0, 0.001, 0.0, 0.002, 0.0, 0.003) do
        Perf.measure(:first) { nil }
        Perf.measure(:second) { nil }
        Perf.measure(:first) { nil }
      end
      assert_equal ["first avg=2.00ms max=3.00ms n=2", "second avg=2.00ms max=2.00ms n=1"],
                   Perf.report.split(" | ").sort,
                   "each label's figures, in any order, as a hash keeps no order under Ruby 1.8.7"
    end
  end

  test "answers the block's value" do
    in_fresh_window do
      assert_equal 42, Perf.measure(:probe) { 42 }
    end
  end

  test "records a block that raises, and lets the error through" do
    in_fresh_window do
      with_clock(1.0, 1.005) do
        assert_raises(RuntimeError) { Perf.measure(:probe) { raise "boom" } }
      end
      assert_equal "probe avg=5.00ms max=5.00ms n=1", Perf.report
    end
  end

  test "a reset starts a fresh window" do
    in_fresh_window do
      Perf.measure(:probe) { nil }
      Perf.reset
      assert_equal "(sin datos)", Perf.report
    end
  end

  test "one frame of input, which every scene runs, leaves an input_frame measurement" do
    in_fresh_window do
      Input.update
      assert_match(/\Ainput_frame avg=\d+\.\d\dms max=\d+\.\d\dms n=1\z/, Perf.report)
    end
  end

  private

  # Runs the block on an empty window, the stats measured before it put back after.
  def in_fresh_window
    saved = Perf.instance_variable_get(:@stats)
    Perf.reset
    yield
  ensure
    Perf.instance_variable_set(:@stats, saved)
  end

  # Runs the block with the mod's clock answering the given seconds in turn, the real clock put back after.
  def with_clock(*seconds)
    real = PokeAccess.method(:clock)
    queue = seconds.dup
    PokeAccess.define_singleton_method(:clock) { queue.empty? ? real.call : queue.shift }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end
end

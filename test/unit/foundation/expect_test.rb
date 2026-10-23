# expect! passes its value through and logs a nil once per key through log_once, which keeps a key's first failure
# in logged and the marker file, an exception as its class, message and top three frames.
class ExpectTest < PokeAccessTest
  test "passes a present value through and logs nothing for it" do
    fresh_log do
      assert_equal :obj, PokeAccess.expect!("probe.present", :obj)
      assert_equal({}, PokeAccess.logged)
    end
  end

  test "passes false through without logging it, as only nil is absent" do
    fresh_log do
      assert_equal false, PokeAccess.expect!("probe.false", false)
      assert_equal({}, PokeAccess.logged)
    end
  end

  test "passes a nil through and logs it under its expect key" do
    fresh_log do
      assert_nil PokeAccess.expect!("probe.absent", nil)
      assert_equal({ "expect.probe.absent" => "expected but absent" }, PokeAccess.logged)
    end
  end

  test "writes a key's nil to the marker file once, however often it comes" do
    fresh_log do
      before = marker_lines("expect.probe.again").length
      3.times { PokeAccess.expect!("probe.again", nil) }
      assert_equal ["expect.probe.again: expected but absent"], marker_lines("expect.probe.again")[before..-1]
    end
  end

  test "keeps a key's first failure, not a later one" do
    fresh_log do
      PokeAccess.log_once("probe.first", "the first")
      PokeAccess.log_once("probe.first", "the second")
      assert_equal({ "probe.first" => "the first" }, PokeAccess.logged)
    end
  end

  test "logs an exception as its class, its message and its top three frames" do
    error = RuntimeError.new("boom")
    error.set_backtrace(["a.rb:1:in `x'", "b.rb:2:in `y'", "c.rb:3:in `z'", "d.rb:4:in `w'"])
    fresh_log do
      PokeAccess.log_once("probe.error", error)
      assert_equal "RuntimeError: boom @ a.rb:1:in `x' <- b.rb:2:in `y' <- c.rb:3:in `z'",
                   PokeAccess.logged["probe.error"]
    end
  end

  test "logs an exception that was never raised with no frames" do
    fresh_log do
      PokeAccess.log_once("probe.unraised", ArgumentError.new("bad"))
      assert_equal "ArgumentError: bad @ ", PokeAccess.logged["probe.unraised"]
    end
  end

  test "survives a failure whose text cannot be had, logging nothing for it" do
    broken = Object.new
    def broken.to_s; raise "no text"; end
    fresh_log do
      assert_nil PokeAccess.log_once("probe.broken", broken)
      assert_equal({}, PokeAccess.logged)
    end
  end

  test "reads as empty before anything is logged" do
    saved = PokeAccess.instance_variable_get(:@logged_once)
    PokeAccess.instance_variable_set(:@logged_once, nil)
    assert_equal({}, PokeAccess.logged)
  ensure
    PokeAccess.instance_variable_set(:@logged_once, saved)
  end

  private

  # Runs the block with log_once's record of this session empty, the record put back after.
  def fresh_log
    saved = PokeAccess.instance_variable_get(:@logged_once)
    PokeAccess.instance_variable_set(:@logged_once, {})
    yield
  ensure
    PokeAccess.instance_variable_set(:@logged_once, saved)
  end

  # The marker file's lines that log key, without their time stamp.
  def marker_lines(key)
    lines = (File.readlines(PokeAccess.marker_file) rescue [])
    lines.map { |l| l.chomp[/: (#{Regexp.escape(key)}: .*)\z/, 1] }.compact
  end
end

# The base of every test: the mod's state reset before each test, the speech assertions, and tests declared as
# `test "what it does" do ... end`. A test that asserts nothing fails.
module SpeechAssertions
  # Passes when a line spoken since the last clear matches pattern.
  def assert_spoken(pattern, msg = nil)
    lines = SpeakCapture.lines
    assert lines.any? { |l| l =~ pattern }, message(msg) { "no spoken line matches #{pattern.inspect}: #{lines.inspect}" }
  end

  # Passes when exactly one line spoken since the last clear matches pattern.
  def assert_spoken_once(pattern, msg = nil)
    lines = SpeakCapture.lines
    n = lines.count { |l| l =~ pattern }
    assert n == 1, message(msg) { "#{n} spoken lines match #{pattern.inspect}, want 1: #{lines.inspect}" }
  end

  # Passes when no line spoken since the last clear matches pattern.
  def refute_spoken(pattern, msg = nil)
    lines = SpeakCapture.lines
    refute lines.any? { |l| l =~ pattern }, message(msg) { "a spoken line matches #{pattern.inspect}: #{lines.inspect}" }
  end

  # Passes when nothing was spoken since the last clear.
  def assert_nothing_spoken(msg = nil)
    lines = SpeakCapture.lines
    assert lines.empty?, message(msg) { "spoke #{lines.inspect}" }
  end
end

class PokeAccessTest < Minitest::Test
  include SpeechAssertions
  include SpeechHelpers
  include RouteHelpers
  include HpaHelpers
  include GuideHelpers
  include SoundHelpers
  include TileWorldHelpers

  class << self
    # The test running now, as "Class#test name" (for the nets' reports).
    attr_accessor :current
  end

  # Declares a test from its description; two tests of a class may not share one.
  def self.test(description, &body)
    name = "test_#{description.gsub(/\s+/, '_')}"
    raise ArgumentError, "#{self}: duplicate test #{description.inspect}" if method_defined?(name)
    define_method(name, &body)
  end

  def setup
    PokeAccessTest.current = "#{self.class}##{name}"
    Reset.before_test
  end

  def teardown
    flunk "the test asserts nothing" if passed? && assertions.zero?
  end
end

# The failure records: swallowed counts what the mod's rescues catch by the place in the mod it came from, writes the
# first failure of each place to the marker file and never raises.

class FailuresTest < PokeAccessTest
  test "counts the failures from one place and writes only the first to the marker" do
    with_clean_records do
      before = marker_lines.grep(%r{swallowed core/zz/probe\.rb:12}).length
      2.times { PokeAccess.swallowed(failure_at("boom", "core/zz/probe.rb:12:in 'read'")) }

      assert_equal [["core/zz/probe.rb:12", 2, "RuntimeError: boom @ core/zz/probe.rb:12:in 'read'"]],
                   PokeAccess.swallowed_sites
      assert_equal before + 1, marker_lines.grep(%r{swallowed core/zz/probe\.rb:12}).length,
                   "one marker line for the place, not one per failure"
    end
  end

  test "keeps each place apart, the most frequent first" do
    with_clean_records do
      PokeAccess.swallowed(failure_at("a", "games/zz/one.rb:3:in 'x'"))
      3.times { PokeAccess.swallowed(failure_at("b", "plugins/zz/two.rb:9:in 'y'")) }

      assert_equal [["plugins/zz/two.rb:9", 3], ["games/zz/one.rb:3", 1]],
                   PokeAccess.swallowed_sites.map { |site, n, _first| [site, n] }
    end
  end

  test "places a failure at the innermost frame of the mod's own code" do
    {
      ["C:/Game/Scripts/Window.rb:10:in 'refresh'", "F:/Game/accessibility/plugins/zz/list.rb:33:in 'read'",
       "F:/Game/accessibility/core/menus/menus.rb:400:in 'update'"] => "plugins/zz/list.rb:33",
      ["core/zz/a.rb:1:in 'x'"] => "core/zz/a.rb:1",
      ["D:/games/Pokemon X/accessibility/core/zz/b.rb:7:in 'y'"] => "core/zz/b.rb:7",
      ["F:/fangames/Reborn/Data/Scripts/Window.rb:3:in 'z'", "F:/fangames/Reborn/accessibility/games/zz/c.rb:8"] =>
        "games/zz/c.rb:8",
      ["C:/Game/Scripts/Game.rb:5:in 'main'"] => "C:/Game/Scripts/Game.rb:5:in 'main'",
      [] => ""
    }.each do |frames, site|
      assert_equal site, PokeAccess.failure_site(failure_at("x", *frames)), "for #{frames.inspect}"
    end
  end

  test "never raises, whatever it is handed" do
    with_clean_records do
      assert_nil PokeAccess.swallowed(nil)
      assert_nil PokeAccess.swallowed(RuntimeError.new("never raised, so no backtrace"))
      assert_equal 2, PokeAccess.swallowed_sites.map { |_site, n, _first| n }.inject(0) { |a, b| a + b }
    end
  end

  private

  def with_clean_records
    saved = PokeAccess.instance_variable_get(:@swallowed)
    PokeAccess.instance_variable_set(:@swallowed, nil)
    yield
  ensure
    PokeAccess.instance_variable_set(:@swallowed, saved)
  end

  def failure_at(message, *frames)
    e = RuntimeError.new(message)
    e.set_backtrace(frames)
    e
  end

  def marker_lines
    path = PokeAccess.marker_file
    File.exist?(path) ? File.readlines(path) : []
  end
end

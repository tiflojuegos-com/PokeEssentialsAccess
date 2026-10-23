require "rbconfig"
require "tmpdir"
require "fileutils"
require "open3"

# test/check187.py keeps the code the 1.8.7 games load 1.8.7-safe: a sweep of the shapes 1.8.7 cannot run, then
# check187_real.rb's parse of every file under a real 1.8.7 interpreter when one is installed (PARCIAL without one).
class Ruby187Test < PokeAccessTest
  SWEEP = File.join(Harness::ROOT, "test", "check187.py")
  PARSE = File.join(Harness::ROOT, "test", "check187_real.rb")
  NO_INTERPRETER = { "RUBY187" => "planted-missing-ruby187" }.freeze
  UNSAFE = [
    ["items.each do |i|", nil],
    ["  risky", nil],
    ["rescue", "block-rescue (1.8.7 syntax error)"],
    ["end", nil],
    ["  .strip", "leading-dot chain (1.8.7 syntax error)"],
    ["h = { foo: 1 }", "1.9 hash literal key: value (use :key => value)"],
    ["def f(**opts)", "double-splat **opts in def (Ruby 2.0+)"],
    ["n = a&.b", "safe navigation &. (Ruby 2.3+)"],
    ["t = a.sum", "Enumerable#sum (Ruby 2.4+)"],
    ["s = <<~TXT", "squiggly heredoc <<~ (Ruby 2.3+)"],
    ["x = 1  # a.sum", nil],
    ["# h = { foo: 1 }", nil]
  ].freeze
  SAFE = ["h = { :foo => 1 }", "def f(*args)", "n = a && a.b", "t = a.inject(0) { |s, x| s + x }", "begin", "  risky",
          "rescue", "end"].freeze
  BROKEN = "CHECK187 ROTO: los patrones no hacen lo que dicen hacer.".freeze
  HASH_RULE = "1.9 hash literal key: value (use :key => value)".freeze
  SELF_TEST_BREAKS = [
    ['"h = { foo: 1 }", "h = { :foo => 1 }"', '"h = { :foo => 1 }", "h = { :foo => 1 }"',
     "  #{HASH_RULE}: no longer catches 'h = { :foo => 1 }'"],
    ['"h = { foo: 1 }", "h = { :foo => 1 }"', '"h = { foo: 1 }", "h = { foo: 1 }"',
     "  #{HASH_RULE}: now flags the 1.8.7-safe 'h = { foo: 1 }'"],
    ['"  .strip", "  x.strip"', '"  x.strip", "  x.strip"', "  leading-dot chain: no longer recognises '  x.strip'"],
    ['"  .strip", "  x.strip"', '"  .strip", "  .strip"', "  leading-dot chain: now recognises '  .strip'"],
    ['"begin\n  risky\nrescue\nend", False', '"begin\n  risky\nrescue\nend", True',
     "  opener walk: rescue owned by begin is not"]
  ].freeze

  test "passes the code the 1.8.7 games load" do
    out, status = sweep(SWEEP, [])
    assert status.success?, out
    assert_match(/\A(OK|PARCIAL):/, out.strip.split("\n").last.to_s, "the sweep reports its verdict")
  end

  test "flags each shape 1.8.7 cannot run in a file it is given, by line and rule, comments aside" do
    Dir.mktmpdir("pa_c187") do |dir|
      path = write_tree(dir, "sample.rb" => UNSAFE.map { |line, _rule| line }.join("\n") + "\n").first
      out, status = sweep(SWEEP, [path])
      want = UNSAFE.each_with_index.map { |(_line, rule), i| rule && [i + 1, rule] }.compact
      assert_equal want, flags(out, path)
      assert_equal 1, status.exitstatus, "a flagged sweep fails"
    end
  end

  test "passes 1.8.7-safe code, saying the real parse was left out without an interpreter" do
    Dir.mktmpdir("pa_c187") do |dir|
      out, status = sweep(SWEEP, write_tree(dir, "sample.rb" => SAFE.join("\n") + "\n"))
      assert_equal 0, status.exitstatus, out
      assert_match(/\APARCIAL: /, out)
    end
  end

  test "leaves out the files of the games that run modern Ruby" do
    Dir.mktmpdir("pa_c187") do |dir|
      paths = write_tree(dir, "games/anil/sample.rb" => "h = { foo: 1 }\n", "games/opalo/sample.rb" => "h = { foo: 1 }\n")
      out, _status = sweep(SWEEP, paths)
      assert_equal [[1, HASH_RULE]], flags(out, paths[1]), "a 1.8.7 game's file"
      assert_equal [], flags(out, paths[0]), "a modern game's file"
    end
  end

  test "stops before sweeping when a rule, a shape case or an opener-walk case no longer does what it says" do
    original = File.read(SWEEP)
    SELF_TEST_BREAKS.each do |from, to, want|
      broken = original.sub(from) { to }
      refute_equal original, broken, "the sweep holds #{from}"
      Dir.mktmpdir("pa_c187") do |dir|
        script, sample = write_tree(dir, "check187.py" => broken, "sample.rb" => "h = { foo: 1 }\n")
        out, status = sweep(script, [sample])
        assert_equal [2, [BROKEN, want]], [status.exitstatus, out.split("\n")], "for #{to}"
      end
    end
  end

  test "with no file given, sweeps every file under core, games, plugins and loader" do
    Dir.mktmpdir("pa_c187") do |dir|
      unsafe = "h = { foo: 1 }\n"
      files = { "core/manifest.rb" => "%w[\n  present\n]\n", "core/present.rb" => unsafe, "core/deep/inner.rb" => unsafe,
                "games/g/m.rb" => unsafe, "plugins/p.rb" => unsafe, "loader/l.rb" => unsafe }
      script = write_tree(dir, files.merge("test/check187.py" => File.read(SWEEP))).last
      out, status = sweep(script, [])
      flagged = out.tr("\\", "/").scan(%r{^  .*/pa_c187[^/]*/(.+):1  #{Regexp.escape(HASH_RULE)} -> }).flatten.sort
      assert_equal %w[core/deep/inner.rb core/present.rb games/g/m.rb loader/l.rb plugins/p.rb], flagged
      assert_equal 1, status.exitstatus
    end
  end

  test "with no file given, fails a sweep that misses a core/manifest.rb entry or a whole folder" do
    {
      { "core/manifest.rb" => "%w[\n  present\n  absent\n]\n", "core/present.rb" => "x = 1\n",
        "games/g/m.rb" => "x = 1\n", "loader/l.rb" => "x = 1\n" } =>
        ["1.8.7 SWEEP INCOMPLETE:", "  manifest entry never scanned: core/absent.rb", "  zero files matched under plugins/"],
      { "core/manifest.rb" => "%w[\n  present\n]\n", "core/present.rb" => "x = 1\n" } =>
        ["1.8.7 SWEEP INCOMPLETE:", "  zero files matched under plugins/", "  zero files matched under games/",
         "  zero files matched under loader/"],
      { "core/present.rb" => "x = 1\n", "games/g/m.rb" => "x = 1\n", "plugins/p.rb" => "x = 1\n",
        "loader/l.rb" => "x = 1\n" } =>
        ["1.8.7 SWEEP INCOMPLETE:", "  core/manifest.rb missing or unreadable"]
    }.each do |files, want|
      Dir.mktmpdir("pa_c187") do |dir|
        script = write_tree(dir, files.merge("test/check187.py" => File.read(SWEEP))).last
        out, status = sweep(script, [])
        assert_equal want, out.tr("\\", "/").split("\n"), "for #{files.keys.inspect}"
        assert_equal 1, status.exitstatus
      end
    end
  end

  test "parses each file without running it, leaving out the modern games' folders" do
    Dir.mktmpdir("pa_c187") do |dir|
      write_tree(dir, "core/manifest.rb" => "%w[\n  present\n]\n",
                      "core/present.rb" => "File.open('planted_ran.txt', 'w') { |f| f.write('ran') }\n",
                      "games/anil/broken.rb" => "def broken(\n", "plugins/p.rb" => "x = 1\n", "loader/l.rb" => "x = 1\n")
      out, status = parse(dir)
      assert_equal "OK: 4 files parse under real Ruby #{RUBY_VERSION} (4 reached, manifest covered)\n", out
      assert_equal 0, status.exitstatus
      refute File.exist?(File.join(dir, "planted_ran.txt")), "the parsed file never ran"
    end
  end

  test "fails the parse on a file that does not compile, naming it" do
    Dir.mktmpdir("pa_c187") do |dir|
      broken = write_tree(dir, "core/manifest.rb" => "%w[\n  present\n]\n", "core/present.rb" => "x = 1\n",
                               "games/g/broken.rb" => "def broken(\n").last
      out, status = parse(dir)
      lines = out.split("\n")
      assert_equal "REAL 1.8.7 SYNTAX ERRORS:", lines[0]
      assert_match(/\A  #{Regexp.escape(broken)}:1: /, lines[1].to_s)
      assert_equal 1, status.exitstatus
    end
  end

  test "fails the parse when a core/manifest.rb entry was never parsed" do
    Dir.mktmpdir("pa_c187") do |dir|
      write_tree(dir, "core/manifest.rb" => "%w[\n  present\n  absent\n]\n", "core/present.rb" => "x = 1\n")
      out, status = parse(dir)
      assert_equal "REAL 1.8.7 SWEEP INCOMPLETE: 1 core/manifest.rb entries never parsed\n  absent\n", out
      assert_equal 1, status.exitstatus
    end
  end

  test "fails the parse when core/manifest.rb is missing, raises, or gives no list of entries" do
    [nil, "raise 'planted failure'\n", "%w[]\n", "{ 'present' => 1 }\n"].each do |manifest|
      Dir.mktmpdir("pa_c187") do |dir|
        files = { "core/present.rb" => "x = 1\n" }
        files["core/manifest.rb"] = manifest if manifest
        write_tree(dir, files)
        out, status = parse(dir)
        want = "REAL 1.8.7 SWEEP INCOMPLETE: core/manifest.rb missing or unreadable at #{dir}/core/manifest.rb\n"
        assert_equal [want, 1], [out, status.exitstatus], "for #{manifest.inspect}"
      end
    end
  end

  private

  # [output, status] of check187.py at script over the given files (every file of its repo when none), with no 1.8.7
  # interpreter for the planted runs.
  def sweep(script, files)
    env = script == SWEEP && files.empty? ? {} : NO_INTERPRETER
    Open3.capture2e(env, "python", script, *files)
  end

  # [output, status] of check187_real.rb over the tree at root, run by this Ruby from root.
  def parse(root)
    Open3.capture2e(RbConfig.ruby, PARSE, root, :chdir => root)
  end

  # Writes each relative path of files under dir with its text; answers their full paths, in order.
  def write_tree(dir, files)
    files.map do |rel, text|
      path = File.join(dir, rel)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, text)
      path
    end
  end

  # [line, rule] of each line of path the sweep's output flags.
  def flags(out, path)
    out.scan(/^  #{Regexp.escape(path)}:(\d+)  (.*?) -> /).map { |line, rule| [line.to_i, rule] }
  end
end

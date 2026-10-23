require "rbconfig"
require "json"
require "tmpdir"
require "fileutils"

# loader/preload_access.rb in a Ruby process of its own over a made-up game folder: it loads the toolkit once, on the
# first frame the game is ready for it, notes a stall once, and keeps the toolkit's failures from ending the game.
class PreloadTriggerTest < PokeAccessTest
  PRELOAD = File.join(Harness::ROOT, "loader", "preload_access.rb")
  BOOT = "File.open('booted.txt', 'a') { |f| f.write(\"boot\\n\") }\n".freeze
  DRIVER = <<~'RUBY'.freeze
    require "json"
    module Graphics
      def self.update(*args)
        $updates = ($updates || 0) + 1
        $update_args = args
        :painted
      end
    end
    def frames(n); n.times { Graphics.update }; end
    def boots; File.exist?("booted.txt") ? File.read("booted.txt").count("\n") : 0; end
    def start_mark; File.read("accessibility/data/preload_started.txt").split("\n"); end
    $report = {}
    at_exit do
      $report["exit"] = $!.status if $!.is_a?(SystemExit)
      puts "REPORT=" + JSON.generate($report)
    end
  RUBY
  # mkxp-z's F12: the frame update raises Reset (an Exception, not a StandardError) while $reset_now is set, and a
  # planted RuntimeError while $fail_now is; rebinds counts the toolkit's after_reset calls.
  RESET = <<~'RUBY'.freeze
    class Reset < Exception; end
    module Graphics
      class << self
        alias_method :update__driver, :update
        def update(*args)
          raise Reset if $reset_now
          raise "planted" if $fail_now
          update__driver(*args)
        end
      end
    end
    def rebinds; File.exist?("rebound.txt") ? File.read("rebound.txt").count("\n") : 0; end
  RUBY
  # A toolkit whose Hooks.after_reset notes each call in rebound.txt.
  REBIND_BOOT = (BOOT + "module PokeAccess; module Hooks; def self.after_reset; " \
                 "File.open('rebound.txt', 'a') { |f| f.write(\"r\\n\") }; end; end; end\n").freeze
  SCRIPT_THREAD = <<~'RUBY'.freeze
    class ThreadLoader
      @@gate = Queue.new
      @@scriptLoadThread = Thread.new { @@gate.pop }
      def self.finish; @@gate.push(:done); @@scriptLoadThread.join; end
    end
  RUBY

  test "marks that it ran, with its Ruby version, before any frame and before the toolkit" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      $report["mark"] = start_mark
      $report["boots"] = boots
    RUBY
    assert_equal({ "mark" => ["preload ok ruby=#{RUBY_VERSION}"], "boots" => 0 }, got)
  end

  test "starts the mark afresh each boot, dropping what an earlier boot noted" do
    got = run_preload(<<~'RUBY')
      File.write("accessibility/data/preload_started.txt",
                 "preload ok ruby=1.8.7\nstalled: 1800 frames, scene=nil, scripts_done=false\n")
      load ARGV[0]
      $report["mark"] = start_mark
    RUBY
    assert_equal({ "mark" => ["preload ok ruby=#{RUBY_VERSION}"] }, got)
  end

  test "loads the toolkit on the first frame once the game has set $scene" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      $scene = Object.new
      frames(1)
      $report["boots"] = boots
    RUBY
    assert_equal({ "boots" => 1 }, got)
  end

  test "takes a $scene the game set to nil as no scene yet" do
    got = run_preload(<<~'RUBY')
      $scene = nil
      load ARGV[0]
      frames(200)
      $report["boots"] = boots
    RUBY
    assert_equal({ "boots" => 0 }, got)
  end

  test "loads the toolkit only once, however many frames follow" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      $scene = Object.new
      frames(50)
      $report["boots"] = boots
    RUBY
    assert_equal({ "boots" => 1 }, got)
  end

  test "waits while the game's scripts are evaluated, then loads once Main's top-level pbCallTitle exists" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      frames(400)
      $report["waiting"] = boots
      def pbCallTitle; nil; end
      $report["private"] = Object.private_method_defined?(:pbCallTitle)
      frames(1)
      $report["loaded"] = boots
    RUBY
    assert_equal({ "waiting" => 0, "private" => true, "loaded" => 1 }, got)
  end

  test "takes a public pbCallTitle as the end of the scripts too" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      frames(400)
      Object.send(:define_method, :pbCallTitle) { nil }
      $report["public"] = Object.public_method_defined?(:pbCallTitle)
      frames(1)
      $report["loaded"] = boots
    RUBY
    assert_equal({ "public" => true, "loaded" => 1 }, got)
  end

  test "takes the script list as unfinished when it cannot tell, and still loads once $scene is set" do
    got = run_preload(<<~'RUBY')
      def pbCallTitle; nil; end
      def Object.private_method_defined?(*args); raise "planted failure"; end
      load ARGV[0]
      frames(200)
      $report["cannot_tell"] = boots
      $scene = Object.new
      frames(1)
      $report["scene_set"] = boots
    RUBY
    assert_equal({ "cannot_tell" => 0, "scene_set" => 1 }, got)
  end

  test "trusts a finished script list without $scene only from the 120th frame" do
    got = run_preload(<<~'RUBY')
      def pbCallTitle; nil; end
      load ARGV[0]
      frames(119)
      $report["frame_119"] = boots
      frames(1)
      $report["frame_120"] = boots
    RUBY
    assert_equal({ "frame_119" => 0, "frame_120" => 1 }, got)
  end

  test "holds the load while the game's script thread runs, $scene set, and loads once it ends" do
    got = run_preload(SCRIPT_THREAD + <<~'RUBY')
      load ARGV[0]
      $scene = Object.new
      frames(3)
      $report["running"] = boots
      ThreadLoader.finish
      frames(1)
      $report["ended"] = boots
    RUBY
    assert_equal({ "running" => 0, "ended" => 1 }, got)
  end

  test "lets a ThreadLoader with no script thread left, or no thread variable at all, load" do
    ["class ThreadLoader\n  @@scriptLoadThread = nil\nend\n", "class ThreadLoader\nend\n"].each do |loader|
      got = run_preload(loader + <<~'RUBY')
        load ARGV[0]
        $scene = Object.new
        frames(1)
        $report["boots"] = boots
      RUBY
      assert_equal({ "boots" => 1 }, got, "for #{loader.inspect}")
    end
  end

  test "notes in the start mark, once, that it stalled for 1800 frames and what it waited for" do
    {
      "" => "stalled: 1800 frames, scene=nil, scripts_done=false",
      "$scene = nil\n" => "stalled: 1800 frames, scene=nil, scripts_done=false",
      "#{SCRIPT_THREAD}$scene = Object.new\ndef pbCallTitle; nil; end\n" =>
        "stalled: 1800 frames, scene=set, scripts_done=true"
    }.each do |arrange, stall|
      got = run_preload(arrange + <<~'RUBY')
        load ARGV[0]
        frames(1799)
        $report["before"] = start_mark
        frames(1)
        $report["at"] = start_mark
        frames(300)
        $report["later"] = start_mark
        $report["boots"] = boots
      RUBY
      mark = ["preload ok ruby=#{RUBY_VERSION}"]
      assert_equal({ "before" => mark, "at" => mark + [stall], "later" => mark + [stall], "boots" => 0 }, got,
                   "for #{arrange.inspect}")
    end
  end

  test "keeps a failing toolkit's error in the loader log, never retries it, and the game goes on" do
    got = run_preload(<<~'RUBY', BOOT + "raise 'planted failure'\n")
      load ARGV[0]
      $scene = Object.new
      $report["frame"] = Graphics.update
      frames(3)
      $report["boots"] = boots
      $report["log"] = File.read("accessibility/data/loader_error.txt").split("\n").first(2)
    RUBY
    assert_equal "painted", got["frame"], "the frame that loaded it still returns the game's own"
    assert_equal 1, got["boots"], "one attempt"
    assert_equal "RuntimeError: planted failure", got["log"][0]
    assert_match(%r{\Aaccessibility/boot\.rb:2:}, got["log"][1], "then its backtrace")
  end

  test "lets the toolkit's exit end the game" do
    got = run_preload(<<~'RUBY', "exit 7\n")
      load ARGV[0]
      $scene = Object.new
      frames(1)
      $report["went_on"] = true
    RUBY
    assert_equal({ "exit" => 7 }, got)
  end

  test "hands the game's frame update its arguments and gives back its result" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      $report["result"] = Graphics.update(1, 2)
      $report["args"] = $update_args
      $report["updates"] = $updates
    RUBY
    assert_equal({ "result" => "painted", "args" => [1, 2], "updates" => 1 }, got)
  end

  test "wraps the frame update once when the preload runs again" do
    got = run_preload(<<~'RUBY')
      load ARGV[0]
      load ARGV[0]
      frames(3)
      $report["updates"] = $updates
    RUBY
    assert_equal({ "updates" => 3 }, got)
  end

  test "runs in a game folder without its data folder, its start mark and stall note left out" do
    got = run_preload(<<~'RUBY', BOOT, false)
      load ARGV[0]
      frames(1800)
      $scene = Object.new
      frames(1)
      $report["boots"] = boots
      $report["data"] = File.exist?("accessibility/data")
    RUBY
    assert_equal({ "boots" => 1, "data" => false }, got)
  end

  test "lets the game go on when a failing toolkit's error cannot be written" do
    got = run_preload(<<~'RUBY', BOOT + "raise 'planted failure'\n", false)
      load ARGV[0]
      $scene = Object.new
      frames(3)
      $report["boots"] = boots
      $report["went_on"] = true
    RUBY
    assert_equal({ "boots" => 1, "went_on" => true }, got)
  end

  test "after an F12 reset, waits for Main to define pbCallTitle anew, then has the toolkit put its wrappers back" do
    got = run_preload(RESET + <<~'RUBY', REBIND_BOOT)
      load ARGV[0]
      def pbCallTitle; :title; end
      $scene = Object.new
      frames(1)
      $reset_now = true
      begin
        Graphics.update
      rescue Reset
        $report["reset"] = true
      end
      $reset_now = false
      frames(200)
      $report["before"] = rebinds
      def pbCallTitle; :title_again; end
      frames(3)
      $report["after"] = rebinds
      $report["boots"] = boots
    RUBY
    assert_equal({ "reset" => true, "before" => 0, "after" => 1, "boots" => 1 }, got)
  end

  test "after a reset in a game without pbCallTitle, puts the wrappers back from the 120th frame" do
    got = run_preload(RESET + <<~'RUBY', REBIND_BOOT)
      load ARGV[0]
      $scene = Object.new
      frames(1)
      $reset_now = true
      begin
        Graphics.update
      rescue Reset
        nil
      end
      $reset_now = false
      frames(119)
      $report["at_119"] = rebinds
      frames(1)
      $report["at_120"] = rebinds
    RUBY
    assert_equal({ "at_119" => 0, "at_120" => 1 }, got)
  end

  test "takes a reset before the toolkit loaded, or another exception out of the frame update, as no reset of its" do
    got = run_preload(RESET + <<~'RUBY', REBIND_BOOT)
      load ARGV[0]
      def pbCallTitle; :title; end
      $reset_now = true
      begin
        Graphics.update
      rescue Reset
        $report["early"] = true
      end
      $reset_now = false
      $scene = Object.new
      frames(1)
      $fail_now = true
      begin
        Graphics.update
      rescue RuntimeError => e
        $report["passed_on"] = e.message
      end
      $fail_now = false
      def pbCallTitle; :title_again; end
      frames(200)
      $report["rebinds"] = rebinds
      $report["boots"] = boots
    RUBY
    assert_equal({ "early" => true, "passed_on" => "planted", "rebinds" => 0, "boots" => 1 }, got)
  end

  private

  # What the driver body put in $report, run after DRIVER in a fresh game folder whose accessibility/boot.rb holds
  # boot (with the data folder unless data is false), the preload as the harness would load it given as ARGV[0].
  def run_preload(body, boot = BOOT, data = true)
    Dir.mktmpdir("pa_preload") do |dir|
      FileUtils.mkdir_p(File.join(dir, "accessibility", data ? "data" : ""))
      File.write(File.join(dir, "accessibility", "boot.rb"), boot)
      File.write(File.join(dir, "preload_access.rb"), Harness.source(PRELOAD))
      File.write(File.join(dir, "driver.rb"), DRIVER + body)
      out = IO.popen([RbConfig.ruby, "driver.rb", "preload_access.rb"], :chdir => dir, :err => [:child, :out]) do |io|
        io.read
      end
      line = out.to_s[/^REPORT=(.*)$/, 1]
      flunk "the driver gave no report: #{out}" unless line
      JSON.parse(line)
    end
  end
end

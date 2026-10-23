require "rbconfig"
require "json"
require "tmpdir"
require "fileutils"

# games/uranium/compat.rb in a Ruby process of its own against stand-ins of what mkxp-z and Uranium's scripts give it:
# it neutralizes what mkxp-z cannot run, evaluates the script sections as RGSS does, and answers the first-boot picker.
class UraniumCompatTest < PokeAccessTest
  COMPAT = File.join(Harness::ROOT, "games", "uranium", "compat.rb")
  PROBE = <<~'RUBY'.freeze
    require "json"
    module Audio
      %w[bgm_fade bgm_stop bgs_fade bgs_stop me_fade me_stop se_stop].each do |m|
        (class << self; self; end).send(:define_method, m) { |*a| nil }
      end
      %w[bgm_play bgs_play me_play se_play].each do |m|
        (class << self; self; end).send(:define_method, m) do |name, volume = 100, pitch = 100|
          $played = [m, name, volume, pitch]
        end
      end
    end
    class Win32API
      def initialize(dll, fn, *rest); @fn = fn; end
      def call(*args); @fn == "GetUserDefaultUILanguage" ? $langid : 7; end
    end
    class ProbeSystem
      attr_accessor :language
      def bgmvolume; 50; end
      def sevolume; 25; end
    end
    LANGUAGES = [["English", "messages.dat"], ["Espanol", "intl_spanish.dat"], ["Deutsch", "intl_german.dat"],
                 ["Francais", "intl_french.dat"], ["Portugues", "intl_portuguese.dat"], ["Chinese", "intl_chinese.dat"],
                 ["Korean", "intl_korean.dat"], ["Nederlands", "intl_dutch.dat"]]
    def pbLoadMessages(file); $loaded = file; end
    def picker_section(name = "168:Language Selection")
      nil.eval("class LanguageSelection; def main(first = false); :picker; end; end", nil, name)
    end
    def pick
      $PokemonSystem = ProbeSystem.new
      [LanguageSelection.new.main(true), $PokemonSystem.language, $loaded]
    end
    $langid = 0x0c0a
    $report = {}
    at_exit { puts "REPORT=" + JSON.generate($report) }
  RUBY

  test "sets RGSS Linker's guard so the game's script never loads its DLL, keeping one already set" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["fresh"] = Kernel.instance_variable_get(:@RGSS_Linker)
      Kernel.instance_variable_set(:@RGSS_Linker, { "linked" => true })
      load ARGV[0]
      $report["kept"] = Kernel.instance_variable_get(:@RGSS_Linker)
    RUBY
    assert_equal({ "fresh" => {}, "kept" => { "linked" => true } }, got)
  end

  test "sets FmodEx's guard as the game would: every native saved, a library of its own, both volumes at 100" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["saved"] = UraniumCompat::SAVED.select { |m| Audio.instance_variable_get("@#{m}") == Audio.method(m) }
      $report["library"] = Audio.instance_variable_get(:@library).inspect
      $report["volumes"] = [Audio.instance_variable_get(:@master_volume), Audio.instance_variable_get(:@sfx_volume)]
      $report["fmodex"] = FmodEx.class.name
    RUBY
    assert_equal %w[bgm_fade bgm_stop bgs_fade bgs_stop me_fade me_stop se_stop], got["saved"],
                 "the natives it leaves in place are the ones it saved"
    assert_equal ":mkxp", got["library"], "a library that is not FmodEx"
    assert_equal [100, 100], got["volumes"]
    assert_equal "Module", got["fmodex"], "and an empty FmodEx"
  end

  test "saves the natives it wraps, which play at the call's own volume" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $PokemonSystem = ProbeSystem.new
      $report["plays"] = %w[bgm_play bgs_play me_play se_play].map do |m|
        Audio.instance_variable_get("@#{m}").call("x", 80)
        $played
      end
    RUBY
    assert_equal %w[bgm_play bgs_play me_play se_play].map { |m| [m, "x", 80, 100] }, got["plays"]
  end

  test "plays at the call's own volume while the game has no options yet" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      Audio.bgm_play("bgm", 80)
      $report["bgm"] = $played
      Audio.se_play("se")
      $report["se"] = $played
    RUBY
    assert_equal({ "bgm" => ["bgm_play", "bgm", 80, 100], "se" => ["se_play", "se", 100, 100] }, got)
  end

  test "scales each play by the game's option for it, keeping the pitch" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $PokemonSystem = ProbeSystem.new
      $report["plays"] = [["bgm_play", 80, 90], ["me_play", 80, 90], ["bgs_play", 80, 90], ["bgm_play", 33, 100]].map do |m, v, p|
        Audio.send(m, "x", v, p)
        $played
      end
      Audio.se_play("se")
      $report["plays"] << $played
    RUBY
    want = [["bgm_play", "x", 40, 90], ["me_play", "x", 40, 90], ["bgs_play", "x", 20, 90], ["bgm_play", "x", 16, 100],
            ["se_play", "se", 25, 100]]
    assert_equal want, got["plays"], "music by its option, effects by theirs, truncated to a whole volume"
  end

  test "scales by the game's own master and effects volumes too" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      Audio.instance_variable_set(:@master_volume, 50)
      Audio.instance_variable_set(:@sfx_volume, 40)
      $PokemonSystem = ProbeSystem.new
      $report["plays"] = %w[bgm_play me_play bgs_play se_play].map do |m|
        Audio.send(m, "x", 80)
        $played
      end
    RUBY
    want = [["bgm_play", "x", 20, 100], ["me_play", "x", 20, 100], ["bgs_play", "x", 8, 100], ["se_play", "x", 8, 100]]
    assert_equal want, got["plays"],
                 "music and music effects by the master volume, background sounds and sound effects by the effects one"
  end

  test "wraps the play functions and Win32API.new once, however many times the file runs" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      load ARGV[0]
      $PokemonSystem = ProbeSystem.new
      Audio.bgm_play("bgm", 80)
      $report["bgm"] = $played
      $report["dlls"] = [Win32API.new("user32", "f", "", "i").call(1), Win32API.new("KleinBitmap.dll", "f", "", "i").call(1)]
    RUBY
    assert_equal({ "bgm" => ["bgm_play", "bgm", 40, 100], "dlls" => [7, 0] }, got)
  end

  test "answers 0 for every call into KleinBitmap and rubyscreen, whatever their folder, case or extension" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      names = ["KleinBitmap.dll", "./rubyscreen.dll", "KLEINBITMAP", "lib/RubyScreen.DLL"]
      $report["null"] = names.map { |n| api = Win32API.new(n, "f", "", "i"); [api.call(1), api.Call] }
      $report["others"] = ["user32", "kleinbitmap2.dll"].map { |n| Win32API.new(n, "f", "", "i").call(1) }
    RUBY
    assert_equal [[0, 0]] * 4, got["null"]
    assert_equal [7, 7], got["others"], "every other DLL runs as before"
  end

  test "leaves Win32API alone where the engine has none" do
    got = probe(<<~'RUBY')
      Object.send(:remove_const, :Win32API)
      load ARGV[0]
      $report["win32api"] = defined?(Win32API).inspect
      $report["files"] = Dir.children("accessibility")
    RUBY
    assert_equal({ "win32api" => "nil", "files" => [] }, got)
  end

  test "writes nothing when every neutralization applies" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["files"] = Dir.children("accessibility")
    RUBY
    assert_equal({ "files" => [] }, got)
  end

  test "evaluates a script section at top level with its methods public, as RGSS does, and returns its value" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["value"] = nil.eval("def planted_section; 42; end\n40 + 3", nil, "010:Probe")
      $report["call"] = planted_section
      $report["public"] = Object.public_method_defined?(:planted_section)
      $report["kernel"] = Kernel.planted_section
    RUBY
    assert_equal({ "value" => 43, "call" => 42, "public" => true, "kernel" => 42 }, got)
  end

  test "keeps the section's own name and line numbers" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      nil.eval("x = 1\ndef planted_where; [__FILE__, __LINE__]; end", nil, "011:Line")
      $report["where"] = planted_where
    RUBY
    assert_equal({ "where" => ["011:Line", 2] }, got)
  end

  test "skips each section that does not compile, noting it, and goes on with the next" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["values"] = [nil.eval("def broken(", nil, "253:GENERATE WIKI PAGES"), nil.eval("43", nil, "254:After"),
                           nil.eval("class Broken", nil, "255:Other")]
      $report["notes"] = File.read("accessibility/compat_skipped.txt").split("\n")
    RUBY
    assert_equal [nil, 43, nil], got["values"]
    assert_equal 2, got["notes"].length, "one note a section"
    assert_match(/\A253:GENERATE WIKI PAGES: \S/, got["notes"][0], "with the parser's first line")
    assert_match(/\A255:Other: \S/, got["notes"][1])
  end

  test "skips a section that does not compile where its note cannot be written" do
    got = probe(<<~'RUBY', false)
      load ARGV[0]
      $report["value"] = nil.eval("def broken(", nil, "253:GENERATE WIKI PAGES")
      $report["after"] = nil.eval("43", nil, "254:After")
    RUBY
    assert_equal({ "value" => nil, "after" => 43 }, got)
  end

  test "answers the first-boot language picker with the game language Windows displays, else English" do
    want = { 0x0c0a => [1, "intl_spanish.dat"], 0x0407 => [2, "intl_german.dat"], 0x040c => [3, "intl_french.dat"],
             0x0416 => [4, "intl_portuguese.dat"], 0x0804 => [5, "intl_chinese.dat"], 0x0412 => [6, "intl_korean.dat"],
             0x0413 => [7, "intl_dutch.dat"], 0x0409 => [0, "messages.dat"], 0 => [0, "messages.dat"] }
    got = probe("ids = #{want.keys.inspect}\n" + <<~'RUBY')
      load ARGV[0]
      picker_section
      $report["picks"] = ids.map { |id| $langid = id; $loaded = nil; pick }
    RUBY
    want.each_with_index do |(id, (index, file)), i|
      assert_equal [index, index, "Data/#{file}"], got["picks"][i], format("for the language id 0x%04x", id)
    end
  end

  test "answers the picker with English for a Windows language the game has no messages for" do
    got = probe(<<~'RUBY')
      Object.send(:remove_const, :LANGUAGES)
      LANGUAGES = [["English", "messages.dat"], ["Espanol", "intl_spanish.dat"]]
      load ARGV[0]
      picker_section
      $langid = 0x040c
      $report["pick"] = pick
    RUBY
    assert_equal({ "pick" => [0, 0, "Data/messages.dat"] }, got)
  end

  test "answers the picker with English when Windows' display language cannot be read" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      picker_section
      Object.send(:remove_const, :Win32API)
      $report["pick"] = pick
    RUBY
    assert_equal({ "pick" => [0, 0, "Data/messages.dat"] }, got)
  end

  test "takes mkxp-z's language before Windows', when it gives one" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      picker_section
      module System
        def self.user_language; $user_language == "raise" ? raise("planted failure") : $user_language; end
      end
      $report["picks"] = ["de_DE", "DE", "", "1x", "raise"].map { |l| $user_language = l; pick.first }
      class << System; remove_method :user_language; end
      $report["without"] = pick.first
    RUBY
    assert_equal({ "picks" => [2, 2, 1, 1, 1], "without" => 1 }, got,
                 "German from mkxp-z; Windows' Spanish when it gives no code, fails, or has no such method")
  end

  test "opens the picker as before for every other call, choosing no language itself" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      picker_section
      $PokemonSystem = ProbeSystem.new
      $report["later"] = [LanguageSelection.new.main(false), LanguageSelection.new.main]
      $report["chosen"] = [$PokemonSystem.language, $loaded]
    RUBY
    assert_equal({ "later" => %w[picker picker], "chosen" => [nil, nil] }, got,
                 "the game's picker answers, with no language set or messages loaded")
  end

  test "rewraps the picker each time its section is evaluated again" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      2.times { picker_section }
      $report["first"] = pick.first
      $report["later"] = LanguageSelection.new.main(false)
    RUBY
    assert_equal({ "first" => 1, "later" => "picker" }, got)
  end

  test "finds the picker's section by its name after the number" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["picks"] = ["Language Selection", "168: Language Selection ", "168:Language Selection Old"].map do |name|
        picker_section(name)
        pick.first
      end
    RUBY
    assert_equal({ "picks" => [1, 1, "picker"] }, got)
  end

  test "notes a step that fails after its section with the top of its backtrace, and the boot goes on" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["value"] = nil.eval("class LanguageSelection; end\n:defined", nil, "168:Language Selection")
      $report["after"] = nil.eval("43", nil, "169:Next")
      $report["note"] = File.read("accessibility/compat_error.txt").split("\n")
      begin
        UraniumCompat.auto_first_language
      rescue NameError => e
        $report["top"] = e.backtrace[0, 2]
      end
    RUBY
    assert_equal "defined", got["value"], "the section's own value"
    assert_equal 43, got["after"], "the next section"
    assert_match(/\A168:Language Selection: NameError: .*main/, got["note"][0])
    assert_equal [6, got["top"]], [got["note"].length, got["note"][1, 2]],
                 "then five frames from where it failed, its top ones first"
  end

  test "leaves a section by the picker's name that defines no picker as it is" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      $report["value"] = nil.eval("41 + 1", nil, "168:Language Selection")
      $report["files"] = Dir.children("accessibility")
    RUBY
    assert_equal({ "value" => 42, "files" => [] }, got)
  end

  test "turns the game's font install into a no-op, leaving its other methods as they are" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      nil.eval("module FontInstaller; def self.planted_other; :kept; end; def self.install(*a); raise 'installed'; end; end",
               nil, "169:PSystem_System")
      $report["install"] = [FontInstaller.install, FontInstaller.install("Fonts", true)]
      $report["other"] = FontInstaller.planted_other
    RUBY
    assert_equal({ "install" => [nil, nil], "other" => "kept" }, got)
  end

  test "keeps the font install a no-op each time the game defines it again" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      2.times do
        nil.eval("module FontInstaller; def self.install(*a); raise 'installed'; end; end", nil, "169:PSystem_System")
      end
      $report["install"] = FontInstaller.install
    RUBY
    assert_equal({ "install" => nil }, got)
  end

  test "notes a neutralization that fails with the top of its backtrace, and still evaluates the game's sections" do
    got = probe(<<~'RUBY')
      Object.send(:remove_const, :Audio)
      def boot_compat; load ARGV[0]; end
      boot_compat
      $report["note"] = File.read("accessibility/compat_error.txt").split("\n")
      $report["section"] = nil.eval("40 + 2", nil, "001:After")
      begin
        UraniumCompat.skip_fmodex
      rescue NameError => e
        $report["top"] = e.backtrace[0]
      end
    RUBY
    assert_match(/\ANameError: uninitialized constant (UraniumCompat::)?Audio\z/, got["note"][0])
    assert_equal [6, got["top"]], [got["note"].length, got["note"][1]],
                 "then five frames from where it failed, its top one first"
    assert_equal 42, got["section"], "the sections still evaluate"
  end

  private

  # What the probe body put in $report, run after PROBE in a fresh folder (with accessibility/ unless folder is false),
  # compat.rb as the harness would load it given as ARGV[0].
  def probe(body, folder = true)
    Dir.mktmpdir("pa_ucompat") do |dir|
      FileUtils.mkdir_p(File.join(dir, "accessibility")) if folder
      File.write(File.join(dir, "compat.rb"), Harness.source(COMPAT))
      File.write(File.join(dir, "probe.rb"), PROBE + body)
      out = IO.popen([RbConfig.ruby, "probe.rb", "compat.rb"], :chdir => dir, :err => [:child, :out]) { |io| io.read }
      line = out.to_s[/^REPORT=(.*)$/, 1]
      flunk "the probe gave no report: #{out}" unless line
      JSON.parse(line)
    end
  end
end

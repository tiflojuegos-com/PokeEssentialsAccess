require "rbconfig"
require "json"
require "tmpdir"
require "fileutils"

# games/solarlight/compat.rb in a Ruby process of its own, ahead of the game's script sections as RGSS evaluates them:
# the title screen's font install becomes a no-op, the installer's other methods stay, and a failure is noted.
class SolarlightCompatTest < PokeAccessTest
  COMPAT = File.join(Harness::ROOT, "games", "solarlight", "compat.rb")
  PROBE = <<~'RUBY'.freeze
    require "json"
    $report = {}
    at_exit { puts "REPORT=#{JSON.generate($report)}" }
  RUBY

  test "turns the game's font install into a no-op, leaving its other methods as they are" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      eval("module FontInstaller; def self.getFontFolder; :kept; end; def self.install; raise 'installed'; end; end",
               TOPLEVEL_BINDING, "159:PScreen_Load")
      $report["install"] = FontInstaller.install
      $report["other"] = FontInstaller.getFontFolder
    RUBY
    assert_equal({ "install" => nil, "other" => "kept" }, got)
  end

  test "keeps the font install a no-op each time the game defines it again" do
    got = probe(<<~'RUBY')
      load ARGV[0]
      2.times { eval("module FontInstaller; def self.install; raise 'installed'; end; end", TOPLEVEL_BINDING, "159:PScreen_Load") }
      $report["install"] = FontInstaller.install
    RUBY
    assert_equal({ "install" => nil }, got)
  end

  test "notes a neutralization that fails, with the top of its backtrace" do
    got = probe(<<~'RUBY')
      Object.const_set(:FontInstaller, 42)
      load ARGV[0]
      $report["note"] = File.read("accessibility/compat_error.txt").split("\n")
    RUBY
    assert_match(/\ATypeError: /, got["note"][0])
    assert_operator got["note"].length, :>, 1, "then where it failed"
  end

  private

  # What the probe body put in $report, run after PROBE in a fresh folder, compat.rb given as ARGV[0].
  def probe(body)
    Dir.mktmpdir("pa_scompat") do |dir|
      File.write(File.join(dir, "compat.rb"), Harness.source(COMPAT))
      File.write(File.join(dir, "probe.rb"), PROBE + body)
      out = IO.popen([RbConfig.ruby, "probe.rb", "compat.rb"], :chdir => dir, :err => [:child, :out]) { |io| io.read }
      line = out.to_s[/^REPORT=(.*)$/, 1]
      flunk "the probe gave no report: #{out}" unless line
      JSON.parse(line)
    end
  end
end

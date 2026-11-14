require "open3"
require "rbconfig"

class UraniumRestartCompatTest < PokeAccessTest
  test "mkxp reset does not launch the unmodified player or exit its process" do
    path = File.join(Harness::ROOT, "games", "uranium", "compat.rb")
    program = <<~'RUBY'
      # Minimal preload context in a separate process: its Audio/Win32 changes
      # must not alter the other harness specs.
      module Audio; end
      load ARGV.fetch(0)
      def system(*args); raise "The original player was launched"; end
      def exit(*args); raise "The legacy reset section exited the process"; end
      $game_exists = true
      legacy = "if $game_exists\n  Thread.new {system('Uranium')}\n  exit\nend\n$game_exists = true\n"
      2.times { UraniumCompat.eval_section(legacy, TOPLEVEL_BINDING, "000:Hard Reset") }
      raise "Reset state was changed" unless $game_exists
      result = UraniumCompat.eval_section("$compat_other_section = 47", TOPLEVEL_BINDING, "001:Other")
      raise "An ordinary section stopped working" unless result == 47 && $compat_other_section == 47
      UraniumCompat.eval_section("$unrecognized_reset_section = true", TOPLEVEL_BINDING, "000:Hard Reset")
      raise "An unrecognized section was skipped" unless $unrecognized_reset_section
      puts "Restart stays in mkxp; other script sections still run"
    RUBY
    output, errors, status = Open3.capture3(RbConfig.ruby, "-e", program, path, :chdir => Dir.tmpdir)
    assert status.success?, errors + output
    assert_includes output, "Restart stays in mkxp; other script sections still run"
  end
end

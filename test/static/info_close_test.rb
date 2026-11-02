# A screen that publishes a line for the info key says where it goes (Info.clear_text, clear_info_on, focus_reader's :close),
# or is listed here with why it need not: a line left behind is what a screen's parent menu would then answer with.
require File.expand_path(File.join(File.dirname(__FILE__), "imports"))

class InfoCloseTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  PUBLISHES = /Info\.set_info\(:text|\binfo_line\(/
  CLOSES = /clear_text|clear_info_on|:close\s*=>/
  # Battle screens: the next menu replaces the line, and the battle's end forgets it (Info.clear_combat).
  IN_BATTLE = %w[games/rejuvenation/fight_menu.rb games/rv_common/inspect_rv.rb games/soulstones2/raid_cheer.rb games/vitro/battle_bag.rb
                 plugins/bes_battle_info.rb plugins/bes_move_info.rb plugins/ebdx.rb plugins/ebs_ui.rb]
  # Panels over the map with no method that closes them: the map takes the key back on its next frame (Locator.refresh_info).
  OVER_THE_MAP = %w[games/africanus/tablas.rb games/infinitefusion_hoenn/contests.rb games/infinitefusion_hoenn/starters.rb
                    games/perseida/raid.rb games/perseida/tutorials.rb games/reminiscencia/blessings.rb
                    games/reminiscencia/picker.rb
                    games/rv_common/online_trade_rv.rb games/worldfrontier/pwt.rb
                    plugins/fl_wall_clock.rb]
  # Pages and rows of a stock screen, whose close core declares.
  CORE_CLOSES = %w[games/infinitefusion_common/option_screens.rb games/perseida/summary.rb games/reminiscencia/summary_extra.rb
                   games/rv_common/summary_rv.rb games/uranium/options.rb games/vitro/creature_mart.rb games/vitro/summary.rb
                   plugins/improved_mementos.rb]
  EXCUSED = IN_BATTLE + OVER_THE_MAP + CORE_CLOSES

  test "every file that publishes a line says where it goes, or why it need not" do
    assert_equal [], unclosed(sources) - EXCUSED
  end

  test "excuses no file that no longer needs it" do
    assert_equal [], EXCUSED - unclosed(sources)
  end

  test "reports a file that publishes a line with nothing to forget it, and none that declares how" do
    tree = { "a.rb" => "PokeAccess::Info.set_info(:text, line)\n",
             "b.rb" => "PokeAccess::Info.set_info(:text, line)\nclear_info_on(\"X\", :dispose)\n",
             "c.rb" => "PokeAccess::Info.set_info(:text, line)\nPokeAccess::Info.clear_text\n",
             "d.rb" => "PokeAccess::Info.set_info(:text, line)\nfocus_reader(\"X\", :close => :dispose) { |i| i }\n",
             "e.rb" => "PokeAccess::Info.set_info(:map, nil)\n",
             "f.rb" => "PokeAccess::Verbosity.info_line(:quest, parts)\n" }
    assert_equal ["a.rb", "f.rb"], unclosed(tree)
  end

  # The source of every file of the profiles and plugins, by its path from the root.
  def sources
    out = {}
    %w[games plugins].each do |top|
      Dir.glob(File.join(ROOT, top, "**", "*.rb")).each { |f| out[f[(ROOT.length + 1)..-1]] = File.read(f) }
    end
    out
  end

  # The paths that publish a line and declare no way to forget it.
  def unclosed(tree)
    tree.select { |_path, src| src =~ PUBLISHES && src !~ CLOSES }.map { |path, _src| path }.sort
  end
end

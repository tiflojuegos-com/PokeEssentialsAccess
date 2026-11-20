# Pokemon Golden Crown's New Orleans City Gym on the shipped profile: the leaders' event, named Norman in the editor, goes
# by the trainer name its battle gives (Tate & Liza); other events and other maps keep their names.
class GoldenCrownLeaderNamesTest < PokeAccessTest
  test "names New Orleans' leaders as their battle does, and nothing else" do
    rules = PokeAccess::Locator.instance_variable_get(:@rules)[:name]
    kept = rules.length
    path = File.join(Harness::ROOT, "games", "goldencrown", "leader_names.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    $game_map.map_id = 388
    leader = trainer(119, "Norman", ":LEADER_Tate_and_Liza,\"Tate & Liza\"")
    helper = trainer(116, "Trainer(3)", ":PSYCHIC_F,\"Cinny\"")
    assert_equal "Tate & Liza", PokeAccess::Locator.target_name(leader)
    refute_equal "Cinny", PokeAccess::Locator.target_name(helper)
    $game_map.map_id = 384
    PokeAccess::Caches.reset_all
    refute_equal "Tate & Liza", PokeAccess::Locator.target_name(leader)
  ensure
    rules.slice!(kept..-1) if rules && kept
  end

  private

  # A trainer event of the editor name given, whose page fights in a branch on pbTrainerBattle(args).
  def trainer(id, name, args)
    list = [TestCmd.new(355, ["pbTrainerIntro(:LEADER_Tate_and_Liza)"]),
            TestCmd.new(111, [12, "pbTrainerBattle(#{args})"]), TestCmd.new(355, ["pbTrainerEnd"])]
    page = TestPage.new(:trigger => 0, :sprite => "trchar131", :list => list)
    ev = TestGameEvent.new(:id => id, :name => name, :x => 41, :y => 0, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end
end

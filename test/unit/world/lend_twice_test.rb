# An event lent through twice in one go (a walker that is also a boulder, lent as both by the assisted regions) is put
# back as it was, not left walked through for good.

class LendTwiceTest < PokeAccessTest
  test "puts back an event listed twice as it was" do
    $game_map.load_grid(["#####", "#@..#", "#####"])
    ev = World.event(:kind => :npc, :id => 30, :x => 3, :y => 1)
    PokeAccess::World::Probe.lend_through([ev, ev]) { assert ev.through }
    refute ev.through
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  test "leaves a walking boulder solid after the assisted regions are walked" do
    $game_map.load_grid(["#######", "#@....#", "#######"])
    page = TestPage.new(:trigger => 0, :sprite => "rhyhorn", :move_type => 1,
                        :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev = TestGameEvent.new(:id => 31, :x => 4, :y => 1, :name => "StrengthBoulder", :pages => [page])
    ev.blocking = true
    $game_map.events[31] = ev
    World.next_frame
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Routes::Regions.assisted.status([[5, 1]])
    refute ev.through
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

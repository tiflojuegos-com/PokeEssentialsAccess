# The first reading of a map's events (entering it, loading a game) indexes every touch event even when the last one
# read walks about by itself: what a change's listener read from the records before their list was whole (the touch
# index the regions ask for, to tell whether the walker is lent through) is read again.

class FirstSyncIndexTest < PokeAccessTest
  test "indexes the touch events when the last event read on the map walks about" do
    $game_map.load_grid(["#########",
                         "#@......#",
                         "#########"])
    World.touch(:id => 1, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id + 77, 1, 1])])
    walker = TestGameEvent.new(:id => 2, :x => 6, :y => 1, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    walker.blocking = true
    $game_map.events[2] = walker
    PokeAccess::World::Events.forget
    PokeAccess::World::Events.sync(true)
    assert_equal [:exit], PokeAccess::Routes::Effects.touch_at(3, 1, 6, true)
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

# Control.event_at, the event the bump cue and the radar find on the tile ahead: any tile of an event with a size, as
# the engine's at_coordinate? acts on it (a cobweb "Size(3,2)" covers three tiles right and two up from its anchor).

class ControlEventAtTest < PokeAccessTest
  test "finds an event with a size from a tile it covers that is not its anchor" do
    web = World.event(:id => 7, :x => 4, :y => 6, :name => "Size(3,2)")

    assert_same web, PokeAccess::Control.event_at(6, 5)
    assert_same web, PokeAccess::Control.event_at(4, 6)
  ensure
    World.clear_events
  end

  test "finds nothing beside the tiles an event covers" do
    World.event(:id => 7, :x => 4, :y => 6, :name => "Size(3,2)")

    assert_nil PokeAccess::Control.event_at(7, 6)
    assert_nil PokeAccess::Control.event_at(4, 4)
  ensure
    World.clear_events
  end
end

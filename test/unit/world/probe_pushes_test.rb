# Whether the probe lets a pushable move: by the strict check where the game's push asks it, and by the plain passable?
# where the game declared its pushes loose (the Reborn engine and Sevii comment the strict one out).

class ProbePushesTest < PokeAccessTest
  test "asks the strict check where the event has one and the game declared nothing" do
    assert_equal false, PokeAccess::World::Probe.event_movable?(boulder, 3, 3, 2)
  end

  test "asks the plain passable? where the game declared its pushes loose" do
    PokeAccess::World::Probe.loose_pushes!

    assert_equal true, PokeAccess::World::Probe.event_movable?(boulder, 3, 3, 2)
  end

  private

  def boulder
    ev = Object.new
    def ev.through; false; end
    def ev.through=(_v); end
    def ev.passableStrict?(_x, _y, _d); false; end
    def ev.passable?(_x, _y, _d); true; end
    ev
  end
end

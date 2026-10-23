# The route key at the end of an assisted route says what to do there (the field move, the push, the control), as
# the guides do, not that the player is beside it, then how many presses are left past it.

class RouteKeyEndTest < PokeAccessTest
  test "says what to do at the end of an assisted route" do
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@target)
    $game_map.load_grid(["#######",
                         "#.@...#",
                         "#######"])
    World.event(:kind => :npc, :id => 80, :x => 3, :y => 1, :name => "Tree").blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    loc.instance_variable_set(:@target, loc::SurfaceTarget.new(5, 1, "cofre", :spot))
    loc.instance_variable_set(:@targets_stale, false)
    plan = loc.route_plan(loc.instance_variable_get(:@target))
    SpeakCapture.clear
    loc.announce_route
    hold = PokeAccess::Routes::Text.hold(plan.gate, 2, 1) + "; " + PokeAccess::I18n.t(:loc_route_after, :n => 2)
    assert_equal [:assisted, [hold]], [plan.kind, SpeakCapture.lines]
  ensure
    loc.instance_variable_set(:@target, saved)
    World.clear_events
    $game_map.clear_grid
  end
end

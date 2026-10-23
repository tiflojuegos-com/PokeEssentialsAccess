# A map whose shortcuts are too many for a bound (Bound::WORK) is searched without one, and its shortcut list
# is not built again for a character's step, only once the event pages, the vehicle or an event's end change it.

class CrowdedShortcutsTest < PokeAccessTest
  test "searches a map whose shortcuts are too many without a bound" do
    on_crowded_map { assert_nil bound }
  end

  test "builds a crowded map's shortcut list once, not again after a character steps" do
    on_crowded_map do
      bound
      gen = PokeAccess::World::Events.gen
      @walker.x += 1
      PokeAccess::World::Events.sync(true)
      refute_equal gen, PokeAccess::World::Events.gen, "the step is seen as a change of the events"
      bound
      assert_equal 1, @builds
    end
  end

  test "builds the list again once an event ends" do
    on_crowded_map do
      bound
      PokeAccess::Pathfinder.invalidate_cache
      bound
      assert_equal 2, @builds
    end
  end

  private

  def bound
    goal = PokeAccess::Routes::Goal.onto(8, 1)
    PokeAccess::Pathfinder.searching { PokeAccess::Routes::Search.bound_for(goal, PokeAccess::Routes::Moves::LEDGE) }
  end

  def on_crowded_map
    bound_class = PokeAccess::Routes::Bound
    work = bound_class::WORK
    bound_class.send(:remove_const, :WORK)
    bound_class.const_set(:WORK, 0)
    moves = PokeAccess::Routes::Moves
    moves.singleton_class.send(:alias_method, :shortcuts_spec, :shortcuts)
    test_case = self
    @builds = 0
    moves.define_singleton_method(:shortcuts) do |lvl, mode|
      test_case.instance_variable_set(:@builds, test_case.instance_variable_get(:@builds) + 1)
      shortcuts_spec(lvl, mode)
    end
    $game_map.load_grid(["##########", "#@.......#", "#........#", "##########"])
    warp = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, $game_map.map_id, 8, 2])])
    $game_map.events[1] = TestGameEvent.new(:id => 1, :x => 2, :y => 1, :pages => [warp], :active_page => warp)
    @walker = World.event(:kind => :npc, :id => 2, :x => 4, :y => 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    bound_class.send(:remove_const, :WORK)
    bound_class.const_set(:WORK, work)
    moves.singleton_class.send(:alias_method, :shortcuts, :shortcuts_spec)
    moves.singleton_class.send(:remove_method, :shortcuts_spec)
    World.clear_events
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end
end

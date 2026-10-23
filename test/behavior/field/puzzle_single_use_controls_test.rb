# A puzzle control stays a target of the puzzles category only while its current page can run: a single-use valve
# (Z's ship, map 144) turns once, and its next page has no commands, so the engine never starts it again.

class PuzzleSingleUseControlsTest < PokeAccessTest
  VALVE_SWITCH = 312

  test "offers a valve as a puzzle target while it can still be turned" do
    with_valve(:unturned) do
      assert_equal [PokeAccess::I18n.t(:ship_valve1)], target_names
    end
  end

  test "leaves out a valve once its page emptied" do
    with_valve(:turned) do
      assert_equal [], target_names
    end
  end

  private

  def target_names
    PokeAccess::Puzzles.control_targets.map { |t| t.name }
  end

  def with_valve(state)
    mech = PokeAccess::World::Mechanics
    turn = TestPage.new(:trigger => 0, :sprite => "",
                        :list => [TestCmd.new(121, [VALVE_SWITCH, VALVE_SWITCH, 0]), TestCmd.new(0, [])])
    spent = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])],
                         :condition => { :switch1_valid => true, :switch1_id => VALVE_SWITCH })
    World.clear_events
    $game_map.events[6] = TestGameEvent.new(:id => 6, :x => 39, :y => 12, :pages => [turn, spent],
                                            :active_page => (state == :turned ? spent : turn))
    mech.declare($game_map.map_id, :kind => :state, :controls => true,
                 :watch => [{ :switch => VALVE_SWITCH, :label => :ship_valve1 }])
    yield
  ensure
    mech.instance_variable_set(:@defs, {})
    mech.forget
    World.clear_events
  end
end

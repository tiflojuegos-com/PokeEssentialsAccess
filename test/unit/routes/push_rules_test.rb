# A game's own rule for its pushables (Effects.push_script), as Realidea's pbPushThisBoulder, which moves a Strength
# boulder only with switch 379 on and asks for no field move: a route pushes such a boulder only while the condition
# holds, asked as it is searched, and its gate names no move. A stock Strength boulder's push names no move either
# once Strength is in use on the map, as pbPushThisBoulder then pushes it with nothing more asked.

class PushRulesTest < PokeAccessTest
  test "pushes a boulder under a game's rule only while its condition holds" do
    with_rule_and_boulder do
      $game_switches[379] = false
      assert_nil push_route
      $game_switches[379] = true
      route, gate = push_route
      assert_equal [[6, 6], 4, nil], [route.to_a, gate[:x], gate[:move]]
    end
  end

  test "names no field move for a Strength boulder once Strength is in use on the map" do
    was = $PokemonMap
    $PokemonMap = Struct.new(:strengthUsed).new(false)
    with_boulder do
      assert_equal :STRENGTH, PokeAccess::Routes::Planner.plan(7, 2, true).gate[:move]
      $PokemonMap.strengthUsed = true

      assert_nil PokeAccess::Routes::Planner.plan(7, 2, true).gate[:move]
    end
  ensure
    $PokemonMap = was
  end

  private

  def push_route
    PokeAccess::Routes::Pushes.route(PokeAccess::Routes::Goal.onto(7, 2))
  end

  # Runs the block with Realidea's rule for pbPushThisBoulder (switch 379) and its boulder.
  def with_rule_and_boulder
    fx = PokeAccess::Routes::Effects
    kept = fx.instance_variable_get(:@push_rules).dup
    fx.push_script(/pbPushThisBoulder/) { $game_switches[379] ? true : false }
    with_boulder { yield }
  ensure
    fx.instance_variable_set(:@push_rules, kept)
    $game_switches[379] = false
  end

  # Runs the block on a corridor whose way down past (7,1) a boulder that runs pbPushThisBoulder stands in.
  def with_boulder
    $game_map.load_grid(["##########", "#@.......#", "#######.##", "##########"])
    ev = World.touch(:id => 61, :name => "Boulder", :x => 4, :y => 1, :trigger => 0, :sprite => "boulder",
                     :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      !$game_map.blocked?(nx, ny)
    end
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

# A way by water that comes ashore and pushes off again: planned a crossing at a time from the water as from the ground,
# the landing said as a leg of its own, Surf asked for on each shore it leaves from, and no landing the engine closes.
class WaterChainTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Planner = PokeAccess::Routes::Planner
  Moves = PokeAccess::Routes::Moves
  T = PokeAccess::I18n
  # Two ponds with an island between them: the far shore (10..12) is reached across both, landing on (6..7).
  CHAIN = ["##############",
           "#@..~~..~~...#",
           "#...~~..~~...#",
           "##############"]
  # A pond whose upper row is closed toward the shore on its right: the way ashore is the lower row's.
  CLOSED = ["#########",
            "#@.~~}..#",
            "#..~~~..#",
            "#########"]
  # A pond below a waterfall (crest at (3,2), fall at (3,3)) whose top pond reaches the ground at (4,1).
  FALL = ["#######",
          "#@.~~.#",
          "###V###",
          "###W###",
          "###~###",
          "###~###",
          "#######"]

  test "from the ground the way goes to the first shore, its search crossing both ponds" do
    with_tile_world(CHAIN) do
      plan = Planner.plan(12, 1, true)
      assert_equal [:surf, [6, 6], 6], [plan.kind, plan.route.to_a, plan.launch]
    end
  end

  test "afloat, the way lands on the island and pushes off again from its far shore" do
    with_tile_world(CHAIN) do
      $game_player.x = 4
      $PokemonGlobal.surfing = true
      plan = Planner.plan(12, 1, true)
      assert_equal [:surf, [6, 6, 6], 6, [7, 1, 6]], [plan.kind, plan.route.to_a, plan.launch, PF.surf_plan(12, 1)]
    end
  end

  test "afloat on the last pond the way is a walk that comes ashore" do
    with_tile_world(CHAIN) do
      $game_player.x = 8
      $PokemonGlobal.surfing = true
      plan = Planner.plan(12, 1, true)
      assert_equal [:walk, [6, 6, 6, 6]], [plan.kind, plan.route.to_a]
    end
  end

  test "the press that comes ashore is a landing; on foot no press is" do
    with_tile_world(CHAIN) do
      $PokemonGlobal.surfing = true
      afloat = Moves.one_way(4, 1, 0, [6, 6, 6])
      $PokemonGlobal.surfing = false
      assert_equal [[nil, :land, nil], [nil, nil, nil]], [afloat, Moves.one_way(1, 1, 0, [6, 6, 6])]
    end
  end

  test "the route key afloat gives the water, the landing, the island and which way to surf on" do
    with_tile_world(CHAIN) do
      $game_player.x = 4
      $PokemonGlobal.surfing = true
      plan = Planner.plan(12, 1, true)
      kinds = Moves.one_way(4, 1, 0, plan.route)
      legs = [leg(1), land, leg(1), T.t(:loc_surf_way, :toward => surf_toward)].join(", ")
      assert_equal T.t(:loc_route, :steps => legs), PokeAccess::Routes::Text.line(plan, [4, 1], kinds)
    end
  end

  test "the step guide says the landing, asks for Surf on the island's far shore, and afloat again leads on" do
    with_guide_state do |loc|
      with_tile_world(CHAIN) do
        $game_player.x = 4
        $PokemonGlobal.surfing = true
        steps_aim(loc, PokeAccess::Locator::SurfaceTarget.new(12, 1, "costa", :spot))
        SpeakCapture.clear
        guide_frame
        first = SpeakCapture.lines
        ashore = walk_to(loc, 5, 1)
        $PokemonGlobal.surfing = false
        island = walk_to(loc, 6, 1)
        shore = walk_to(loc, 7, 1)
        $PokemonGlobal.surfing = true
        again = walk_to(loc, 8, 1)
        assert_equal [[leg(1)], [land], [leg(1)], [surf_toward], [leg(1)]], [first, ashore, island, shore, again]
      end
    end
  end

  test "a landing the engine closes is no way ashore; the open one is" do
    with_tile_world(CLOSED) do
      $game_player.x = 5
      $PokemonGlobal.surfing = true
      shut = Moves.step(5, 1, 0, PokeAccess::Routes::DIR_OF[6], Moves::SURF_PLAN)
      open = Moves.step(5, 2, 0, PokeAccess::Routes::DIR_OF[6], Moves::SURF_PLAN)
      assert_equal [nil, [6, 2]], [shut, open && open.tile]
    end
  end

  test "afloat below a waterfall, the water up it is no shore to push off from" do
    with_tile_world(FALL) do
      $game_player.x = 3
      $game_player.y = 5
      $PokemonGlobal.surfing = true
      foot = PokeAccess::Routes::Regions.foot
      5.times { foot.status([[1, 1]]) }
      assert_equal [true, nil, nil], [foot.done?, PF.surf_plan(4, 1), Planner.surf(4, 1)]
    end
  end

  test "afloat the camera and the trail may push off only from ground they came ashore on" do
    with_tile_world(CHAIN) do
      dry = PF.may_surf?(6, 1)
      $PokemonGlobal.surfing = true
      assert_equal [true, true, false, false], [dry, PF.may_surf?(6, 1), PF.may_surf?(4, 1), PF.may_surf?]
    end
  end

  test "a trail afloat that comes ashore and heads for the water again stops on that shore to push off" do
    with_tile_world(CHAIN) do
      $game_player.x = 4
      $PokemonGlobal.surfing = true
      conv = PokeAccess::Routes::Trail.convert((4..9).map { |x| [x, 1, 0] }, [4, 1, 0])
      assert_equal [[6, 6, 6], 6, []], [conv.route.to_a, conv.surf, conv.breaks]
    end
  end

  private

  # One leg of n presses to the right, as the guides say it.
  def leg(n)
    T.t(:loc_leg, :n => n, :dir => T.t(:dir_right))
  end

  # The landing to the right, as the guides say it.
  def land
    T.t(:loc_land_leg, :dir => T.t(:dir_right))
  end

  # The hold line on a shore pushing off to the right.
  def surf_toward
    T.t(:loc_surf_toward, :dir => T.t(:toward_right))
  end
end

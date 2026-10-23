# Crossing water on a TileWorld: the shore the route leads to is the one whose water reaches the target, where the
# guides hold saying which way to surf, and deep water over a sea is a dive spot.
class RouteWaterTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Moves = PokeAccess::Routes::Moves
  T = PokeAccess::I18n
  # The dive map's index in a gen-6 metadata row, the game's MetadataDiveMap.
  DIVE_FIELD = 8
  # An island at (10, 1) behind the right wall, reached across the lower pond from its shore at (7, 4); the upper pond
  # lies nearer the island but reaches nowhere.
  TWO_PONDS = ["############",
               "#@....~~#..#",
               "#.....~~#..#",
               "#.......#..#",
               "#.......~~~#",
               "#.......~~~#",
               "############"]

  test "the shore it pushes off from is the one whose water reaches the target, not the nearer pond's" do
    with_tile_world(TWO_PONDS) do
      walk = walk_route(10, 1)
      plan = PF.surf_plan(10, 1)
      shores = PokeAccess::Routes::Regions.foot.tiles.select do |x, y|
        PokeAccess::Routes::DIRS.any? { |d| $game_map.water?(x + d[0], y + d[1]) }
      end
      nearest = shores.map { |x, y| (x - 10).abs + (y - 1).abs }.min
      assert_equal [nil, [7, 4, 6], 5], [walk, plan, nearest],
                   "no walk to the island; the plan's shore lies six tiles off it, one the player walks to five"
    end
  end

  test "the planned way walks onto that shore and pushes off the way the search did" do
    with_tile_world(TWO_PONDS) do
      assert_equal [[2, 2, 2, 6, 6, 6, 6, 6, 6], 6], PokeAccess::Routes::Planner.surf(10, 1)
    end
  end

  test "pushing off the shore is a surf move, which on foot is no move" do
    with_tile_world(TWO_PONDS) do
      off = Moves.step(7, 4, 0, PokeAccess::Routes::DIR_OF[6], Moves::SURF_PLAN)
      assert_equal [8, 4, :surf], [off.x, off.y, off.kind], "with the surf planned"
      assert_nil Moves.step(7, 4, 0, PokeAccess::Routes::DIR_OF[6], 0), "on foot"
    end
  end

  test "a cliff over the water is no shore to push off from" do
    with_tile_world(["#########",
                     "#@..]~~.#",
                     "#...#~~.#",
                     "#....~~.#",
                     "#########"]) do
      assert_equal [4, 3, 6], PF.surf_plan(7, 1), "the ledge nearest the island is closed toward the water"
    end
  end

  test "a target water touches on one side only is reached across that side" do
    pocket = ["#############",
              "#############",
              "#@..##~######",
              "#...~~~~~~~##",
              "#...##~######",
              "######~######",
              "#############"]
    with_tile_world(pocket) do
      sides = { [6, 1] => "below", [6, 6] => "above", [11, 3] => "on its left", [5, 5] => "on its right" }
      sides.each do |(tx, ty), side|
        assert_equal [3, 3, 6], PF.surf_plan(tx, ty), "a rock with the water #{side}"
      end
    end
  end

  test "a pool reached only down a waterfall is planned for, the surf ending on the pool itself" do
    with_tile_world(["#######",
                     "#@.~~.#",
                     "###V###",
                     "###W###",
                     "###~###",
                     "#######"]) do
      assert_equal [2, 1, 6], PF.surf_plan(3, 4)
    end
  end

  test "a party that cannot surf gets no plan across the water" do
    with_tile_world(TWO_PONDS) do
      with_surf_items([]) { with_party_knowing_nothing { with_bag([:SPECBOARD]) { assert_nil PF.surf_plan(10, 1) } } }
    end
  end

  test "an item the game gives Surf to stands in for a Pokemon that knows it" do
    with_tile_world(TWO_PONDS) do
      with_surf_items([:SPECBOARD]) do
        with_party_knowing_nothing { with_bag([:SPECBOARD]) { assert_equal [7, 4, 6], PF.surf_plan(10, 1) } }
      end
    end
  end

  test "already afloat there is no shore to plan" do
    with_tile_world(TWO_PONDS) do
      $PokemonGlobal.surfing = true
      assert_nil PF.surf_plan(10, 1)
    end
  end

  test "where the game keeps the player on the bike, Surf is not offered" do
    with_tile_world(TWO_PONDS) do
      with_cycling_road { assert_nil PF.surf_plan(10, 1) }
    end
  end

  test "with someone along, a game that will not let the player surf so plans no way by water and says why" do
    with_tile_world(TWO_PONDS) do
      company(false)
      plan = PokeAccess::Routes::Planner.plan(10, 1)
      assert_equal [:company, nil], [plan.kind, plan.route]
      assert_equal ", " + T.t(:loc_surf_company), PokeAccess::Routes::Text.listing(plan)
    end
  end

  test "a game whose own check lets the company surf plans the way by water as one without the check" do
    with_tile_world(TWO_PONDS) do
      company(true)
      assert_equal [:surf, 6], [PokeAccess::Routes::Planner.plan(10, 1).kind, PokeAccess::Routes::Planner.plan(10, 1).launch]
    end
  end

  test "a game whose own Surf refuses anyone walking along plans no way by water with a dependent event following" do
    with_tile_world(TWO_PONDS) do
      with_surf_company(:dependents) do
        company(true)
        dependents(true)
        plan = PokeAccess::Routes::Planner.plan(10, 1)
        dependents(false)
        assert_equal [:company, nil, true], [plan.kind, plan.route, PF.surf_with_company?],
                     "refused with someone along whatever can_ride_vehicle_with_follower? says; alone, let"
      end
    end
  end

  test "a game whose own Surf lets the following Pokemon along by its switch refuses the company only with it off" do
    with_tile_world(TWO_PONDS) do
      on = false
      with_surf_company(:dependents, lambda { on }) do
        dependents(true)
        off = PF.surf_with_company?
        on = true
        assert_equal [false, true], [off, PF.surf_with_company?]
      end
    end
  end

  test "a game whose own Surf asks nothing of who walks along plans the way by water though its v20 check refuses" do
    with_tile_world(TWO_PONDS) do
      with_surf_company(:anyone) do
        company(false)
        dependents(true)
        assert_equal :surf, PokeAccess::Routes::Planner.plan(10, 1).kind
      end
    end
  end

  test "a game with no check of its own and no v20 one lets the player surf with anyone along" do
    with_tile_world(TWO_PONDS) do
      with_surf_company(nil) do
        dependents(true)
        assert_equal :surf, PokeAccess::Routes::Planner.plan(10, 1).kind
      end
    end
  end

  test "a change of the tiles drops the launch kept for the water: the next one pushes off where the new tiles lead" do
    rows = TWO_PONDS.map { |r| r.dup }
    with_tile_world(rows) do
      first = PF.surf_plan(10, 1)
      rows[1][8, 1] = "~"
      PokeAccess::World::Epoch.tiles_due!
      PokeAccess::World::Epoch.settle
      assert_equal [[7, 4, 6], [5, 1, 6]], [first, PF.surf_plan(10, 1)],
                   "the upper pond, opened onto the island, is pushed off from its nearest shore"
    end
  end

  test "a walker's steps leave the launch as it was, searched once; a change to an event that is no walker, again" do
    with_tile_world(TWO_PONDS) do |world|
      walker = still_tiles(world, TWO_PONDS)
      launches = counting(PokeAccess::Routes::Launch, :toward) do
        3.times do |i|
          assert_equal :surf, PokeAccess::Routes::Planner.plan(10, 1).kind
          walker.x = 3 - i % 2
          World.next_frame
        end
        world.events[41] = TestGameEvent.new(:id => 41, :x => 1, :y => 5)
        World.next_frame
        PokeAccess::Routes::Planner.plan(10, 1)
      end
      assert_equal 2, launches
    end
  end

  test "the target list says the way is across the water" do
    with_tile_world(TWO_PONDS) do
      assert_equal ", " + T.t(:loc_surf_route), PokeAccess::Locator.route_phrase(island)[1]
    end
  end

  test "L, after the list, gives the way to the shore, then the water and which way to surf" do
    with_tile_world(TWO_PONDS) do
      pick(island)
      PokeAccess::Locator.route_phrase(island)
      PokeAccess::Locator.announce_route
      legs = [leg(3, :dir_down), leg(6, :dir_right), T.t(:loc_surf_way, :toward => surf_toward(:toward_right))].join(", ")
      assert_equal [[T.t(:loc_route, :steps => legs), true]], SpeakCapture.log
    end
  end

  test "on the shore L gives which way to surf alone" do
    with_tile_world(TWO_PONDS) do
      pick(island)
      $game_player.x = 7
      $game_player.y = 4
      PokeAccess::Locator.announce_route
      assert_equal [[T.t(:loc_route, :steps => surf_toward(:toward_right)), true]], SpeakCapture.log
    end
  end

  test "on the shore the step guide says once which way to surf, and stays on" do
    with_guide_state do |loc|
      with_tile_world(TWO_PONDS) do
        $game_player.x = 7
        $game_player.y = 4
        steps_aim(loc, island)
        guide_frame
        first = SpeakCapture.log.dup
        SpeakCapture.clear
        guide_frame
        assert_equal [[[surf_toward(:toward_right), false]], [], true],
                     [first, SpeakCapture.log, PokeAccess::Guide.on?(:steps)],
                     "said on the first frame, silent on the next, the step guide still on"
      end
    end
  end

  test "deep water over a sea is listed as a dive spot in place of deep water" do
    with_dive_map(900) do
      with_tile_world(["#########",
                       "#@..DDD.#",
                       "#.......#",
                       "#########"]) do
        found = PokeAccess::Locator.scan_surfaces(1, 1).map { |t| [t.key, t.name, t.x, t.y] }
        assert_equal [[:surf_dive, T.t(:surf_dive), 4, 1]], found, "the nearest deep tile"
      end
    end
  end

  test "deep water over no sea stays deep water, with no dive spot" do
    with_dive_map(900) do
      with_tile_world(["#########",
                       "#@..DDD.#",
                       "#.......#",
                       "#########"]) do
        $game_map.map_id = 901
        assert_equal [:surf_deepwater], PokeAccess::Locator.scan_surfaces(1, 1).map { |t| t.key }
      end
    end
  end

  test "afloat on a dive spot the guides end with what the action button does there" do
    with_dive_map(900) do
      with_guide_state do |loc|
        with_tile_world(["#########",
                         "#..@DDD.#",
                         "#.......#",
                         "#########"]) do
          dive = loc.scan_surfaces(3, 1).find { |t| t.key == :surf_dive }
          $game_player.x = dive.x
          $PokemonGlobal.surfing = true
          steps_aim(loc, dive)
          guide_frame
          assert_equal [[[T.t(:loc_dive_here), true]], false], [SpeakCapture.log, PokeAccess::Guide.on?]
        end
      end
    end
  end

  test "a dive spot chosen on foot is led to its shore, where the guide says to surf" do
    with_dive_map(900) do
      with_guide_state do |loc|
        with_tile_world(["##########",
                         "#@..~~DD~#",
                         "#...~~~~~#",
                         "##########"]) do
          steps_aim(loc, loc.scan_surfaces(1, 1).find { |t| t.key == :surf_dive })
          guide_frame
          to_shore = SpeakCapture.log.dup
          shore = walk_to(loc, 3, 1)
          assert_equal [[[leg(2, :dir_right), false]], [surf_toward(:toward_right)], true],
                       [to_shore, shore, PokeAccess::Guide.on?(:steps)],
                       "the leg to the shore, there the way to surf, the step guide still on"
        end
      end
    end
  end

  private

  # The island behind the right wall of TWO_PONDS, as the locator lists a spot.
  def island
    PokeAccess::Locator::SurfaceTarget.new(10, 1, "isla", :spot)
  end

  # Gives the player the game's check for surfing with someone along (can_ride_vehicle_with_follower?), answering lets.
  def company(lets)
    $game_player.define_singleton_method(:can_ride_vehicle_with_follower?) { lets }
  end

  # Gives the player the gen-6 check for anyone walking along as a dependent event (pbHasDependentEvents?), answering
  # along.
  def dependents(along)
    $game_player.define_singleton_method(:pbHasDependentEvents?) { along }
  end

  # Runs the block with the game's own check for surfing with someone along declared as kind, with lets (none for
  # nil), the profile's put back afterwards.
  def with_surf_company(kind, lets = nil)
    was = PF.instance_variable_get(:@surf_company)
    kind ? PF.surf_company(kind, &lets) : PF.instance_variable_set(:@surf_company, nil)
    yield
  ensure
    PF.instance_variable_set(:@surf_company, was)
  end

  # Puts a walker on (2, 2) of world, drawn as rows, its tiles read off a copy of rows with no events, so that a step
  # is no change of the tiles (TileWorld's own tiles take its events in); the walker.
  def still_tiles(world, rows)
    world.instance_variable_set(:@data, TileWorld::Data.new(TileWorld.new(rows)))
    ev = TestGameEvent.new(:id => 40, :x => 2, :y => 2, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    world.events[40] = ev
    World.next_frame
    ev
  end

  # Runs the block counting the calls of mod's method name; answers the count.
  def counting(mod, name)
    was = mod.method(name)
    calls = 0
    mod.define_singleton_method(name) { |*args, &blk| calls += 1; was.call(*args, &blk) }
    yield
    calls
  ensure
    mod.define_singleton_method(name, was)
  end

  # Makes t the locator's selection.
  def pick(t)
    PokeAccess::Locator.instance_variable_set(:@target, t)
  end

  # One leg of a route as the guides say it: n presses toward the direction named by key.
  def leg(n, key)
    T.t(:loc_leg, :n => n, :dir => T.t(key))
  end

  # The hold line on a shore: surf toward the direction named by key.
  def surf_toward(key)
    T.t(:loc_surf_toward, :dir => T.t(key))
  end

  # Runs the block with only items standing in for Surf, the items registered for it put back afterwards.
  def with_surf_items(items)
    reg = PokeAccess::FieldMoves.instance_variable_get(:@items)
    saved = reg[:SURF]
    reg.delete(:SURF)
    items.each { |it| PokeAccess::FieldMoves.register_item(:SURF, it) }
    yield
  ensure
    saved ? reg[:SURF] = saved : reg.delete(:SURF)
  end

  # Runs the block with a party in which no Pokemon knows any move, the trainer's own finder put back afterwards.
  def with_party_knowing_nothing
    tr = PokeAccess::Engine.player
    tr.define_singleton_method(:get_pokemon_with_move) { |_m| nil }
    yield
  ensure
    tr.singleton_class.send(:remove_method, :get_pokemon_with_move)
  end

  # Runs the block with a bag holding one of each item given, the bag put back afterwards.
  def with_bag(items)
    had = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |item| items.include?(item) ? 1 : 0 }
    yield
  ensure
    $PokemonBag = had
  end

  # Runs the block as on a map that keeps the player on the bike (Cycling Road), MapMeta's own answer put back.
  def with_cycling_road
    meta = PokeAccess::MapMeta.singleton_class
    own = meta.instance_method(:always_bicycle?)
    meta.send(:define_method, :always_bicycle?) { |_mid| true }
    yield
  ensure
    meta.send(:define_method, :always_bicycle?, own)
  end

  # Runs the block with the gen-6 metadata giving map mid a map under its sea in field DIVE_FIELD, the stub's lack of
  # one put back.
  def with_dive_map(mid)
    Object.send(:define_method, :pbGetMetadata) { |m, idx| (m == mid && idx == DIVE_FIELD) ? 77 : nil }
    Object.send(:private, :pbGetMetadata)
    yield
  ensure
    Object.send(:remove_method, :pbGetMetadata)
  end
end

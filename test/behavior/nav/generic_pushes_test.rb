# What the routes read by themselves from any game's events: functions that push with no field move, what steps away from the
# player when walked into or used, the mark that says something can be pushed, and events that answer from one side alone.
class GenericPushesTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects

  test "any pbPushThis function but the boulder's needs no field move, and what it moves is called pushable" do
    ev = event(:name => "Boulder", :sprite => "Object boulder", :list => [TestCmd.new(355, ["pbPushThisObject"])])
    assert_equal [nil], Effects.push_move(ev)
    assert_equal t(:loc_pushable), PokeAccess::Locator.target_name(ev)
    assert_equal [:STRENGTH], Effects.push_move(event(:list => [TestCmd.new(355, ["pbPushThisBoulder"])]))
  end

  test "what moves away from the player is pushed from any side, by the action button or by touch" do
    { "by moving away" => [11], "at a speed" => [29, 11, 29], "turning to them and stepping back" => [25, 13] }.each do |what, codes|
      [0, 1, 2].each do |trigger|
        assert_equal [2, 4, 6, 8], Effects.self_push_dirs(fleeing(codes, :trigger => trigger)), "#{what}, trigger #{trigger}"
      end
    end
  end

  test "what the action button moves that way is told apart from walking into it" do
    assert_equal :act, Effects.push_facet(events.record_of(place(fleeing([11], :trigger => 0))))[1]
    assert_equal :walk, Effects.push_facet(events.record_of(place(fleeing([11], :trigger => 1))))[1]
  ensure
    World.clear_events
  end

  test "is no push when it is a person, talks, moves the player too, or goes more than a step" do
    { "a person" => fleeing([11], :sprite => "NPC 01"), "a Pokemon" => fleeing([11], :sprite => "025"),
      "what talks" => fleeing([11], :extra => [TestCmd.new(101, ["Eek!"])]),
      "the player moved too" => fleeing([11], :extra => [TestCmd.new(209, [-1, TestMoveRoute.new([TestMoveCmd.new(1), TestMoveCmd.new(0)])])]),
      "two steps" => fleeing([11, 11]) }.each do |what, ev|
      assert_equal [], Effects.self_push_dirs(ev), what
    end
  end

  test "says that what can be pushed can be, where its name does not tell" do
    assert_equal t(:loc_push_mark), Effects.push_mark(fleeing([11], :name => "Black Shard 1"))
    assert_nil Effects.push_mark(event(:name => "Sign", :list => [TestCmd.new(101, ["Hi"])])), "what cannot be"
    assert_nil Effects.push_mark(fleeing([11], :name => "Boulder")), "a name that says it"
    assert_nil Effects.push_mark(PokeAccess::Locator::SurfaceTarget.new(1, 1, "x", :puzzle_spot)), "no event"
  end

  test "an event that answers from one side is reached from that side" do
    room(["#######", "#@....#", "#.....#", "#.....#", "#######"]) do
      switch = one_sided(8, 3, 1)
      assert_equal [8], Effects.sides_facet(events.record_of(switch))
      r = walk(3, 1)
      assert_equal :found, r.status
      assert_equal [3, 2], where_it_ends(r), "from below, not beside it"
    end
  end

  test "an event several tiles wide that answers from one side is reached from the nearest tile of that side" do
    room(["#######", "#.....#", "#.....#", "#....@#", "#######"]) do
      one_sided(8, 2, 1, 70, "Machine size(3,1)")
      assert_equal [[2, 2], [3, 2], [4, 2]], Effects.act_sides(2, 1).sort
      assert_equal [4, 2], where_it_ends(walk(2, 1))
    end
  end

  test "an event several tiles tall that answers from one side is not reached from within itself" do
    room(["#######", "#.....#", "#.....#", "#....@#", "#######"]) do
      one_sided(8, 3, 2, 70, "Tall size(1,2)")
      assert_equal [[3, 3]], Effects.act_sides(3, 2)
    end
  end

  test "a route to an event ends beside it when the side it answers from cannot be got to" do
    room(["#######", "#@....#", "###.###", "#######"]) do
      one_sided(8, 3, 1)
      assert_equal [[3, 2]], Effects.act_sides(3, 1)
      r = walk(3, 1)
      assert_equal :found, r.status
      assert_equal [2, 1], where_it_ends(r)
    end
  end

  test "several sides are several tiles, and an event that answers from all four or has an else is any side" do
    room(["#######", "#@....#", "#.....#", "#.....#", "#######"]) do
      two = one_sided([8, 4], 3, 1)
      assert_equal [8, 4], Effects.sides_facet(events.record_of(two))
      assert_nil Effects.sides_facet(events.record_of(one_sided([2, 4, 6, 8], 5, 3, 71)))
      otherwise = [TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(101, ["up"], 1), TestCmd.new(0, [], 1), TestCmd.new(411, [], 0),
                   TestCmd.new(101, ["else"], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
      $game_map.events[72] = TestGameEvent.new(:id => 72, :x => 1, :y => 3, :pages => [TestPage.new(:trigger => 0, :list => otherwise)])
      events.sync(true)
      assert_nil Effects.sides_facet(events.record_of($game_map.events[72]))
    end
  end

  test "a branch on anything else besides those on facing answers from any side" do
    room(["#######", "#@....#", "#.....#", "#.....#", "#######"]) do
      list = [TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(101, ["up"], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0),
              TestCmd.new(111, [0, 50, 0], 0), TestCmd.new(101, ["any"], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
      $game_map.events[74] = TestGameEvent.new(:id => 74, :x => 3, :y => 2, :pages => [TestPage.new(:trigger => 0, :list => list)])
      events.sync(true)
      assert_nil Effects.sides_facet(events.record_of($game_map.events[74]))
    end
  end

  test "a step away that hangs from a branch goes by what the branch says now" do
    route = TestMoveRoute.new([TestMoveCmd.new(11), TestMoveCmd.new(0)])
    branch = lambda do |cond|
      event(:list => [TestCmd.new(111, cond, 0), TestCmd.new(209, [0, route], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)])
    end
    assert_equal [], Effects.self_push_dirs(branch.call([0, 3200, 0])), "a switch that is off"
    $game_switches[3200] = true
    begin
      assert_equal [2, 4, 6, 8], Effects.self_push_dirs(branch.call([0, 3200, 0])), "the same switch on"
    ensure
      $game_switches[3200] = false
    end
    assert_equal [8], Effects.self_push_dirs(branch.call([6, -1, 8])), "from one side"
  end

  test "an else with nothing in it is no else" do
    room(["#######", "#@....#", "#.....#", "#.....#", "#######"]) do
      list = [TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(101, ["up"], 1), TestCmd.new(0, [], 1), TestCmd.new(411, [], 0),
              TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
      $game_map.events[75] = TestGameEvent.new(:id => 75, :x => 3, :y => 2, :pages => [TestPage.new(:trigger => 0, :list => list)])
      events.sync(true)
      assert_equal [8], Effects.sides_facet(events.record_of($game_map.events[75]))
    end
  end

  test "an event with something besides its facing branches answers from any side" do
    room(["#######", "#@....#", "#.....#", "#.....#", "#######"]) do
      list = [TestCmd.new(250, ["bump"], 0), TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(101, ["up"], 1), TestCmd.new(0, [], 1),
              TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
      $game_map.events[73] = TestGameEvent.new(:id => 73, :x => 3, :y => 2, :pages => [TestPage.new(:trigger => 0, :list => list)])
      events.sync(true)
      assert_nil Effects.sides_facet(events.record_of($game_map.events[73]))
    end
  end

  test "a one-sided event whose side has no floor is still reached, beside it" do
    room(["#####", "#@..#", "#####"]) do
      one_sided(8, 3, 1)
      assert_equal [[3, 2]], Effects.act_sides(3, 1)
      r = walk(3, 1)
      assert_equal :found, r.status
      assert_equal [2, 1], where_it_ends(r)
    end
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def events; PokeAccess::World::Events; end

  def event(opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 1), :sprite => opts.fetch(:sprite, "object_rock"),
                        :list => opts.fetch(:list, []) + [TestCmd.new(0, [])])
    TestGameEvent.new(:id => opts.fetch(:id, 3), :name => opts.fetch(:name, "EV003"), :pages => [page])
  end

  # An event whose page sets a route on itself of these move codes.
  def fleeing(codes, opts = {})
    route = TestMoveRoute.new(codes.map { |c| TestMoveCmd.new(c) } + [TestMoveCmd.new(0)])
    event(opts.dup.merge!(:list => [TestCmd.new(209, [0, route])] + opts.fetch(:extra, [])))
  end

  def place(ev)
    $game_map.events[ev.id] = ev
    PokeAccess::World::Events.sync(true)
    ev
  end

  # An action event at (x, y) that does something only facing dirs.
  def one_sided(dirs, x, y, id = 70, name = "EV070")
    list = []
    [dirs].flatten.each do |d|
      list.concat([TestCmd.new(111, [6, -1, d], 0), TestCmd.new(101, ["It works"], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0)])
    end
    list.push(TestCmd.new(0, [], 0))
    page = TestPage.new(:trigger => 0, :sprite => "", :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    ev.blocking = true
    $game_map.events[id] = ev
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Events.sync(true)
    ev
  end

  def room(rows)
    $game_map.load_grid(rows)
    PokeAccess::World::Mechanics.forget
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  def walk(x, y); PokeAccess::Routes::Planner.walk(x, y); end

  # The tile a route leaves the player on.
  def where_it_ends(r)
    x = $game_player.x
    y = $game_player.y
    r.route.to_a.each do |d|
      dd = PokeAccess::DIR_DELTA[d]
      x += dd[0]
      y += dd[1]
    end
    [x, y]
  end
end

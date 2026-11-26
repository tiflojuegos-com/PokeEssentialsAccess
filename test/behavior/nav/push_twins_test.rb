# Pushes that move another event along (Routes::Effects.push_twins, Reborn's Mirage Tower): the branch that pushes a
# control block steps its twin the same way, the twin moving as it can though the block stays, and with the puzzle
# assist a phase's goal plans both into their tiles (Planner.carry with :with).
class PushTwinsTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Planner = PokeAccess::Routes::Planner
  # The block on (3, 2) and its twin on (7, 2), the twin walled off to its right and above it: pushed right first, the
  # block moves alone; pushed down after, both move.
  ROOM = ["##########",
          "#......#.#",
          "#.......##",
          "#........#",
          "#........#",
          "##########"]
  # A corridor sealed at its west end above two cells of one tile: the block on (3, 1) with the player east of it, the twin
  # shut in the cell (1, 3); (5, 3) a tile away from both.
  SEALED = ["##########",
            "##......##",
            "##########",
            "#.###.####",
            "##########"]

  test "a push that steps another event the same way moves it along, each way" do
    room do |block, twin|
      assert_equal({ 2 => [twin], 4 => [twin], 6 => [twin], 8 => [twin] }, Effects.push_twins(block))
    end
  end

  test "a branch that steps another event and pushes nothing has no twin" do
    room do |_block, twin|
      list = [World.if_facing(6), TestCmd.new(209, [twin.id, step_route(3)], 1), TestCmd.new(0, [], 1), World.end_]
      other = World.touch(:id => 40, :x => 2, :y => 4, :trigger => 0, :list => list)
      assert_equal({}, Effects.push_twins(other))
    end
  end

  test "the twin is tracked with the pushables, and a push of the block moves it where it can" do
    room do |block, twin|
      pieces = Effects.push_pieces
      assert_equal [:act, :along], [pieces[PokeAccess::Routes.pkey(3, 2)][2], pieces[PokeAccess::Routes.pkey(7, 2)][2]]
      assert_equal [twin], pieces[PokeAccess::Routes.pkey(3, 2)][7][6]
      assert_same block, pieces[PokeAccess::Routes.pkey(3, 2)][0]
    end
  end

  test "with the assist the plan pushes the block right first, the only order that leaves the twin on its tile" do
    room do |block, twin|
      PokeAccess::Config.puzzle_assist = true
      plan = Planner.carry(block, [4, 3, 4, 3], { twin.id => [7, 3, 7, 3] })
      assert_equal :assisted, plan.kind
      assert_equal [3, 2], [plan.gate[:x], plan.gate[:y]]
      steps = traced(1, 1, 0, plan.route.to_a)
      assert_equal [2, 2], [steps[-1].x, steps[-1].y], "it pushes from the block's left"
    end
  end

  test "with both on their tiles the plan is a walk with no steps" do
    room do |block, twin|
      PokeAccess::Config.puzzle_assist = true
      assert_equal :walk, Planner.carry(block, [3, 2, 3, 2], { twin.id => [7, 2, 7, 2] }).kind
      assert_equal :assisted, Planner.carry(block, [3, 2, 3, 2], { twin.id => [7, 3, 7, 3] }).kind,
                   "the block on its tile, the twin still off its own"
    end
  end

  test "the pushes are counted only from the tiles behind a piece the player can walk to between the pieces" do
    room(SEALED, [3, 1], [1, 3], [5, 1]) do
      key = PokeAccess::Routes.pkey(3, 1)
      twin = [[PokeAccess::Routes.pkey(1, 3), [1, 3, 1, 3], 1, 3]]
      left = lambda do |box, x, y|
        goal = PokeAccess::Routes::Pushes::RockGoal.new(key, 3, 1, box, Effects.boulder_index[key], twin)
        goal.pairs.left([[3, 1], [1, 3]], x, y)
      end
      assert_equal [1, PokeAccess::Routes::Pushes::Pairs::NEVER], [left.call([2, 1, 2, 1], 5, 1), left.call([6, 1, 6, 1], 5, 1)],
                   "a push west from the east side, none east from the west side behind the block"
      $game_player.x = 5
      $game_player.y = 3
      assert_equal 3, left.call([6, 1, 6, 1], 5, 3), "away from the pieces, any tile behind them is the route's to get to"
    end
  end

  test "a push the piece's push rule refuses is not counted" do
    room(SEALED, [3, 1], [1, 3], [5, 1]) do
      key = PokeAccess::Routes.pkey(3, 1)
      twin = [[PokeAccess::Routes.pkey(1, 3), [1, 3, 1, 3], 1, 3]]
      info = Effects.boulder_index[key].dup
      info[5] = lambda { |x, _y| x != 2 }
      goal = PokeAccess::Routes::Pushes::RockGoal.new(key, 3, 1, [2, 1, 2, 1], info, twin)
      assert_equal PokeAccess::Routes::Pushes::Pairs::NEVER, goal.pairs.left([[3, 1], [1, 3]], 5, 1)
    end
  end

  private

  # The room laid out from rows with the player on at, the block (event 30, pushed with the action button by
  # pbPushThisObject, each facing stepping event 31 too) on block_at and its twin (31) on twin_at; both stop the player and
  # move where the grid is open.
  def room(rows = ROOM, block_at = [3, 2], twin_at = [7, 2], at = [1, 1])
    $game_map.load_grid(rows)
    $game_player.x = at[0]
    $game_player.y = at[1]
    list = []
    [[2, 1], [4, 2], [6, 3], [8, 4]].each do |d, code|
      list.push(World.if_facing(d), TestCmd.new(355, ["pbPushThisObject(#{d})"], 1),
                TestCmd.new(209, [31, step_route(code)], 1), TestCmd.new(0, [], 1), World.end_)
    end
    block = piece(30, block_at[0], block_at[1], TestPage.new(:trigger => 0, :sprite => "block", :list => list + [TestCmd.new(0, [])]))
    twin = piece(31, twin_at[0], twin_at[1], TestPage.new(:trigger => 0, :sprite => "block"))
    World.next_frame
    yield block, twin
  ensure
    PokeAccess::Config.puzzle_assist = false
  end

  # A piece on (x, y) with one page: it stops the player and moves one tile where the grid's next tile is open.
  def piece(id, x, y, page)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Block", :pages => [page])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      !$game_map.blocked?(x + (d == 6 ? 1 : (d == 4 ? -1 : 0)), y + (d == 2 ? 1 : (d == 8 ? -1 : 0)))
    end
    $game_map.events[id] = ev
    ev
  end

  # A move route of one step (1 down, 2 left, 3 right, 4 up).
  def step_route(code)
    TestMoveRoute.new([TestMoveCmd.new(code), TestMoveCmd.new(0)])
  end
end

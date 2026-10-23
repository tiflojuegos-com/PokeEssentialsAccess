# Where a way across water leaves the ground (Routes::Launch, via Pathfinder.surf_plan): a shore on a shortest way for
# each target only water reaches and none otherwise, the last tile walked before the water, on either level, its budget.
class LaunchTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Pathfinder = PokeAccess::Pathfinder
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  AMPHIBIOUS = PokeAccess::Routes::Moves::LEDGE | PokeAccess::Routes::Moves::SURF_PLAN
  SEEDS = [5, 8, 13, 21, 34, 55, 89, 144].freeze
  # A shore three tiles from the player, two tiles of water, and land beyond.
  STRAIT = ["#########",
            "#@..~~..#",
            "#########"].freeze

  test "the shore for a target only water reaches lies on a way as short as brute force's, the regions walked or not" do
    [false, true].each do |walked|
      rows = water_targets(walked).select { |r| r[4] }
      assert_operator rows.length, :>, 40, "targets only water reaches (regions on foot walked: #{walked})"
      bad = rows.reject { |_seed, _x, _y, plan, presses, via| plan && via == presses }
      assert_equal [], bad.first(5), "each shore is walked to, faces water, and lies on a shortest way (#{walked})"
    end
  end

  test "a target water does not reach either gets no shore" do
    rows = water_targets(false).reject { |r| r[4] }
    assert_operator rows.length, :>, 0, "targets nothing reaches"
    assert_equal [], rows.select { |r| r[3] }.first(5), "none gets a shore"
  end

  test "a target whose cheapest way crosses no water gets no shore" do
    with_tile_world(["#######",
                     "#@....#",
                     "#~~~~~#",
                     "#######"]) do
      assert_nil Pathfinder.surf_plan(5, 1), "walking there takes three presses, swimming five"
    end
  end

  test "pushes off from the last tile the block says is walked to, straight into water it does not" do
    with_tile_world(STRAIT) do
      goal = Routes::Goal.onto(7, 1)
      cost = Routes::CostModel.new(:shortest)
      {
        3 => [3, 1, 6],
        4 => [4, 1, 6],
        1 => nil
      }.each do |last, want|
        assert_shore want, Routes::Launch.toward(goal, cost) { |x, _y| x <= last }, "walked up to x = #{last}"
      end
    end
  end

  test "finds the shore of a search that runs on a bridge's upper level, where the player stands" do
    with_tile_world(STRAIT) do
      $PokemonGlobal.bridge = 2
      assert_equal [3, 1, 6], Pathfinder.surf_plan(7, 1)
    end
  end

  test "by effort its search takes a budget of its own, however small the route budget" do
    PokeAccess::Config.astar_max = 2
    with_tile_world(STRAIT) do
      assert_equal [3, 1, 6], Pathfinder.surf_plan(7, 1)
    end
  end

  test "its search takes an estimate where no fall on the map can carry the surfer, and none where one can" do
    goal = Routes::Goal.onto(7, 1)
    { STRAIT => 1, ["#########", "#@..~W..#", "#########"] => nil }.each do |rows, want|
      est = with_tile_world(rows) { Pathfinder.searching { Routes::Search.bound_for(goal, AMPHIBIOUS) } }
      want.nil? ? assert_nil(est, rows[1]) : assert_equal(want, est, rows[1])
    end
  end

  test "under a time limit its search runs on the operation's: past the deadline it finds no shore" do
    PokeAccess::Config.route_limit = :time
    { 10000 => [3, 1, 6], -1 => nil }.each do |ms, want|
      PokeAccess::Config.route_budget_ms = ms
      with_tile_world(["#" * 30, "#@..~~" + "." * 23 + "#", "#" * 30]) do
        assert_shore want, Pathfinder.surf_plan(28, 1), "with #{ms} ms"
      end
    end
  end

  private

  # A random map of walls and ponds, its player at the top left on land.
  def water_rows(seed, w, h)
    srand(seed)
    rows = (0...h).map do |y|
      (0...w).map { |x| (x == 0 || y == 0 || x == w - 1 || y == h - 1) ? "#" : (rand(7) == 0 ? "#" : ".") }
    end
    3.times do
      x0 = 1 + rand(w - 4)
      y0 = 1 + rand(h - 4)
      (y0...[y0 + 2 + rand(3), h - 1].min).each do |y|
        (x0...[x0 + 2 + rand(4), w - 1].min).each { |x| rows[y][x] = "~" }
      end
    end
    rows[1][1] = "@"
    rows[1][2] = "."
    rows[2][1] = "."
    rows.map { |r| r.join }
  end

  # Each target of the random maps none of whose tiles can be walked to, as [seed, x, y, the plan surf_plan gives it,
  # the fewest presses brute force reaches it in across land and water (nil for none), the presses of the plan's way
  # (nil when its shore is not walked to, faces no water or reaches nothing)]; with walked, the regions on foot are
  # walked before any is asked.
  def water_targets(walked)
    out = []
    SEEDS.each do |seed|
      with_tile_world(water_rows(seed, 14, 10)) do |world|
        foot = brute_best(:shortest, LEDGE)
        amph = brute_best(:shortest, AMPHIBIOUS)
        afloat = {}
        Routes::Regions.foot.status([[0, 0]]) if walked
        assert_equal walked, Routes::Regions.foot.done?, "seed #{seed}: the regions on foot walked"
        (1...world.height - 1).each do |ty|
          (1...world.width - 1).each do |tx|
            tiles = Pathfinder::SURF_AROUND.map { |dx, dy| [tx + dx, ty + dy] }
            next if tiles.any? { |t| foot[t] }
            plan = Pathfinder.surf_plan(tx, ty)
            out.push([seed, tx, ty, plan, fewest(amph, tiles), plan && way_presses(world, plan, tiles, foot, afloat)])
          end
        end
      end
    end
    out
  end

  # The presses of the way a plan takes: walking to its shore, pushing off, and the fewest from the water in front;
  # nil when the shore is not walked to, faces no water, or the water reaches none of tiles.
  def way_presses(world, plan, tiles, foot, afloat)
    lx, ly, d = plan
    front = [lx + PokeAccess::DIR_DELTA[d][0], ly + PokeAccess::DIR_DELTA[d][1]]
    return nil unless foot[[lx, ly]] && world.water?(*front) && !foot[front]
    rest = fewest(afloat[front] ||= stand_at(*front) { brute_best(:shortest, AMPHIBIOUS) }, tiles)
    rest && foot[[lx, ly]][0] + 1 + rest
  end

  # The fewest presses brute force (best) takes to any of tiles, or nil.
  def fewest(best, tiles)
    tiles.map { |t| best[t] && best[t][0] }.compact.min
  end

  # Passes when got is the shore want ([x, y, facing]), or nil when want is.
  def assert_shore(want, got, msg)
    want ? assert_equal(want, got, msg) : assert_nil(got, msg)
  end

  # The block's value with the player moved to (x, y) for it.
  def stand_at(x, y)
    was = [$game_player.x, $game_player.y]
    $game_player.x = x
    $game_player.y = y
    yield
  ensure
    $game_player.x, $game_player.y = was
  end
end

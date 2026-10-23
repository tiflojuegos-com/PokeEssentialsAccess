# The soundscape's geometry (Sound::Scene) on the grid harness ('#' wall, '.' floor, 'C' counter, '@' player): the
# line that hides an emitter behind a wall, the side rays the wind loops measure and the merging of a structure's tiles.
class GeometryTest < PokeAccessTest
  Scene = PokeAccess::Sound::Scene
  Config = PokeAccess::Config
  # An open room, the player at its top left.
  ROOM = ["######",
          "#@...#",
          "#....#",
          "#....#",
          "######"]
  # The player at (5, 1) with the nearest wall one tile north, two east, three south and four west.
  SIDES = ["#########",
           "##...@.##",
           "#####.###",
           "#####.###",
           "#########"]

  test "a line is clear with nothing on it and blocked by one wall on it, whichever way it runs" do
    {
      "east" => [["#########", "#@......#", "#########"], ["#########", "#@..#...#", "#########"], [1, 1], [7, 1]],
      "west" => [["#########", "#......@#", "#########"], ["#########", "#...#..@#", "#########"], [7, 1], [1, 1]],
      "south" => [["###", "#@#", "#.#", "#.#", "#.#", "###"],
                  ["###", "#@#", "#.#", "###", "#.#", "###"], [1, 1], [1, 4]],
      "north" => [["###", "#.#", "#.#", "#.#", "#@#", "###"],
                  ["###", "#.#", "###", "#.#", "#@#", "###"], [1, 4], [1, 1]]
    }.each do |way, (open, walled, from, to)|
      assert_equal [true, false], [clear_on(open, from, to), clear_on(walled, from, to)], "a line running #{way}"
    end
  end

  test "walls beside the line leave it clear" do
    assert_equal true, clear_on(["#########", "#@......#", "##.#.#.##", "#########"], [1, 1], [7, 1])
  end

  test "hides an emitter that only a way around the wall reaches: it is a line, not a search" do
    assert_equal false, clear_on(["#######", "#@#...#", "#.#...#", "#.....#", "#######"], [1, 1], [5, 1])
  end

  test "never asks the step into the emitter's own tile, so a counter it stands on does not hide it" do
    {
      "a clerk on the counter beside" => [["#####", "#@C.#", "#####"], [2, 1], true],
      "a clerk on the counter below" => [["###", "#@#", "#C#", "#.#", "###"], [1, 2], true],
      "someone behind the counter" => [["#####", "#@C.#", "#####"], [3, 1], false]
    }.each do |who, (rows, at, want)|
      assert_equal want, clear_on(rows, [1, 1], at), who
    end
  end

  test "walks the line one step at a time along the axis with more distance left, the horizontal one on a tie" do
    {
      [[1, 1], [4, 3]] => [[1, 1, 6], [2, 1, 6], [3, 1, 2], [3, 2, 6]],
      [[4, 3], [1, 1]] => [[4, 3, 4], [3, 3, 4], [2, 3, 8], [2, 2, 4]]
    }.each do |(from, to), want|
      $game_map.load_grid(ROOM)
      clear = nil
      asked = steps_asked { clear = Scene.line_clear?(from[0], from[1], to[0], to[1]) }
      assert_equal [true, want], [clear, asked], "from #{from.inspect} to #{to.inspect}"
    end
  end

  test "gives up after 48 steps and reports the rest of a longer line clear" do
    { 49 => false, 50 => true }.each do |wall, want|
      assert_equal want, clear_on(corridor(wall, 60), [1, 1], [60, 1]), "a wall met at step #{wall - 1} of the line"
    end
  end

  test "still sees a wall right before an emitter at the sonar's farthest range" do
    far = Config::KIND_BOUNDS[Config.setting(:audio3d_range).kind][1]
    assert_equal false, clear_on(corridor(far, far + 1), [1, 1], [far + 1, 1]), "an emitter #{far} tiles away"
  end

  test "reads a line it cannot work out as clear" do
    assert_equal true, Scene.line_clear?(1, 1, nil, 1)
  end

  test "feels on each side the nearest wall within the wall range set, and none past it" do
    $game_map.load_grid(SIDES)
    {
      1 => { :wind_n => 1, :wind_e => nil, :wind_s => nil, :wind_w => nil },
      2 => { :wind_n => 1, :wind_e => 2, :wind_s => nil, :wind_w => nil },
      3 => { :wind_n => 1, :wind_e => 2, :wind_s => 3, :wind_w => nil },
      4 => { :wind_n => 1, :wind_e => 2, :wind_s => 3, :wind_w => 4 }
    }.each do |range, want|
      Config.audio3d_wall_range = range
      Scene.read_walls(5, 1)
      assert_equal want, Scene.walls, "with a wall range of #{range}"
    end
  end

  test "measures each side from the player's own tile outward, one step at a time up to the wall range" do
    Config.audio3d_wall_range = 2
    {
      :wind_n => [[5, 5, 8], [5, 4, 8]],
      :wind_e => [[5, 5, 6], [6, 5, 6]],
      :wind_s => [[5, 5, 2], [5, 6, 2]],
      :wind_w => [[5, 5, 4], [4, 5, 4]]
    }.each do |wind, want|
      side = PokeAccess::Sound::Catalog.entry(wind).side
      felt = :unset
      asked = steps_asked { felt = Scene.ray(5, 5, side) }
      assert_equal [nil, want], [felt, asked], "#{wind} on the open map"
    end
  end

  test "gives back no emitters, or a lone one, as they are" do
    assert_equal [[], [[4, 4, 2, "door"]]], [Scene.cluster([]), Scene.cluster([[4, 4, 2, "door"]])]
  end

  test "merges the tiles of one sprite that touch by a side or a corner, chained, into the one nearest the player" do
    {
      "a row" => [[[3, 3, 4, "door"], [4, 3, 2, "door"], [5, 3, 6, "door"]], [[4, 3, 2, "door"]]],
      "a column" => [[[7, 1, 3, "door"], [7, 2, 2, "door"]], [[7, 2, 2, "door"]]],
      "a corner" => [[[3, 3, 5, "rock"], [4, 4, 4, "rock"]], [[4, 4, 4, "rock"]]],
      "a run of five" => [(0..4).map { |i| [i, 7, 9 - i, "counter"] }, [[4, 7, 5, "counter"]]]
    }.each do |shape, (tiles, want)|
      assert_equal want, Scene.cluster(tiles), shape
    end
  end

  test "keeps apart the tiles of one sprite that do not touch, and touching tiles of different sprites" do
    {
      "two doors a tile apart" => [[[2, 2, 3, "door"], [4, 2, 5, "door"]], [[2, 2, 3, "door"], [4, 2, 5, "door"]]],
      "two doors in a column, a tile apart" => [[[6, 2, 3, "door"], [6, 4, 5, "door"]],
                                                [[6, 2, 3, "door"], [6, 4, 5, "door"]]],
      "two people side by side" => [[[4, 4, 3, "boy"], [5, 4, 4, "girl"]], [[4, 4, 3, "boy"], [5, 4, 4, "girl"]]],
      "a person beside a two-tile door" => [[[4, 4, 3, "door"], [5, 4, 4, "door"], [5, 5, 6, "boy"]],
                                            [[4, 4, 3, "door"], [5, 5, 6, "boy"]]]
    }.each do |crowd, (tiles, want)|
      assert_equal want, Scene.cluster(tiles).sort, crowd
    end
  end

  private

  # Whether line_clear? finds the line from `from` to `to` clear on a freshly loaded grid.
  def clear_on(rows, from, to)
    $game_map.load_grid(rows)
    Scene.line_clear?(from[0], from[1], to[0], to[1])
  end

  # A walled one-row corridor: the player at (1, 1), floor up to x = last and a wall at x = wall.
  def corridor(wall, last)
    row = (0..last + 1).map { |x| x == 1 ? "@" : ([0, wall, last + 1].include?(x) ? "#" : ".") }.join
    ["#" * row.length, row, "#" * row.length]
  end

  # The steps the block asks the engine's passable?, in order, as [x, y, direction].
  def steps_asked
    asked = []
    real = $game_player.method(:passable?)
    $game_player.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); real.call(x, y, d) }
    yield
    asked
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end
end

# Where the player can get to (Routes::Regions): what they reach and how many rooms away against brute force, the
# regions they name, the walker rule, what drops them, and how far questions and map frames walk.
class RegionsTest < PokeAccessTest
  Regions = PokeAccess::Routes::Regions
  Moves = PokeAccess::Routes::Moves
  LEDGE = PokeAccess::Routes::Moves::LEDGE

  test "tell what the player reaches and how many rooms away as brute force does, wherever they stand" do
    bad = []
    checked = 0
    rooms = 0
    kept = 0
    [3, 11, 29, 47, 53, 71, 89, 97].each do |seed|
      one_way_grid(seed, 12, 9)
      walked = Regions.foot
      starts = [[$game_player.x, $game_player.y]]
      brute_rooms(LEDGE).keys.sort.each_with_index { |t, i| starts.push(t) if i % 6 == 3 }
      starts.each do |x, y|
        $game_player.x = x
        $game_player.y = y
        truth = brute_rooms(LEDGE)
        checked += 1
        rooms += 1 if truth.values.any? { |r| r > 0 }
        got = told(12, 9)
        bad.push([seed, x, y, :reach]) unless got[0] == truth
        bad.push([seed, x, y, :none]) unless got[1] == tiles_of(12, 9).reject { |t| truth.key?(t) }
        kept += 1 if Regions.foot.equal?(walked)
      end
    end
    assert_operator checked, :>, 40, "starts checked"
    assert_operator rooms, :>, 5, "starts with a tile past a transfer"
    assert_equal [], bad.first(5), "every start sees what brute force does"
    assert_equal checked, kept, "the regions walked from the first start answered every start"
  end

  test "answer the player wherever they go next with the regions walked first" do
    open_room
    walked = Regions.foot
    assert_equal [:yes, 0], walked.status([[30, 10]]), "walked from the corner, the far corner is reached"
    $game_player.x = 20
    $game_player.y = 7
    World.next_frame
    assert_same walked, Regions.foot, "moved, the player is answered by the same regions"
    assert_equal [:yes, 0], Regions.foot.status([[1, 1]]), "which reach the corner they came from"
  end

  test "count the transfers on the way as rooms away, past a ledge hopped after one too" do
    hpa_fresh_grid(["##########",
                    "#@.#....##",
                    "#####.####",
                    "#...#..###",
                    "##########"])
    pad(60, 2, 1, 4, 1)
    pad(61, 6, 3, 1, 3)
    $game_map.place_ledge(5, 2, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
    { [1, 1] => [:yes, 0], [7, 1] => [:yes, 1], [5, 3] => [:yes, 1], [3, 3] => [:yes, 2], [2, 1] => [:no],
      [6, 3] => [:no] }.each do |tile, want|
      assert_equal want, Regions.foot.status([tile]), "for #{tile.inspect}"
    end
  end

  test "count the rooms away through a way that the walk's last state finds to tiles found before" do
    with_share(10) do
      hpa_fresh_grid(["##########",
                      "#@.......#",
                      "#.######.#",
                      "##########",
                      "#..#..####",
                      "##########"])
      pad(60, 1, 2, 1, 4)
      pad(61, 2, 4, 4, 4)
      pad(62, 8, 2, 5, 4)
      PokeAccess::Pathfinder.invalidate_cache(true)
      reg = Regions.foot
      reg.status([[0, 0]])
      refute reg.done?, "the share walks all but the corridor's east end"
      World.next_frame
      assert_equal [:no], reg.status([[0, 0]]), "the next frame's question walks it, finding no tile but a way"
      assert_equal [:yes, 1], reg.status([[4, 4]]), "the room behind two pads is one transfer away through the third"
    end
  end

  test "count a transfer that lands the player where it stands as a room" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    pad(60, 3, 1, 3, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [[:yes, 0], [:yes, 1], [:yes, 1]], [2, 3, 5].map { |x| Regions.foot.status([[x, 1]]) }
  end

  test "keep a one-way step one way, wherever the walk began" do
    hpa_fresh_grid(["#######",
                    "#.....#",
                    "#.....#",
                    "#.###.#",
                    "#.@#..#",
                    "#.###.#",
                    "#.....#",
                    "#######"])
    $game_map.block_step(1, 2, 2)
    $game_map.block_step(5, 2, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [:yes, 0], Regions.foot.status([[3, 1]]), "from below, the steps up reach the room above"
    $game_player.x = 3
    $game_player.y = 1
    World.next_frame
    assert_equal [[:no], [:no]], [Regions.foot.status([[3, 6]]), Regions.foot.status([[5, 3]])],
                 "from above, nothing below is"
  end

  test "tell the tiles asked about the fewest rooms away of any of them" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    pad(60, 3, 1, 3, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [:yes, 0], Regions.foot.status([[5, 1], [2, 1], [0, 0]])
  end

  test "take a walker as no wall, though the engine says it blocks" do
    walker_corridor
    refute PokeAccess::World::Probe.step?(7, 1, 2), "the walker stands in the only way down"
    assert_equal [:yes, 0], Regions.foot.status([[1, 3]])
  end

  test "stand while a walker steps about" do
    walker = walker_corridor
    reg = Regions.foot
    reg.status([[1, 3]])
    walker.x = 6
    walker.y = 3
    World.next_frame
    assert_same reg, Regions.foot
  end

  test "take a character standing still as a wall, walked afresh once it lets the player through" do
    corridor
    reg = Regions.foot
    reg.status([[1, 3]])
    still = blocker(41, 7, 2, TestPage.new(:sprite => "npc"))
    World.next_frame
    refute_same reg, Regions.foot, "its coming drops the regions"
    refute reached?(1, 3), "standing still in the way, it is a wall"
    still.through = true
    World.next_frame
    assert reached?(1, 3), "letting the player through, the regions walk past it"
  end

  test "take a character walking a move route as a walker only when the route takes a step" do
    { "a step in the route" => [[16, 1], true], "only turns in it" => [[16, 24], false] }.each do |what, (codes, past)|
      corridor
      route = TestMoveRoute.new(codes.map { |c| TestMoveCmd.new(c) })
      blocker(40, 7, 2, TestPage.new(:sprite => "npc", :move_type => 3, :move_route => route))
      World.next_frame
      assert_equal past, reached?(1, 3), "with #{what}"
    end
  end

  test "keep as a wall a walker on ice or beside it, where it stops a slide" do
    { "on the ice" => [2, 3, 4], "beside it" => [2, 3] }.each do |where, ice|
      $game_map.clear_grid
      hpa_fresh_grid(["#######",
                      "#@....#",
                      "###.###",
                      "#.....#",
                      "#######"])
      ice.each { |x| $game_map.set_terrain(x, 1, 12) }
      blocker(40, 4, 1, TestPage.new(:move_type => 1, :sprite => "npc"))
      World.next_frame
      assert_equal [], Regions.lendable_walkers, "a walker #{where} is no character to lend"
      assert_equal [:yes, 0], Regions.foot.status([[1, 3]]), "#{where}, the slide stops at it: the way down is reached"
    end
  end

  test "lend through a walker on plain ground, at the map's edge too" do
    hpa_fresh_grid(["#######",
                    "#@.....",
                    "###.###",
                    "#.....#",
                    "#######"])
    walkers = [blocker(40, 4, 1, TestPage.new(:move_type => 1, :sprite => "npc")),
               blocker(41, 6, 1, TestPage.new(:move_type => 1, :sprite => "npc"))]
    World.next_frame
    assert_equal walkers, Regions.lendable_walkers
  end

  test "keep as a wall a walker whose touch takes the player elsewhere, lending the others" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "###.###",
                    "#.....#",
                    "#######"])
    walker = blocker(40, 4, 1, TestPage.new(:move_type => 1, :sprite => "npc"))
    World.next_frame
    assert_equal [walker], Regions.lendable_walkers, "the walker alone is lent"
    page = TestPage.new(:trigger => 2, :sprite => "npc", :move_type => 1,
                        :list => [TestCmd.new(201, [0, 900, 1, 3]), TestCmd.new(0, [])])
    carrier = blocker(41, 5, 3, page)
    World.next_frame
    assert_equal [walker, carrier], PokeAccess::World::Events.walkers, "both walk about by themselves"
    assert_equal [walker], Regions.lendable_walkers, "yet the one whose touch sends the player away is not lent"
  end

  test "walk past an obstacle only in the assisted variant" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#########"])
    tree = World.event(:id => 50, :x => 4, :y => 1, :name => "Tree", :sprite => "tree")
    tree.blocking = true
    World.next_frame
    assert_equal [[:no], [:yes, 0]], [Regions.foot.status([[7, 1]]), Regions.assisted.status([[7, 1]])]
  end

  test "walk past a boulder only in the assisted variant" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#########"])
    page = TestPage.new(:trigger => 0, :sprite => "boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    blocker(50, 4, 1, page).name = "Boulder"
    World.next_frame
    assert_equal [[:no], [:yes, 0]], [Regions.foot.status([[7, 1]]), Regions.assisted.status([[7, 1]])]
  end

  test "tell no tile cannot be got to in the assisted variant while a boulder stands on ice, which stops slides" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#########"])
    (2..6).each { |x| $game_map.set_terrain(x, 1, 12) }
    page = TestPage.new(:trigger => 0, :sprite => "boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    blocker(50, 4, 1, page).name = "Boulder"
    World.next_frame
    assert_equal [:unknown], Regions.assisted.status([[3, 1]]), "the slide that stops at the boulder is not walked"
  end

  test "list every tile the player can get to, as brute force does" do
    bad = []
    [3, 29, 71].each do |seed|
      one_way_grid(seed, 12, 9)
      bad.push(seed) unless Regions.foot.tiles.sort == brute_rooms(LEDGE).keys.sort
    end
    assert_equal [], bad
  end

  test "keep the tiles listed while the player stays in one region, and list anew in another" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#.....#",
                    "#.....#",
                    "#######"])
    [1, 2, 3, 4, 5].each { |x| $game_map.place_ledge(x, 2, 2) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    above = Regions.foot.tiles
    both = (1..5).map { |x| [x, 1] } + (1..5).map { |x| [x, 3] }
    assert_equal both.sort, above.sort, "from above the ledges, both rows"
    $game_player.x = 4
    World.next_frame
    assert_same above, Regions.foot.tiles, "moved along the same side, the same list"
    $game_player.y = 3
    World.next_frame
    assert_equal (1..5).map { |x| [x, 3] }, Regions.foot.tiles.sort, "below them, only the row below"
  end

  test "name the player's region the same anywhere inside it and another past a ledge" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#.....#",
                    "#.....#",
                    "#######"])
    [1, 2, 3, 4, 5].each { |x| $game_map.place_ledge(x, 2, 2) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    reg = Regions.foot
    reg.status([[0, 0]])
    zones = [[1, 1], [5, 1], [3, 3]].map { |x, y| stand_at(x, y) { reg.zone } }
    assert_equal zones[0], zones[1], "two tiles of one side"
    refute_equal zones[0], zones[2], "and one below the ledges"
  end

  test "name one region across a tile an arrival rule owns that leaves the steps onto it plain" do
    hpa_fresh_grid(["######",
                    "#@..##",
                    "###.##",
                    "###..#",
                    "######"])
    restoring_terrain_rules do
      Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      $game_map.set_terrain(3, 1, 88)
      reg = Regions.foot
      reg.status([[0, 0]])
      zones = [[1, 1], [3, 1], [4, 3]].map { |x, y| stand_at(x, y) { reg.zone } }
      assert_equal [zones[0]] * 3, zones, "stepped onto from the west and from below, it is of the corridor's region"
    end
  end

  test "name another region past a hop a leave rule makes, though it lands on the tile in front" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    restoring_terrain_rules do
      Moves.leave_rule(:tags => [88]) { |x, y, dir| dir[2] == 6 ? [x + 1, y] : nil }
      $game_map.set_terrain(3, 1, 88)
      reg = Regions.foot
      reg.status([[0, 0]])
      zones = [[1, 1], [3, 1], [4, 1], [5, 1]].map { |x, y| stand_at(x, y) { reg.zone } }
      assert_equal [zones[0], zones[0], zones[2], zones[2]], zones, "the tiles before the hop, and those after it"
      refute_equal zones[1], zones[2], "two regions, the hop no plain step"
    end
  end

  test "tell nothing and walk nothing without a player" do
    open_room
    reg = Regions.foot
    without_player do
      assert_equal [[:unknown], [:unknown], [], nil, 0],
                   [reg.status([[3, 2]]), reg.known([[3, 2]]), reg.tiles, reg.zone, reg.renew]
    end
  end

  test "walk nothing in the map frames without a player" do
    PokeAccess::Config.regions_background = true
    settled_room
    pass_frames(10)
    without_player { Regions.tick }
    assert_equal 0, walked(Regions.foot)
  end

  test "walk nothing while the player is partway up a side stair" do
    open_room
    def $game_player.on_middle_of_stair?; true; end
    World.next_frame
    reg = Regions.foot
    assert_equal [:unknown], reg.status([[3, 2]])
    assert_equal 0, walked(reg), "no state walked"
  ensure
    $game_player.singleton_class.send(:remove_method, :on_middle_of_stair?)
    World.next_frame
  end

  test "answer from a dropped one as the regions walked anew on the map as it is now" do
    open_room
    old = Regions.foot
    old.status([[30, 10]])
    wall_off_far_corner
    assert_equal [:no], old.status([[30, 10]]), "a question"
    assert_equal [:no], old.known([[30, 10]]), "what is known"
    assert_equal 299, old.tiles.length, "the tiles"
  end

  test "renew a dropped one by walking the regions anew on the map as it is now" do
    open_room
    old = Regions.foot
    old.status([[30, 10]])
    wall_off_far_corner
    assert_equal 299, old.renew, "the room but its far corner walked by the new regions"
  end

  test "tell what is known without walking on" do
    open_room
    reg = Regions.foot
    assert_equal [:unknown], reg.known([[3, 2]])
    assert_equal 0, walked(reg), "nothing walked"
  end

  test "walk a question's share at once, then a tenth of it a frame" do
    with_share(40) do
      open_room
      reg = Regions.foot
      assert_equal [:unknown], reg.status([[30, 10]]), "past its share a far tile cannot be told"
      assert_equal 40, walked(reg), "the share walked"
      assert_equal [:unknown], reg.status([[30, 10]]), "nor can a second question in the same frame tell it"
      assert_equal 44, walked(reg), "which walks a tenth of the share"
      reg.status([[30, 10]])
      assert_equal 44, walked(reg), "and then nothing more in that frame"
      World.next_frame
      reg.status([[30, 10]])
      assert_equal 48, walked(reg), "the next frame another tenth"
    end
  end

  test "renew a cut search with a whole share more" do
    with_share(40) do
      open_room
      reg = Regions.foot
      2.times { reg.status([[30, 10]]) }
      assert_equal 40, reg.renew, "the share walked again at once"
      assert_equal 84, walked(reg)
    end
  end

  test "renew under a deadline as a question walks" do
    open_room
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    assert_equal 8, Regions.foot.renew, "the states before the clock is first read"
  end

  test "walk nothing in a map frame's slice once dropped" do
    with_share(40) do
      open_room
      old = Regions.foot
      old.status([[30, 10]])
      Regions.forget
      assert_equal 0, old.slice(2)
    end
  end

  test "walk the whole map at once with no route limit" do
    PokeAccess::Config.route_limit = :none
    with_share(40) do
      open_room
      reg = Regions.foot
      assert_equal [:yes, 0], reg.status([[30, 10]])
      assert reg.done?, "walked to the end"
    end
  end

  test "walk under a deadline the first states at least, telling only what they reach" do
    open_room
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    reg = Regions.foot
    assert_equal [:unknown], reg.status([[30, 10]]), "cut short, a far tile cannot be told"
    assert_equal 8, walked(reg), "the states before the clock is first read"
    refute reg.done?, "nor is the walk done"
    assert_equal [:yes, 0], reg.status([[3, 2]]), "while a near one is told"
  end

  test "go on under a deadline frame after frame to the end with the same regions" do
    open_room
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    reg = Regions.foot
    frames = 0
    until reg.done? || frames > 100
      World.next_frame
      reg.status([[30, 10]])
      frames += 1
    end
    assert_operator frames, :>, 1, "it took several frames"
    assert reg.done?, "it got to the end"
    assert_same reg, Regions.foot
    assert_equal [[:yes, 0], [:no]], [reg.status([[30, 10]]), reg.status([[0, 0]])], "the far tile and a wall told"
  end

  test "walk nothing in the map frames with regions_background off" do
    PokeAccess::Config.regions_background = false
    settled_room
    pass_frames(10)
    Regions.tick
    assert_equal 0, walked(Regions.foot)
  end

  test "walk on in the map frames with regions_background on: on foot, then by water, then assisted" do
    PokeAccess::Config.regions_background = true
    settled_room
    pass_frames(10)
    assert tick_until { Regions.foot.done? }, "the regions on foot walked to the end"
    assert_equal [:yes, 0], Regions.foot.known([[30, 10]]), "where they tell the far tile"
    assert_equal 0, walked(Regions.water), "before any by water"
    assert tick_until { Regions.water.done? }, "then those by water"
    assert_equal 0, walked(Regions.assisted), "before the assisted ones"
    assert tick_until { Regions.assisted.done? }, "then the assisted ones, as a game's assisted step could help"
  end

  test "leave the assisted regions to the questions in the map frames where nothing could assist" do
    PokeAccess::Config.regions_background = true
    without_assist_sources do
      settled_room
      pass_frames(10)
      assert tick_until { Regions.water.done? }, "the map frames walked the regions by water to the end"
      3.times { Regions.tick }
      assert_equal 0, walked(Regions.assisted), "the map frames after them walk none of the assisted ones"
    end
  end

  test "rest ten map frames after a drop before walking again" do
    PokeAccess::Config.regions_background = true
    settled_room
    Regions.forget
    pass_frames(9)
    Regions.tick
    assert_equal 0, walked(Regions.foot), "nine frames after it, nothing walked"
    pass_frames(1)
    Regions.tick
    assert_operator walked(Regions.foot), :>, 0, "the tenth walks on"
  end

  private

  # Every tile of a w x h map as the regions on foot tell it: [{ [x, y] => rooms away } of those they reach, the
  # tiles they say cannot be got to, in order].
  def told(w, h)
    reg = Regions.foot
    yes = {}
    no = []
    tiles_of(w, h).each do |t|
      s = reg.status([t])
      yes[t] = s[1] if s[0] == :yes
      no.push(t) if s[0] == :no
    end
    [yes, no]
  end

  # Every tile of a w x h map, column by column.
  def tiles_of(w, h)
    (0...w).to_a.product((0...h).to_a)
  end

  # A random grid (random_route_grid with ice and three pads) with eight steps shut one way at random.
  def one_way_grid(seed, w, h)
    random_route_grid(seed, w, h, true, 3)
    srand(seed * 7)
    8.times { $game_map.block_step(1 + rand(w - 2), 1 + rand(h - 2), [2, 4, 6, 8][rand(4)]) }
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A 30 x 10 room with the player in its top left corner, every tile of it reached on foot.
  def open_room
    rows = ["#" * 32, "#@" + "." * 29 + "#"]
    9.times { rows.push("#" + "." * 30 + "#") }
    rows.push("#" * 32)
    hpa_fresh_grid(rows)
  end

  # Shuts both steps into the room's far corner, (30, 10), which drops the regions with the tiles changed.
  def wall_off_far_corner
    $game_map.block_step(29, 10, 6)
    $game_map.block_step(30, 9, 2)
  end

  # The room (open_room) with the world settled on it, so the map is no longer new: settling on a new map drops the
  # regions and rests the map frames.
  def settled_room
    open_room
    Regions.foot
  end

  # A corridor with one way down, at (7, 2).
  def corridor
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#######.#",
                    "#.......#",
                    "#########"])
  end

  # The corridor with a walker (at random, id 40) standing in its way down; the walker.
  def walker_corridor
    corridor
    walker = blocker(40, 7, 2, TestPage.new(:move_type => 1, :sprite => "npc"))
    World.next_frame
    walker
  end

  # A blocking event with one page at (x, y), placed on the map.
  def blocker(id, x, y, page)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
    ev.blocking = true
    $game_map.events[id] = ev
    ev
  end

  # A touch event at (x, y) that sends the player to (tx, ty) of the same map.
  def pad(id, x, y, tx, ty)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0, $game_map.map_id, tx, ty])])
  end

  # How many states the walk has taken: what a question's, a renewal's and a map frame's budgets count.
  def walked(reg)
    reg.instance_variable_get(:@head)
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

  # Runs map frames' walks (Regions.tick) until the block is true, 500 at most; whether it came true.
  def tick_until
    500.times do
      return true if yield
      Regions.tick
    end
    yield
  end

  # Runs the block as in a game with no assisted step registered, the registered ones put back afterwards.
  def without_assist_sources
    was = Moves.instance_variable_get(:@assist_sources)
    Moves.instance_variable_set(:@assist_sources, [])
    Moves.forget_map
    yield
  ensure
    Moves.instance_variable_set(:@assist_sources, was)
    Moves.forget_map
  end

  # Runs the block with the arrival and leave rules registered now put back afterwards, the map's scan dropped both
  # ways.
  def restoring_terrain_rules
    was = [:@arrival_rules, :@leave_rules].map { |v| [v, Moves.instance_variable_get(v).dup] }
    Moves.forget_map
    yield
  ensure
    was.each { |v, rules| Moves.instance_variable_set(v, rules) }
    Moves.forget_map
  end

  # Runs the block with no player on the map, the player put back afterwards.
  def without_player
    was = $game_player
    $game_player = nil
    yield
  ensure
    $game_player = was
  end

  # Counts n more map frames, as the engine's would, the world marked unsettled.
  def pass_frames(n)
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + n)
    World.next_frame
  end

  # Runs the block with the regions on foot sharing share states out to their questions, dropped before and after.
  def with_share(share)
    was = Regions::VARIANTS
    Regions.send(:remove_const, :VARIANTS)
    Regions.const_set(:VARIANTS, was.merge(:foot => [was[:foot][0], share]))
    Regions.forget
    yield
  ensure
    Regions.send(:remove_const, :VARIANTS)
    Regions.const_set(:VARIANTS, was)
    Regions.forget
  end
end

# Pokemon Reborn's puzzles as the review of part rb2 left them (games/reborn/puzzles/): Once Upon a Somewhere's exits
# and bridge, Labradorra Gym's foes and jump tiles, Pyrous Mountain's glowing rocks and the Meteor grunts' stealth in
# Rhodochrine Jungle. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesRb2Test < PokeAccessTest
  include TileWorldHelpers

  SWITCHES = [174, 175, 176, 177, 874, 1098, 1786]
  VARS = [62, 77, 352, 361, 380, 478]
  WORDS = { "es" => %w[norte este], "en" => %w[north east], "fr" => %w[nord est], "de" => %w[Nord Ost],
            "pl" => %w[północ wschod], "pt" => %w[norte leste] }
  STEALTH_FAILURES = [[115, 102], [113, 101], [113, 98], [114, 97], [112, 96], [114, 103], [112, 100], [114, 102]]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::RebornJumpTiles.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Once Upon a Somewhere counts every exit north or east, and the same exit south only once in a row" do
    on_map(696, 31, 23)
    3.times { wrap(2) }
    assert_equal 1, $game_variables[380], "after a wrap south the next one south does not count"
    assert_equal [:rbb_some_hint, { :n => 2 }], PokeAccess::RebornSomewhere.hint
    [0, 2, 4].each do |kept|
      [8, 6].each do |dir|
        $game_variables[361] = kept
        was = $game_variables[380]
        wrap(dir)
        assert_equal was + 1, $game_variables[380], "an exit #{dir} after 361 at #{kept}"
      end
    end
  end

  test "Once Upon a Somewhere's hint names the north and east edges in every language" do
    WORDS.each do |lang, (north, east)|
      text = PokeAccess::I18n.table(lang)["rbb_some_hint"].to_s
      assert_includes text, north, lang
      assert_includes text, east, lang
      assert_includes text, "%{n}", lang
    end
    refute_match(/any edge/, PokeAccess::I18n.table("en")["rbb_some_hint"].to_s)
  end

  test "Once Upon a Somewhere keeps the bridge's title for the info key as the player comes and goes by it" do
    on_map(696, 31, 23)
    $game_variables[380] = 3
    frame
    lines = frame { $game_player.x, $game_player.y = 50, 30 }
    lines += frame { $game_player.x, $game_player.y = 31, 23 }
    lines += frame { $game_player.x, $game_player.y = 50, 30 }
    refute_includes lines.join(" "), "rbb_some_bridge_seen"
    assert_includes info_key, "rbb_some_bridge_seen"
  end

  test "Labradorra's foes are named by the species their sprite shows, not by their misspelt event names" do
    on_map(779, 26, 50)
    with_species(:AERODACTYL => 142, :DRUDDIGON => 621) do
      aerodactyl = place(100, 25, 29, "16-AerodactlylA", 0, "pkmn_aerodactyl")
      druddigon = place(109, 9, 42, "25-DruddgonC", 0, "pkmn_druddigon")
      knight = place(88, 33, 56, "4-KnightA", 0, "trchar148")
      assert_equal "Especie142", PokeAccess::Puzzles.piece_name(aerodactyl)
      assert_equal "Especie621", PokeAccess::Puzzles.piece_name(druddigon)
      assert_equal "{rbc2_labradorra_knight}", PokeAccess::Puzzles.piece_name(knight)
    end
  end

  test "Labradorra's jump tiles hop onto a tile walled in but for the jump tile behind" do
    with_tile_world(["#######", "#######", "###.###", "###.###", "#..@..#", "#.....#", "#######"]) do |world|
      world.map_id = 779
      world.events[3] = jump_tile(3, 3, 3, 8 => [0, -2])
      PokeAccess::RebornJumpTiles.forget
      assert_equal [3, 2], step_up
    end
  end

  test "Labradorra's chained jump tiles read as their pages in Map779 run: hops added up, the else for the other facings" do
    world_rows = ["#########"] + ["#.......#"] * 6 + ["#@......#", "#########"]
    with_tile_world(world_rows) do |world|
      world.map_id = 779
      up = hops([0, -1], [0, -1])
      down = hops([0, 1], [0, 1])
      world.events[65] = touch_tile(65, 6, 4, [
        TestCmd.new(111, [1, 478, 0, 19, 1], 0), TestCmd.new(122, [784, 784, 0, 6, 103, 0], 1),
        TestCmd.new(111, [1, 784, 0, 33, 0], 1), TestCmd.new(115, [], 2), TestCmd.new(0, [], 2),
        TestCmd.new(412, [], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0),
        TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(209, [-1, up], 1), TestCmd.new(0, [], 1),
        TestCmd.new(411, [], 0), TestCmd.new(209, [-1, down], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [], 0),
        TestCmd.new(0, [], 0)])
      world.events[66] = touch_tile(66, 4, 2, [TestCmd.new(209, [-1, hops([-2, 0], [-1, 1])], 0), TestCmd.new(0, [], 0)])
      world.events[68] = touch_tile(68, 3, 6, [
        TestCmd.new(111, [6, -1, 6], 0), TestCmd.new(209, [-1, hops([2, 0], :turn_up, [-1, -1])], 1),
        TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)])
      jumps = PokeAccess::RebornJumpTiles
      jumps.forget
      assert_equal({ 8 => [0, -2], 2 => [0, 2], 4 => [0, 2], 6 => [0, 2] }, jumps.table[[6, 4]])
      assert_equal({ 2 => [-3, 1], 4 => [-3, 1], 6 => [-3, 1], 8 => [-3, 1] }, jumps.table[[4, 2]])
      assert_equal({ 6 => [1, -1] }, jumps.table[[3, 6]])
      assert_equal [6, 3], jumps.hop(6, 5, 8)
      assert_equal [6, 5], jumps.hop(6, 3, 2), "facing down takes the else"
      assert_equal [2, 3], jumps.hop(5, 2, 4), "no branch: any facing"
      assert_equal [3, 5], jumps.hop(2, 6, 6)
      assert_nil jumps.hop(3, 7, 8)
    end
  end

  test "Pyrous B2F's rock is named glowing while it glows for the Turtonator, and not once it is plain" do
    on_map(200, 10, 6)
    $game_variables[352] = 1
    rock = place(5, 10, 5, "Rock", 0, "rocksmash3b")
    assert_equal "{rba_pm_glowing_rock}", PokeAccess::Puzzles.piece_name(rock)
    rock.character_name = "rocksmash3"
    assert_nil PokeAccess::Puzzles.piece_name(rock)
  end

  test "the stealth way keeps off the failure tiles a tile at a time, from the upper entrance tile to their north" do
    way = PokeAccess::RebornStealth::WAY
    assert_equal [118, 101], way.first
    assert_empty way & STEALTH_FAILURES
    way.each_cons(2) { |a, b| assert_equal 1, (a[0] - b[0]).abs + (a[1] - b[1]).abs, "#{a.inspect} to #{b.inspect}" }
    assert(STEALTH_FAILURES.all? { |_x, y| y > way.last[1] })
  end

  test "the stealth hint walks the way on from the tile the player stands on" do
    stealth = PokeAccess::RebornStealth
    on_map(150, 118, 101)
    $game_switches[1786] = true
    whole = legs([4, 4], [8, 1], [4, 1], [8, 1], [4, 1], [8, 2], [6, 1], [8, 2])
    assert_equal [:rbf_stealth_hint, { :steps => whole }], stealth.hint
    $game_player.y = 102
    assert_equal [:rbf_stealth_hint, { :steps => legs([8, 1], [4, 4], [8, 1], [4, 1], [8, 1], [4, 1], [8, 2], [6, 1],
                                                      [8, 2]) }], stealth.hint
    $game_player.x, $game_player.y = 112, 99
    assert_equal [:rbf_stealth_hint, { :steps => legs([8, 2], [6, 1], [8, 2]) }], stealth.hint
    $game_player.x, $game_player.y = 109, 101
    assert_equal [:rb2_stealth_hint_entrance, { :steps => whole }], stealth.hint
    $game_player.x, $game_player.y = 115, 95
    assert_nil stealth.hint
  end

  test "the stealth hint comes on the info key with the assist alone" do
    on_map(150, 118, 102)
    $game_switches[1786] = true
    World.next_frame
    refute_includes info_key, "rbf_stealth_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "rbf_stealth_hint steps=#{legs([8, 1], [4, 4])}"
  end

  private

  # One wrap as the 62 edges of map 696 run it: 62 takes the facing, 380 grows when it differs from 361, then 361
  # takes the facing through four branches in a row (2 to 8, 4 to 6, 6 to 4, 8 to 2), none of them an else.
  def wrap(dir)
    $game_variables[62] = dir
    $game_variables[380] += 1 if $game_variables[361] != $game_variables[62]
    kept = dir
    kept = 8 if kept == 2
    kept = 6 if kept == 4
    kept = 4 if kept == 6
    kept = 2 if kept == 8
    $game_variables[361] = kept
  end

  # The legs as Routes::Text.steps says them, keyed.
  def legs(*runs)
    keys = { 2 => "dir_down", 4 => "dir_left", 6 => "dir_right", 8 => "dir_up" }
    runs.map { |d, n| "{loc_leg dir={#{keys[d]}} n=#{n}}" }.join(", ")
  end

  def with_species(consts)
    consts.each { |k, v| PBSpecies.const_set(k, v) }
    yield
  ensure
    consts.each_key { |k| PBSpecies.send(:remove_const, k) if PBSpecies.const_defined?(k) }
  end

  # A jump tile as Obsidia Slums' and Labradorra's: a touch page that, on the player's facing, jumps them by jumps[d].
  def jump_tile(id, x, y, jumps)
    list = []
    jumps.each do |d, (dx, dy)|
      route = Struct.new(:list).new([TestCmd.new(14, [dx, dy]), TestCmd.new(0, [])])
      list.push(TestCmd.new(111, [6, -1, d], 0), TestCmd.new(209, [-1, route], 1), TestCmd.new(412, [], 0))
    end
    list.push(TestCmd.new(0, [], 0))
    page = TestPage.new(:trigger => 1, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.blocking = true
    ev
  end

  # A touch event drawn with a solid tile whose page is list.
  def touch_tile(id, x, y, list)
    page = TestPage.new(:trigger => 1, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.blocking = true
    ev
  end

  # A route of the player's as Labradorra's chained tiles write it: through on, each hop with a wait and a sound before
  # it (:turn_up turns the player up), through off.
  def hops(*moves)
    list = [TestMoveCmd.new(37)]
    moves.each do |m|
      list.push(m == :turn_up ? TestMoveCmd.new(19) : [TestMoveCmd.new(15, [4]), TestMoveCmd.new(14, m), TestMoveCmd.new(44, [])])
    end
    TestMoveRoute.new(list.flatten + [TestMoveCmd.new(38), TestMoveCmd.new(0)])
  end

  # Where a press up from (3, 4) lands, as the routes play it, or nil when it goes nowhere.
  def step_up
    up = PokeAccess::Routes::DIRS.find { |v| v[2] == 8 }
    s = PokeAccess::Pathfinder.searching { PokeAccess::Routes::Moves.step(3, 4, 0, up, PokeAccess::Pathfinder.replay_mode) }
    s && [s.x, s.y]
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rb2_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rb2_kept_t)
    i18n.send(:remove_method, :rb2_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end
end

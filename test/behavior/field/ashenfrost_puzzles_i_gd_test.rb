# Pokemon Ashen Frost's puzzles of part I (games/ashenfrost/): Return to Fogdale Isle (the cave's mud, the camp's snow,
# the cabin's basket and the valley's trees), the Mossy Monument's Unown stones, the Smuggling Tunnels' stairs as the
# routes take them, the Serenity sewers' hint where a room has no name, TargetBot's count and the Lonardo cameras.
# Without the assist, what the screen shows; with it, the way.
class AshenfrostPuzzlesIGdTest < PokeAccessTest
  SWITCHES = [71, 130, 142, 143, 144, 290, 365, 412, 413, 414, 415, 416, 417]
  VARIABLES = [74, 258, 373, 374, 375, 377]

  def setup
    super
    keyed
    declare
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    $game_self_switches = {}
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Jellybean's mud is named while she sniffs, and the assist leads to her, counts the mud and leaves out the sniffed" do
    fog = PokeAccess::AshenFogdaleReturn
    on_map(695)
    mud = place(9, 23, 7, :sprite => "HiddenItem_Smell_Yellow")
    place(23, 20, 10, :sprite => "HiddenItem_Smell_Black")
    place(26, 8, 14, :sprite => "HiddenItem_Smell_Green")
    place(20, 15, 9, :sprite => "Kiddo_Ivan")
    place(21, 18, 9, :sprite => "Truffles_walk")
    $game_variables[373] = 2
    refute_includes info_key, "afi_cave"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afi_cave_ivan}"
    $game_self_switches[[695, 21, "A"]] = true
    assert_includes info_key, "{afi_cave_jellybean}"
    $game_switches[71] = true
    assert_equal "{afi_mud_smell}", PokeAccess::Puzzles.piece_name(mud)
    assert_equal "{afb_smell}", PokeAccess::Puzzles.piece_name($game_map.events[26])
    assert_includes info_key, "{afi_cave_mud}"
    assert_includes listed, [23, 7, "{afi_mud_smell}"]
    $game_self_switches[[695, 9, "A"]] = true
    $game_variables[374] = 1
    assert_equal 1, fog.mud_found
    refute listed.any? { |x, y, _n| [x, y] == [23, 7] }, "sniffed, with the assist"
    assert_includes info_key, "afi_mud_found"
    $game_variables[374] = 4
    refute_includes info_key, "afi_cave_mud"
  end

  test "the camp's five snow piles share one name, the Ninja's too, and the assist counts them and sends to the basket" do
    on_map(795)
    piles = [[16, 21, 15], [17, 32, 11], [18, 29, 15], [19, 35, 12], [20, 27, 17]].map do |id, x, y|
      place(id, x, y, :sprite => "NPC_30", :name => id == 19 ? "Ninja Snow Pile" : "Snow Pile")
    end
    $game_variables[375] = 3
    assert_equal ["{afi_snow_pile}"], piles.map { |p| PokeAccess::Puzzles.piece_name(p) }.uniq
    refute_includes info_key, "afi_snow_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afi_snow_hint}"
    assert_includes listed, [35, 12, "{afi_snow_pile}"]
    $game_self_switches[[795, 19, "A"]] = true
    $game_variables[377] = 1
    refute listed.any? { |x, y, _n| [x, y] == [35, 12] }, "the Ninja stays drawn once fought"
    assert_includes info_key, "afi_snow_piles"
    place(5, 23, 11, :sprite => "doors31", :trigger => 1)
    $game_variables[377] = 5
    $game_variables[375] = 4
    assert_includes info_key, "{afi_basket_door}"
    on_map(796)
    place(5, 18, 31, :sprite => "Object_Basket")
    $game_variables[375] = 4
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afi_basket_take}"
    assert listed.any? { |x, y, _n| [x, y] == [18, 31] }, "the basket, the right way"
    $game_variables[375] = 5
    refute_includes info_key, "afi_basket"
  end

  test "the valley's small trees hide which are Sudowoodo, and the assist cuts the east ones until they fall" do
    on_map(798)
    tree = place(28, 36, 20, :sprite => "Object_Cut_Tree", :name => "Cut Tree (Sudowoodo)")
    assert_equal "{afi_small_tree}", PokeAccess::Puzzles.piece_name(tree)
    $game_variables[375] = 7
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afi_trees_hint}"
    $game_self_switches[[798, 28, "A"]] = true
    refute_includes info_key, "afi_trees_hint"
  end

  test "the monument's Unown stones are named, and the assist sends to Alice first, then to a stone, until one counts" do
    on_map(794)
    stones = (3..6).map { |id| place(id, 8 + id, 7, :name => "Achoo!") }
    assert_equal "{afi_unown_stone}", PokeAccess::Puzzles.piece_name(stones[0])
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afi_mossy_alice_first}"
    $game_switches[365] = true
    assert_includes info_key, "{afi_mossy_stone}"
    $game_self_switches[[794, 4, "B"]] = true
    refute_includes info_key, "afi_mossy"
  end

  test "the routes leave by the tunnels' stairs where the ride ends, only in the switch states that let it run" do
    tunnels = PokeAccess::AshenSmugglingTunnels
    on_map(405)
    tunnels::STAIR_HOPS.each do |key, (lands, codes)|
      assert_equal 64, codes.length, key.inspect
      assert codes.delete("-").chars.all? { |c| (1..lands.length).include?(c.to_i(36)) }, key.inspect
    end
    assert_equal [7, 46], leave(7, 39, 2), "the west stairs run in every state"
    assert_nil leave(24, 9, 2), "red spikes up"
    assert_nil leave(24, 9, 8), "no stairs that way"
    assert_nil leave(24, 8, 2), "no stairs from beside them"
    assert_equal [41, 9], leave(41, 15, 8), "up onto black I's spikes, raised"
    assert_equal [41, 15], leave(41, 9, 2), "and back down from them"
    $game_switches[142] = true
    assert_equal [24, 13], leave(24, 9, 2)
    assert_equal [24, 9], leave(24, 13, 8)
    assert_nil leave(27, 52, 2), "green spikes up"
    assert_nil leave(27, 55, 8), "green spikes up, from Francis' tile"
    $game_switches[144] = true
    assert_equal [27, 55], leave(27, 52, 2)
    assert_equal [27, 52], leave(27, 55, 8)
    $game_switches[143] = true
    assert_nil leave(24, 9, 2), "blue raised closes the top stairs"
  end

  test "the Serenity sewers' hint says how many are left where a room gives no name, the rooms where all do" do
    sl = PokeAccess::AshenSerenityLabs
    $game_switches[130] = true
    [412, 413, 414].each { |s| $game_switches[s] = true }
    loc = PokeAccess::Locator.singleton_class
    loc.send(:alias_method, :afi_kept_map_name, :map_name)
    names = { 324 => "Serenity Labs - Freight Room", 325 => "Serenity Labs - Shipyard", 327 => "" }
    loc.send(:define_method, :map_name) { |m| names[m] }
    assert_equal [:afi_sl_sewers_left, { :n => 3 }], sl.sewers_hint
    i18n = PokeAccess::I18n
    one = i18n.interpolate(i18n.table(i18n.lang)["afi_sl_sewers_left.one"], :n => 1)
    assert_equal one, i18n.afi_kept_t(:afi_sl_sewers_left, :n => 1), "one sewer takes the singular form"
    names[327] = "Serenity Labs - House Storage"
    hint = sl.sewers_hint
    assert_equal :afg_sl_sewers_hint, hint[0]
    assert_includes hint[1][:rooms], "Serenity Labs - House Storage"
  ensure
    loc.send(:alias_method, :map_name, :afi_kept_map_name) if loc && loc.method_defined?(:afi_kept_map_name)
  end

  test "TargetBot's count is the info key's while targets stand, not in the valley any other way in leaves without them" do
    on_map(691)
    $game_variables[258] = 7
    assert_includes info_key, "afi_targets"
    $game_variables[258] = 20
    refute_includes info_key, "afi_targets"
    $game_variables[258] = 0
    $game_switches[290] = true
    refute_includes info_key, "afi_targets", "switch 290 on: the twenty with no graphic"
  end

  test "the Lonardo feed's assist takes each camera's task, then the camera with one left" do
    feed = PokeAccess::AshenLonardoCameras
    assert_equal 1, feed.camera
    assert_equal({ :var => 380 }, feed.choice, "camera 1: the register")
    $game_self_switches[[800, 3, "A"]] = true
    assert_equal({ :self => "C" }, feed.choice, "on to camera 3")
    $game_self_switches[[800, 2, "C"]] = true
    assert_equal 3, feed.camera
    assert_equal({ :var => 380 }, feed.choice, "camera 3: the phone")
    $game_self_switches[[800, 2, "D"]] = true
    assert_equal({ :self => "B" }, feed.choice, "on to camera 2")
    $game_self_switches[[800, 2, "C"]] = false
    $game_self_switches[[800, 2, "B"]] = true
    assert_equal({ :var => 380 }, feed.choice, "camera 2: the vending machine")
    $game_self_switches[[800, 7, "A"]] = true
    assert_nil feed.choice
  end

  test "with camera 1 the one left, the feed's assist names the switch of cameras and then camera 1" do
    feed = PokeAccess::AshenLonardoCameras
    on_map(800)
    ev = place(2, 0, 1)
    $game_self_switches[[800, 7, "A"]] = true
    $game_self_switches[[800, 2, "D"]] = true
    $game_self_switches[[800, 2, "B"]] = true
    assert_equal "Switch cameras.", right_option(camera_menu, 0)
    assert_nil right_option(camera_menu, 10), "both cameras clear camera 2's switch"
    reach = PokeAccess::World::Mechanics.entries_for(:reaches, ev)[0]
    assert_match reach[:text], "\\xn[Radon]\\c[21]Which camera?"
    assert_equal :afi_lonardo_first, PokeAccess::World::Mechanics.label_now(reach[:label], ev)
    $game_self_switches[[800, 2, "B"]] = false
    $game_self_switches[[800, 2, "C"]] = true
    assert_equal({ :self => "C" }, feed.choice, "camera 3: its own switch")
    assert_equal :afi_lonardo_first, feed.camera_line
    $game_self_switches[[800, 2, "C"]] = false
    assert_equal({ :var => 380 }, feed.choice, "camera 1: the register")
    assert_equal "", feed.camera_line
  end

  def declare
    was = $VERBOSE
    $VERBOSE = nil
    Harness.load_puzzles("ashenfrost")
  ensure
    $VERBOSE = was
  end

  def on_map(map)
    declare
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles::Auto.forget
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, opts = {})
    list = [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def leave(x, y, d)
    PokeAccess::Routes::Moves.departure(x, y, PokeAccess::Routes::DIRS.find { |v| v[2] == d })
  end

  # Camera 2's menus as the feed's page holds them: the first one's at 0, the cameras' at 10.
  def camera_menu
    [TestCmd.new(102, [["Inspect area.", "Inspect electronics?", "Switch cameras.", "Nothing."], 4], 0),
     TestCmd.new(402, [0, "Inspect area."], 0), TestCmd.new(101, ["..."], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [1, "Inspect electronics?"], 0), TestCmd.new(122, [380, 380, 1, 0, 1], 1),
     TestCmd.new(201, [0, 208, 6, 10, 0, 0], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [2, "Switch cameras."], 0), TestCmd.new(101, ["\\xn[Radon]\\c[21]Which camera?"], 1),
     TestCmd.new(102, [["Camera 1", "Camera 3", "Cancel"], 3], 1),
     TestCmd.new(402, [0, "Camera 1"], 1), TestCmd.new(123, ["B", 1], 2), TestCmd.new(201, [0, 800, 8, 7, 0, 0], 2),
     TestCmd.new(0, [], 2),
     TestCmd.new(402, [1, "Camera 3"], 1), TestCmd.new(123, ["B", 1], 2), TestCmd.new(123, ["C", 0], 2),
     TestCmd.new(201, [0, 800, 30, 25, 0, 0], 2), TestCmd.new(0, [], 2),
     TestCmd.new(402, [2, "Cancel"], 1), TestCmd.new(0, [], 2), TestCmd.new(404, [], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [3, "Nothing."], 0), TestCmd.new(0, [], 1), TestCmd.new(404, [], 0), TestCmd.new(0, [], 0)]
  end

  def right_option(list, i)
    PokeAccess::Config.puzzle_assist = true
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 2)
    PokeAccess::Puzzles::Answers.right_option(int, list, i)
  end

  def info_key
    World.next_frame
    PokeAccess::Info.map_text.to_s
  end

  def listed
    World.next_frame
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afi_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afi_kept_t)
    i18n.send(:remove_method, :afi_kept_t)
  end
end

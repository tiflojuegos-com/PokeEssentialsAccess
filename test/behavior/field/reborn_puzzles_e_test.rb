# Pokemon Reborn's puzzles of part E (games/reborn/puzzles/): Deoxys's meteors, Mew's plushies and the Wasteland Wall's
# holes, the Garchomp statues and the buttons of Sugiline, Darkrai's crystal, Eevee's keypad, the Twilight Factory's
# machines, the GUM Room's pipes and the Rhodochrine Tree's obelisk and fights. Without the assist, what the screen
# shows; with it, the way.
class RebornPuzzlesETest < PokeAccessTest
  SWITCHES = [384, 385, 386, 885, 886, 887, 1063, 1064, 2199, 2226, 2227]
  VARS = [382, 387, 388, 389, 390, 636, 650, 660, 661, 662]

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
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Deoxys's meteors are named, counted by their self switches, and drop out once touched until Deoxys is caught" do
    meteors = PokeAccess::RebornDeoxysMeteors
    on_map(884, 29, 50)
    $game_variables[650] = 2
    first = place(8, 15, 57, "EV008")
    place(12, 43, 77, "EV012")
    refute meteors.live?(first), "before Ciel a touch would spend the meteor"
    $game_variables[650] = 3
    assert_equal "{rbe_meteor}", PokeAccess::Puzzles.piece_name(first)
    assert meteors.live?(first)
    $game_self_switches[[884, 8, "A"]] = true
    $game_variables[650] = 4
    refute meteors.live?(first), "a touched meteor gives nothing more in the hunt"
    assert_includes info_key, "{puzzle_progress label={rbe_meteors} n=1 of=4}"
    $game_variables[650] = 8
    assert meteors.live?(first), "with Deoxys caught each meteor changes its form"
    refute_includes info_key, "rbe_meteors"
  end

  test "Mew's disguise is named with the assist alone, and Mew itself always" do
    on_map(874, 22, 20)
    $game_variables[636] = 5
    cubone = place(77, 8, 51, "emw", 0, "pkmn_cubone")
    plain = PokeAccess::Puzzles.piece_name(cubone)
    refute_nil plain, "without a name of the mod's the event's own name would give the hiding place away"
    refute_match(/emw|rbe_mew_disguised/, plain)
    assert_equal false, PokeAccess::World::Mechanics.piece_of(cubone).listed.call(cubone), "listed with the assist alone"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbe_mew_disguised}", PokeAccess::Puzzles.piece_name(cubone)
    PokeAccess::Config.puzzle_assist = false
    assert_equal "{rbe_mew}", PokeAccess::Puzzles.piece_name(place(84, 24, 11, "EV084", 0, "pkmn_mew"))
  end

  test "the Wasteland Wall says each fall, and with the assist tracks the boulders in their order" do
    wall = PokeAccess::RebornMewWastelandWall
    refute PokeAccess::RebornWastelandWall.const_defined?(:HOLES, false), "map 212's module stays apart from 279's"
    assert_equal [[1, [20, 37], 384], [3, [31, 14], 385], [26, [46, 37], 386]], wall::HOLES
    on_map(279, 16, 40)
    place(1, 16, 37, "Boulder", 1, "rockstrength2")
    place(3, 34, 14, "Boulder", 1, "rockstrength2")
    refute wall.waiting?(26, 386), "the last boulder stands only once the second has fallen"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbe_ww_hint}"
    assert_includes frame { $game_switches[384] = true }, "{rbe_ww_fell}"
    $game_switches[385] = true
    assert wall.waiting?(26, 386)
    $game_switches[386] = true
    refute_includes info_key, "rbe_ww_hint"
  end

  test "the Garchomp statues wake with their row, and the waking is said only while one of the row stands" do
    statues = PokeAccess::RebornGarchompStatues
    on_map(660, 14, 45)
    first = place(3, 13, 37, "EV003", 0, "pkmn_garchomp3")
    second = place(22, 11, 29, "EV022", 0, "pkmn_garchomp3")
    assert_equal "{rbe_sr_statue}", PokeAccess::Puzzles.piece_name(first)
    assert_includes frame { $game_variables[382] = 1 }, "{rbe_sr_waking}"
    assert_equal "{rbe_sr_statue_awake}", PokeAccess::Puzzles.piece_name(first)
    assert_equal "{rbe_sr_statue}", PokeAccess::Puzzles.piece_name(second)
    $game_variables[388] = 5
    $game_variables[382] = 2
    assert_nil statues.waking_line, "with the row beaten the game plays no cry"
    assert_equal [1, 2, 3, 4, nil], [3, 26, 30, 36, 11].map { |id| statues.row_of(id) }
  end

  test "Sugiline's buttons are listed until pressed, and the cave is done with both" do
    cave = PokeAccess::RebornSugilineCave
    on_map(654, 20, 33)
    west = place(56, 17, 29, "EV056")
    assert_equal "{rbe_sc_button}", PokeAccess::Puzzles.piece_name(west)
    $game_switches[886] = true
    refute cave.stairs?
    $game_switches[887] = true
    assert cave.stairs?
    on_map(661, 57, 11)
    assert_equal "{rbe_sr_button}", PokeAccess::Puzzles.piece_name(place(40, 57, 10, "EV040"))
  end

  test "the purple crystal on Darkrai's way is one target on both twin maps, and Eevee's keypad gives the box's code" do
    [339, 338].each do |map|
      on_map(map, 12, 19)
      place(1, 12, 17, "EV001")
      assert_equal [[12, 17, "{rbb_iolia_purple}"]], targets_at(12, 17), "map #{map}"
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[12, 17, "{rb1_iolia_purple_hint}"]], targets_at(12, 17), "map #{map}"
      assert PokeAccess::World::Mechanics.instances.any? { |inst| inst.spec[:sent_back] },
             "Iolia Valley's own mechanic is the one live on map #{map}"
    end
    keypad = PokeAccess::RebornEeveeKeypad
    on_map(774, 32, 18)
    assert_equal "{rbe_eevee_keypad}", PokeAccess::Puzzles.piece_name(place(122, 32, 17, "EV122"))
    assert_equal [:puzzle_answer, { :a => "3862" }], keypad.answer
    $game_switches[1064] = true
    assert_equal [:puzzle_answer, { :a => "2368" }], keypad.answer
    $game_switches[1063] = true
    assert_nil keypad.answer
  end

  test "the GUM Room's pipes say how far they are from their tile with the assist, and the skip is told while no password is on" do
    gum = PokeAccess::RebornGumRoom
    assert_equal 29, gum::TARGETS.length
    on_map(606, 30, 10)
    off = place(1, 22, 4, "K- 14, 4", 0, "sewerpipe")
    home = place(2, 22, 12, "E- 22, 12", 0, "sewerpipe")
    first = place(30, 18, 4, "J- 12, 4", 0, "sewerpipe")
    assert_equal "{rbe_gum_pipe}", PokeAccess::Puzzles.piece_name(off)
    assert_nil gum.rule
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbe_gum_pipe_way way=8 {dir_left}}", PokeAccess::Puzzles.piece_name(off)
    assert_equal "{rb1_gum_pipe_next dir={dir_left}}", PokeAccess::Puzzles.piece_name(first), "the plan moves it before"
    assert_equal "{rbe_gum_pipe_placed}", PokeAccess::Puzzles.piece_name(home)
    assert_equal 1, gum.placed
    assert_includes info_key, "{puzzle_progress label={rbe_gum_placed} n=1 of=29}"
    assert_equal :rbe_gum_skip_hint, gum.rule
    $game_switches[2227] = true
    assert_nil gum.rule
    $game_self_switches[[606, 33, "A"]] = true
    refute_includes info_key, "rbe_gum_placed", "the Goomy given, the room is done"
  end

  test "the GUM Room's plan moves every pipe along its line onto its tile, three of them off and back to open the way" do
    gum = PokeAccess::RebornGumRoom
    tiles = gum::STARTS.dup
    gum::PLAN.each do |id, way, n|
      x, y = tiles[id]
      vertical = [2, 8].include?(way)
      assert(vertical ? gum::STARTS[id][0] == gum::TARGETS[id][0] : gum::STARTS[id][1] == gum::TARGETS[id][1],
             "pipe #{id} moves along its own line")
      dx, dy = gum::WAYS[way]
      tiles[id] = [x + dx * n, y + dy * n]
    end
    assert_equal gum::TARGETS, tiles
    assert_equal 94, gum::PLAN.inject(0) { |sum, run| sum + run[2] }
    assert_equal [19, 20, 21], gum::PLAN.map { |run| run[0] }.select { |id| gum::PLAN.count { |r| r[0] == id } == 2 }.uniq.sort
  end

  test "the GUM Room's assist follows the plan use by use, halfway back along a pipe's own line too" do
    gum = PokeAccess::RebornGumRoom
    on_map(606, 15, 20)
    gum_stage(0)
    PokeAccess::Config.puzzle_assist = true
    gum.runs.each_with_index do |(id, way, n), i|
      dx, dy = gum::WAYS[way]
      n.times do |k|
        assert_equal [:step, i, k], gum.next_step, "use #{k + 1} of step #{i + 1} (pipe #{id})"
        ev = $game_map.events[id]
        gum_move(id, ev.x + dx, ev.y + dy)
      end
    end
    assert_nil gum.next_step
    assert_equal :rb1_gum_boot, gum.hint
    gum_stage(6)
    gum_move(21, 33, 16)
    assert_equal [7, 1], [gum.hint[1][:i], gum.hint[1][:n]], "halfway up, the way back goes on up"
    gum_stage(5)
    gum_move(21, 33, 16)
    assert_equal [:rb1_gum_step, 4, 1], [gum.hint[0], gum.hint[1][:i], gum.hint[1][:n]],
                 "with a row still to do, it goes back down first"
  end

  test "the GUM Room's assist gives the plan's next step, the way back for a pipe off it, and the terminal at the end" do
    gum = PokeAccess::RebornGumRoom
    on_map(606, 15, 20)
    gum_stage(0)
    refute_includes info_key, "rb1_gum", "without the assist the room says no plan"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:rb1_gum_step, { :i => 1, :total => 30, :x => 14, :y => 14, :sx => 13, :sy => 14,
                                   :dir => "{dir_right}", :n => 1 }], gum.hint
    assert_includes info_key, "{rb1_gum_step dir={dir_right} i=1 n=1 sx=13 sy=14 total=30 x=14 y=14}"
    assert_equal "{rb1_gum_pipe_next dir={dir_right}}", PokeAccess::Puzzles.piece_name($game_map.events[3])
    assert_includes PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name, tg.key] },
                    [13, 14, "{rb1_gum_stand}", :puzzle_cell]
    gum_stage(1)
    assert_equal [:rb1_gum_step, { :i => 2, :total => 30, :x => 14, :y => 18, :sx => 14, :sy => 19,
                                   :dir => "{dir_up}", :n => 2 }], gum.hint
    gum_move(4, 14, 17)
    assert_equal 1, gum.hint[1][:n], "one use made, one left in the step"
    gum_stage(3)
    assert_equal [:rb1_gum_step, { :i => 4, :total => 30, :x => 33, :y => 15, :sx => 33, :sy => 14,
                                   :dir => "{dir_down}", :n => 2 }], gum.hint, "the pipe on its tile leaves it first"
    gum_stage(6)
    assert_equal 7, gum.hint[1][:i], "with both rows done the pipe goes back up"
    gum_stage(7)
    assert_equal [:rb1_gum_step, { :i => 8, :total => 30, :x => 30, :y => 15, :sx => 30, :sy => 14,
                                   :dir => "{dir_down}", :n => 4 }], gum.hint, "back on its tile it counts as done"
    gum_move(2, 23, 12)
    assert_equal [:rb1_gum_back, { :list => "{rb1_gum_back_item way=1 {dir_left} x=23 y=12}" }], gum.hint
    gum_stage(30)
    assert_equal 29, gum.placed
    assert_equal :rb1_gum_boot, gum.hint
    $game_self_switches[[606, 33, "A"]] = true
    assert_nil gum.hint
  end

  test "the Twilight Desert's wrap is said as such, and no other teleport is taken for it" do
    desert = PokeAccess::RebornTwilightDesert
    assert_equal "{rbe_td_wrapped}", desert.wrap_line([9, 30, 841], [173, 30, 841])
    assert_equal "{rbe_td_wrapped}", desert.wrap_line([175, 60, 841], [11, 60, 841])
    assert_nil desert.wrap_line([9, 30, 841], [173, 31, 841])
    assert_nil desert.wrap_line([9, 30, 846], [173, 30, 846])
    assert_equal "{rbe_td_wrapped}", PokeAccess::Locator.instance_variable_get(:@teleport_causes)
                                                       .assoc(:rbe_desert_wrap)[1].call([9, 30, 841], [173, 30, 841])
  end

  test "the Rhodochrine Tree tells its password with the assist until the obelisk stands or the tree is done" do
    tree = PokeAccess::RebornTreeObelisk
    on_map(886, 18, 20)
    assert_nil tree.rule
    PokeAccess::Config.puzzle_assist = true
    assert_equal :reb_obelisk_hint, tree.rule
    $game_switches[2199] = true
    assert_nil tree.rule
    $game_switches[2199] = false
    $game_variables[660] = 19
    assert_nil tree.rule
    on_map(846, 55, 39)
    assert_equal "{rbe_tf_counter}", PokeAccess::Puzzles.piece_name(place(82, 55, 38, "EV082"))
  end

  test "the Rhodochrine Tree's fights are searched once per sides and foes standing, until the map changes" do
    tree = PokeAccess::RebornTree
    on_map(886, 20, 340)
    foes = (84..93).map { |id| place(id, id - 70, 340, "EV#{id}", 0, "pkmn") }
    $game_variables[661], $game_variables[662] = 20, 31
    searches = 0
    tree.singleton_class.send(:alias_method, :rv2_kept_search, :search)
    tree.define_singleton_method(:search) { |*args| searches += 1; rv2_kept_search(*args) }
    tree.forget
    assert_equal [84, 87, 88, 89, 90, 91, 92, 93], tree.plan
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:rbrd_tree_next, { :name => "Chimecho" }], tree.label(foes[0])
    refute_nil tree.hint
    assert_equal 1, searches
    foes[3].character_name = ""
    $game_variables[662] = 29
    assert_equal [84, 88, 89, 90, 91, 92, 93], tree.plan
    assert_equal 2, searches
    PokeAccess::World::Epoch.touch(:map)
    tree.plan
    assert_equal 3, searches
  ensure
    tree.singleton_class.send(:alias_method, :search, :rv2_kept_search)
    tree.singleton_class.send(:remove_method, :rv2_kept_search)
    tree.forget
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbe_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbe_kept_t)
    i18n.send(:remove_method, :rbe_kept_t)
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
  # Lays the GUM Room's pipes out as the plan leaves them after its first k steps.
  def gum_stage(k)
    gum = PokeAccess::RebornGumRoom
    tiles = gum::STARTS.dup
    gum::PLAN.first(k).each do |id, way, n|
      dx, dy = gum::WAYS[way]
      tiles[id] = [tiles[id][0] + dx * n, tiles[id][1] + dy * n]
    end
    tiles.each { |id, (x, y)| place(id, x, y, "pipe #{id}", 0, "sewerpipe") }
  end

  # Moves one pipe to a tile.
  def gum_move(id, x, y)
    ev = $game_map.events[id]
    ev.x = x
    ev.y = y
    World.next_frame
  end

  # The puzzle targets listed on a tile, with their names.
  def targets_at(x, y)
    PokeAccess::Puzzles.category_targets.select { |tg| tg.x == x && tg.y == y }.map { |tg| [tg.x, tg.y, tg.name] }
  end
end

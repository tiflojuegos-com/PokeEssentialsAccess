# Pokemon Ashen Frost's puzzles of part D (games/ashenfrost/puzzles/): the inscriptions of Morove, the mirror path, the mural
# and the locker's tile puzzles, and the houses of Case Twenty (Maze House, 16 Floor House, Suspiciously Nice Place, Haunted
# Place, Abandoned Pokémon Center and Dugtrio Den).
# Without the assist, what the screen shows; with it, the way.
class AshenFrostPuzzlesDGdTest < PokeAccessTest
  SWITCHES = [71, 288]
  VARS = [257, 260, 262, 345, 346, 347, 348, 349, 351]

  def setup
    super
    keyed
    Harness.load_puzzles("ashenfrost")
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

  test "Morove's inscriptions are listed on their day until read, and the assist says the key, then how many are left" do
    on_map(686, 30, 30)
    $game_variables[257] = 2
    plaque = place(65, 33, 28, "Tablet Size(3,1)")
    assert_equal "{afd_plaque}", PokeAccess::Puzzles.piece_name(plaque)
    assert_includes targets, [33, 28, "{afd_plaque}"]
    refute_includes info_key, "afd_plaques"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_plaques_key temple="
    $game_variables[260] = 1
    assert_includes info_key, "{afd_plaques_left n=5 "
    $game_self_switches[[684, 28, "A"]] = true
    $game_self_switches[[686, 65, "A"]] = true
    $game_variables[260] = 3
    assert_includes info_key, "{afd_plaques_left n=3 "
    assert_equal 2, PokeAccess::AshenPlaques.translated
    refute(targets.any? { |r| r[2] == "{afd_plaque}" }, "a read inscription leaves the list")
    $game_variables[260] = 7
    assert_equal 5, PokeAccess::AshenPlaques.translated
    refute_includes info_key, "afd_plaques"
  end

  test "the mirror path says Cordelia's mirroring without the assist, and a fall from its false floor alone" do
    on_map(686, 56, 31)
    frame
    $game_switches[288] = true
    $game_variables[262] = 5
    assert_includes frame, "{afd_mirror_rule}"
    refute_includes info_key, "afd_mirror_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_mirror_hint}"
    assert_equal "{afd_mirror_fell}", PokeAccess::Puzzles.sent_back_line([57, 33, 686], [55, 12, 686])
    assert_nil PokeAccess::Puzzles.sent_back_line([57, 50, 686], [55, 12, 686]), "the switch sends the player there too"
    assert_nil PokeAccess::Puzzles.sent_back_line([56, 30, 686], [55, 12, 686]), "and so does the way out"
    assert_equal "{afd_mirror_switch}", PokeAccess::Puzzles.piece_name(place(85, 57, 51, "Switch"))
    $game_variables[262] = 6
    refute_includes info_key, "afd_mirror"
  end

  test "the mirror path's false floor is a step the routes refuse with the assist alone, on that map alone" do
    terrain = PokeAccess::World::Terrain.singleton_class
    terrain.send(:alias_method, :afd_kept_number, :number)
    terrain.send(:define_method, :number) { |x, y| x == 57 && y == 31 ? 20 : 0 }
    moves = PokeAccess::Routes::Moves
    on_map(686, 56, 31)
    assert_equal [57, 31], moves.arrive(57, 31, 6), "unseen without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_nil moves.arrive(57, 31, 6)
    assert_equal [56, 32], moves.arrive(56, 32, 2)
    on_map(684, 56, 31)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [57, 31], moves.arrive(57, 31, 6), "the tag means nothing on other maps"
  ensure
    terrain.send(:alias_method, :number, :afd_kept_number)
    terrain.send(:remove_method, :afd_kept_number)
  end

  test "the mural and the locker are named until their tile puzzle is solved" do
    on_map(690, 8, 6)
    mural = place(11, 8, 4, "Tile Puzzle")
    assert_equal "{afd_mural}", PokeAccess::Puzzles.piece_name(mural)
    assert_includes targets, [8, 4, "{afd_mural}"]
    $game_self_switches[[690, 11, "B"]] = true
    refute_includes targets, [8, 4, "{afd_mural}"]
    on_map(698, 13, 40)
    locker = place(51, 13, 38, "Henry's Locker", 0, "HiddenItem_Sparkle")
    assert_equal "{afd_locker}", PokeAccess::Puzzles.piece_name(locker)
    assert_includes targets, [13, 38, "{afd_locker}"]
    $game_self_switches[[698, 51, "A"]] = true
    refute_includes targets, [13, 38, "{afd_locker}"]
  end

  test "the Maze House points to the owner it waits on, then the east door and the entrance, with the assist alone" do
    on_map(771, 61, 7)
    place(33, 25, 10, "Owner 2", 0, "NPC_7")
    place(29, 50, 51, "EV029", 1)
    place(40, 64, 4, "Owner (Final)", 0, "NPC_7")
    $game_variables[345] = 2
    refute_includes info_key, "afd_maze"
    refute(listed.any? { |r| r[2] =~ /afd_maze/ })
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_maze_owner}"
    assert_includes listed, [25, 10, "{afd_maze_owner_spot}"]
    $game_variables[345] = 6
    assert_includes info_key, "{afd_maze_door}"
    assert_includes listed, [50, 51, "{afd_maze_door_spot}"]
    $game_variables[345] = 7
    assert_includes info_key, "{afd_maze_final}"
    assert_includes listed, [64, 4, "{afd_maze_owner_spot}"]
    $game_variables[345] = 8
    refute_includes info_key, "afd_maze"
  end

  test "the 16 Floor House names its stairs as drawn, and the assist tells the floor and the climbs left" do
    on_map(772, 17, 3)
    up = place(4, 14, 3, "EV004", 1)
    down = place(3, 18, 3, "EV003", 1)
    assert_equal "{afd_floors_up}", PokeAccess::Puzzles.piece_name(up)
    assert_equal "{afd_floors_down}", PokeAccess::Puzzles.piece_name(down)
    $game_variables[346] = 5
    refute_includes info_key, "afd_floors"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_floors_climb floor=5 n=11}"
    $game_player.x = 2
    assert_includes info_key, "{afd_floors_start}"
    $game_player.x = 29
    $game_variables[346] = 16
    assert_includes info_key, "{afd_floors_owner}"
    $game_variables[346] = 17
    refute_includes info_key, "afd_floors"
  end

  test "the Suspiciously Nice Place: its boulders take no field move, and the assist walks the finds and the questions" do
    on_map(773, 30, 35)
    list = [TestCmd.new(355, ["$PokemonMap.strengthUsed = true"]), TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])]
    page = TestPage.new(:trigger => 2, :list => list)
    boulder = TestGameEvent.new(:id => 11, :x => 19, :y => 35, :name => "Boulder C", :pages => [page], :active_page => page)
    $game_map.events[11] = boulder
    assert_equal [nil], PokeAccess::Routes::Effects.push_move(boulder)
    nice = PokeAccess::AshenNicePlace
    refute_includes info_key, "afd_nice"
    refute_includes listed, [44, 34, "{afd_nice_truffles_spot}"]
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_nice_left list={afd_nice_item_box}; {afd_nice_item_truffles}}"
    assert_includes listed, [44, 34, "{afd_nice_truffles_spot}"]
    $game_self_switches[[773, 14, "A"]] = true
    $game_variables[347] = 1
    assert_includes info_key, "{afd_nice_left list={afd_nice_item_truffles}}"
    $game_variables[347] = 3
    assert_includes info_key, "{afd_nice_owner}"
    assert_equal({ :self => "A" }, nice.question)
    $game_self_switches[[773, 12, "A"]] = true
    assert_equal({ :self => "B" }, nice.question)
    $game_self_switches[[773, 12, "B"]] = true
    assert_nil nice.question
    $game_variables[347] = 4
    refute_includes info_key, "afd_nice"
  end

  test "the Haunted Place's ghosts are named and counted with the assist alone, and only while smelling" do
    on_map(774, 12, 30)
    ghost = place(24, 1, 30, "Ghost 1", 0, "Ghost_1")
    $game_variables[348] = 3
    refute_includes listed, [12, 30, "{afd_haunted_truffles_spot}"]
    refute_includes info_key, "afd_haunted"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afd_haunted_truffles}"
    assert_includes listed, [12, 30, "{afd_haunted_truffles_spot}"]
    refute_includes targets, [1, 30, "{afd_haunted_ghost}"]
    $game_switches[71] = true
    assert_includes targets, [1, 30, "{afd_haunted_ghost}"]
    assert_includes info_key, "{afd_haunted_ghosts n=3}"
    $game_self_switches[[774, 24, "A"]] = true
    $game_variables[348] = 4
    refute_includes targets, [1, 30, "{afd_haunted_ghost}"]
    assert_includes info_key, "{afd_haunted_ghosts n=2}"
    assert_equal 1, PokeAccess::AshenHauntedHouse.ghosts
    PokeAccess::Config.puzzle_assist = false
    assert_equal "Ghost 1", ghost.name
    refute_includes info_key, "afd_haunted"
    PokeAccess::Config.puzzle_assist = true
    $game_variables[348] = 6
    $game_switches[71] = false
    assert_includes info_key, "{afd_haunted_owner}"
    $game_variables[348] = 7
    refute_includes info_key, "afd_haunted"
  end

  test "Ramira's right option in the Haunted Place is the one that moves the house on" do
    on_map(774, 34, 14)
    int = $game_system.map_interpreter
    kept = int.instance_variable_get(:@event_id)
    options = ["Your thoughts on the place?", "Small talk.", "Check other room?", "Nothing."]
    branches = [[], [], [TestCmd.new(122, [348, 348, 0, 0, 2], 1)], []]
    assert_equal "Check other room?", option(int, 6, options, branches)
  ensure
    int.instance_variable_set(:@event_id, kept) if int
  end

  test "the Suspiciously Nice Place's owner is asked about the place, then about the box" do
    on_map(773, 12, 8)
    $game_variables[347] = 3
    int = $game_system.map_interpreter
    kept = int.instance_variable_get(:@event_id)
    options = ["About this place...", "About the present box...", "Nothing"]
    branches = [[TestCmd.new(123, ["A", 0], 1)], [TestCmd.new(123, ["B", 0], 1)], []]
    assert_equal "About this place...", option(int, 12, options, branches)
    $game_self_switches[[773, 12, "A"]] = true
    assert_equal "About the present box...", option(int, 12, options, branches)
  ensure
    int.instance_variable_set(:@event_id, kept) if int
  end

  test "the Abandoned Pokémon Center counts one stain, the machine and Audino, then sends to the doctor" do
    on_map(775, 9, 16)
    assert_equal "{afd_center_vending}", PokeAccess::Puzzles.piece_name(place(7, 10, 5, "Vending Machine", 1))
    assert_equal "{afd_center_blood}", PokeAccess::Puzzles.piece_name(place(3, 15, 17, "Blood", 0, "Object_Blood"))
    refute_includes info_key, "afd_center"
    PokeAccess::Config.puzzle_assist = true
    all = "{afd_center_left list={afd_center_item_blood}; {afd_center_item_vending}; {afd_center_item_audino}}"
    assert_includes info_key, all
    $game_self_switches[[775, 5, "A"]] = true
    $game_variables[349] = 1
    assert_includes info_key, "{afd_center_left list={afd_center_item_vending}; {afd_center_item_audino}}"
    refute_includes targets, [15, 17, "{afd_center_blood}"]
    $game_variables[349] = 3
    assert_includes info_key, "{afd_center_doctor}"
    $game_variables[349] = 4
    refute_includes info_key, "afd_center"
  end

  test "the Dugtrio Den lists what is left and the hidden tile with the assist alone" do
    on_map(776, 13, 15)
    refute_includes info_key, "afd_den"
    refute_includes listed, [5, 8, "{afd_den_truffles_spot}"]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [5, 8, "{afd_den_truffles_spot}"]
    all = "{afd_den_left list={afd_den_item_left}; {afd_den_item_right}; {afd_den_item_diglett}; {afd_den_item_truffles}}"
    assert_includes info_key, all
    $game_self_switches[[776, 2, "B"]] = true
    $game_self_switches[[776, 10, "A"]] = true
    $game_variables[351] = 2
    assert_includes info_key, "{afd_den_left list={afd_den_item_right}; {afd_den_item_diglett}}"
    refute_includes listed, [5, 8, "{afd_den_truffles_spot}"]
    $game_variables[351] = 4
    refute_includes info_key, "afd_den"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afd_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afd_kept_t)
    i18n.send(:remove_method, :afd_kept_t)
  end

  # The option right_choice picks of a menu on event id, its page made of the options and each one's commands.
  def option(int, id, options, branches)
    list = [TestCmd.new(102, [options, 4], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    page = TestPage.new(:trigger => 0, :sprite => "Character_Ramira", :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => 35, :y => 14, :pages => [page], :active_page => page)
    World.next_frame
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
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

  # Every target the puzzles category lists, as [x, y, name].
  def targets
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end

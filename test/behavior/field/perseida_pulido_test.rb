# Perseida's optional and unconfirmed puzzles on the shipped profile (games/perseida/puzzles): the Mirror Ruins' tasks and
# statues, the braziers of Desidia Castle, the levers of the Tower Ruins and the Regi chambers, each as it is heard without
# the puzzle assist and with it.
class PerseidaPulidoTest < PokeAccessTest
  SWITCHES = [64, 66, 67, 69, 93, 113, 179, 180]
  VARIABLES = [45, 46, 71, 78, 79, 81, 176, 179, 181, 183]

  test "the Mirror Ruins name what the north tasks use and, with the assist alone, tell the next task and the count" do
    on_map(137, 13, 9)
    { 24 => [18, 5, :perseida_mirror_carpet], 27 => [18, 12, :perseida_mirror_mirror], 32 => [6, 4, :perseida_mirror_frame],
      2 => [24, 9, :perseida_mirror_box], 1 => [8, 9, :perseida_mirror_barrel] }.each do |id, (x, y, key)|
      ev = place(id, x, y, [TestCmd.new(101, ["..."])], id == 32 ? "" : "barril")
      assert_equal t(key), PokeAccess::Puzzles.piece_name(ev), "EV#{id}"
    end
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    tasks = t(:puzzle_progress, :label => t(:perseida_mirror_tasks), :n => 0, :of => 4)
    assert_includes info_key, t(:perseida_mirror_carpet_hint)
    assert_includes info_key, tasks
    $game_switches[69] = true
    $game_variables[45] = 1
    assert_includes info_key, t(:perseida_mirror_take_hint)
    $game_switches[64] = true
    assert_includes info_key, t(:perseida_mirror_frame_hint)
    $game_self_switches[[137, 32, "A"]] = true
    $game_variables[45] = 2
    assert_includes info_key, t(:perseida_mirror_box_hint)
    $game_switches[67] = true
    assert_includes info_key, t(:perseida_mirror_barrel_hint)
    $game_variables[45] = 5
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Mirror Ruins' turning statues say their facing as they turn, the fixed ones are named by theirs" do
    on_map(137, 20, 32)
    fixed = place(10, 4, 32, [TestCmd.new(101, ["..."])], "EstatuaDiosa")
    turning = place(16, 22, 32, [TestCmd.new(102, [["Sí", "No"], 1])], "EstatuaDiosa")
    turning.direction = 4
    World.next_frame
    tick
    assert_equal t(:perseida_mirror_fixed, :dir => t(:face_south)), PokeAccess::Puzzles.piece_name(fixed)
    assert_includes listed, [4, 32, t(:perseida_mirror_fixed, :dir => t(:face_south))]
    assert_includes listed, [22, 32, t(:perseida_mirror_statue)]
    refute_includes listed, [4, 32, t(:perseida_mirror_statue)]
    assert_equal ["#{t(:perseida_mirror_statue)}: #{t(:face_east)}"], tick { turning.direction = 6 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["#{t(:perseida_mirror_statue)}: #{t(:face_north)}. #{t(:statue_goal, :dir => t(:face_south))}"],
                 tick { turning.direction = 8 }
    assert_equal ["#{t(:perseida_mirror_statue)}: #{t(:face_south)}. #{t(:statue_ok)}"], tick { turning.direction = 2 }
  end

  test "Desidia's braziers say their fire as it changes and, with the assist alone, the fires the lever wants" do
    on_map(172, 68, 18)
    braziers = { 2 => [68, 14], 5 => [65, 17], 9 => [68, 20], 11 => [71, 17] }
    braziers.each { |id, (x, y)| place(id, x, y, [TestCmd.new(122, [176, 176, 0, 0, 1])], "Antorcha baja2") }
    assert_equal t(:perseida_desidia_brazier, :side => t(:perseida_desidia_north), :fire => t(:perseida_desidia_out)),
                 PokeAccess::Puzzles.piece_name($game_map.events[2])
    assert_equal ["#{t(:perseida_desidia_north)}: #{t(:perseida_desidia_blue)}"], tick { $game_variables[176] = 2 }
    assert_equal ["#{t(:perseida_desidia_east)}: #{t(:perseida_desidia_purple)}"], tick { $game_variables[183] = 3 }
    assert_equal ["#{t(:perseida_desidia_north)}: #{t(:perseida_desidia_out)}"], tick { $game_variables[176] = 0 }
    assert_equal t(:perseida_desidia_brazier, :side => t(:perseida_desidia_east), :fire => t(:perseida_desidia_purple)),
                 PokeAccess::Puzzles.piece_name($game_map.events[11])
    refute_includes info_key, t(:perseida_desidia_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:perseida_desidia_hint)
    $game_player.y = 30
    assert_nil PokeAccess::Puzzles.info_line
    $game_player.y = 18
    assert_equal [t(:perseida_desidia_solved)], tick { $game_switches[93] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Tower Ruins name the levers and the torches as lit or not, and with the assist the count, the way and the gem's crossings" do
    on_map(117, 22, 8)
    lever = place(66, 47, 33, [TestCmd.new(101, ["..."])], "Palanca", "Palanca 1")
    door_lever = place(30, 22, 6, [TestCmd.new(101, ["..."])], "Palanca")
    torch = place(28, 18, 6, [TestCmd.new(0, [])], "Antorcha baja")
    assert_equal t(:perseida_tower_lever), PokeAccess::Puzzles.piece_name(lever)
    assert_equal t(:perseida_tower_door_lever), PokeAccess::Puzzles.piece_name(door_lever)
    assert_equal t(:perseida_tower_torch_out), PokeAccess::Puzzles.piece_name(torch)
    $game_switches[179] = true
    assert_equal t(:perseida_tower_torch_lit), PokeAccess::Puzzles.piece_name(torch)
    assert_nil PokeAccess::Puzzles.info_line
    refute_includes listed, [10, 23, t(:perseida_tower_false_wall)]
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:perseida_tower_hint)
    assert_includes info_key, t(:puzzle_progress, :label => t(:perseida_tower_levers), :n => 1, :of => 2)
    assert_includes listed, [10, 23, t(:perseida_tower_false_wall)]
    assert_includes listed, [22, 11, t(:perseida_tower_gem_off)]
    $game_variables[71] = 11
    assert_nil PokeAccess::Puzzles.info_line
    refute_includes listed, [10, 23, t(:perseida_tower_false_wall)]
    on_map(57, 34, 9)
    $game_variables[71] = 9
    refute_includes listed, [34, 7, t(:perseida_tower_false_wall)]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [34, 7, t(:perseida_tower_false_wall)]
    $game_variables[71] = 11
    refute_includes listed, [34, 7, t(:perseida_tower_false_wall)]
  end

  test "a Regi chamber says each tile that lights up, lists the lit ones and, with the assist, the hidden ones, the count and the hint" do
    on_map(62, 6, 10)
    tiles = { 14 => [4, 5], 22 => [3, 7], 25 => [6, 7] }.map do |id, (x, y)|
      place(id, x, y, [TestCmd.new(250, []), TestCmd.new(122, [79, 79, 1, 0, 1])], "", nil, 2)
    end
    assert_empty listed.select { |row| row[2] == t(:perseida_regi_tile_hidden) }
    assert_includes info_key, t(:perseida_regi_title, :n => 0)
    assert_equal [t(:perseida_regi_step)], tick { $game_variables[79] = 1; $game_self_switches[[62, 14, "A"]] = true }
    assert_includes listed, [4, 5, t(:perseida_regi_tile_lit)]
    assert_includes info_key, t(:perseida_regi_title, :n => 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [3, 7, t(:perseida_regi_tile_hidden)]
    progress = t(:puzzle_progress, :label => t(:perseida_regi_tiles), :n => 1, :of => 7)
    hint = t(:perseida_regi_hint, :species => PokeAccess::Data.species_name(379))
    assert_equal PokeAccess.sentences([progress, hint]), info_key, "the count out of seven stands in for the title"
    tick { $game_variables[79] = 7 }
    assert_nil PokeAccess::Puzzles.info_line
    assert_equal [], tick { $game_variables[79] = 10 }
    assert_equal 3, tiles.length
  end

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def on_map(map, x, y)
    Harness.load_puzzles("perseida")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
    @arrival = tick
  end

  def place(id, x, y, list, sprite = "", name = nil, trigger = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    opts = { :id => id, :x => x, :y => y, :pages => [page], :active_page => page }
    opts[:name] = name if name
    ev = TestGameEvent.new(opts)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text.to_s; end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end

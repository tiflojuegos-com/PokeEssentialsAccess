# Pokemon Uranium's optional and unconfirmed puzzles (games/uranium/puzzles): the boulders of Zeta, Victory Road's holes
# and bridges, Lanthanite Cave, the Labyrinth, Larkspur's cell, Ripley's sentinels, the dream paths and the memory game.
class UraniumOptPuzzlesTest < PokeAccessTest
  SWITCHES = [120, 139, 248, 249, 250]
  VARIABLES = [30, 31, 35, 117, 126]

  test "Zeta's west boulders say their rule once, and the assist alone gives the push until the Arbokite is taken" do
    lines = arrival(192)
    assert_includes lines, t(:ura_po_zeta_west_rule)
    refute_includes info_key, t(:ura_po_zeta_west_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_po_zeta_west_hint)
    $game_self_switches[[192, 13, "A"]] = true
    refute_includes info_key, t(:ura_po_zeta_west_hint)
  end

  test "Zeta's yard says its rule and, with the assist alone, the pushes it needs until the way to the north door is open" do
    with_yard_wall do
      lines = arrival(190) { place(4, 24, 30, [TestCmd.new(101, ["boulder"])], "boulder") }
      assert_includes lines, t(:ura_po_zeta_patio_rule)
      refute_includes info_key, patio_hint
      PokeAccess::Config.puzzle_assist = true
      assert_includes info_key, patio_hint
      place(4, 40, 31, [TestCmd.new(101, ["boulder"])], "boulder")
      frame
      refute_includes info_key, patio_hint
    end
  end

  test "Zeta's yard hint lists the pushes of a sequence that moves the boulders from where they stand and opens the way" do
    PokeAccess::Config.puzzle_assist = true
    squares = [[25, 17], [23, 22], [24, 22], [25, 22], [23, 20], [25, 20], [24, 19], [24, 18], [26, 19], [25, 18], [22, 19]]
    PokeAccess::UraniumZetaPatio.pushes.each do |x, y, dir, times|
      times.times do |n|
        from = [x + n * (dir == 6 ? 1 : (dir == 4 ? -1 : 0)), y + n * (dir == 2 ? 1 : (dir == 8 ? -1 : 0))]
        assert_includes squares, from
        squares.delete(from)
        dest = [from[0] + (dir == 6 ? 1 : (dir == 4 ? -1 : 0)), from[1] + (dir == 2 ? 1 : (dir == 8 ? -1 : 0))]
        refute_includes squares, dest
        squares << dest
      end
    end
    key, vars = PokeAccess::UraniumZetaPatio.hint
    assert_equal :ura_po_zeta_patio_hint, key
    assert_equal 7, vars[:list].split("; ").length
  end

  test "Victory Road names its open holes, counts each bridge and gives the hint of the bridge still missing with the assist" do
    lines = arrival(184)
    assert_includes lines, t(:ura_po_vr_rule)
    (34..39).each { |id| place(id, 20 + id, 50, [TestCmd.new(101, ["hole"])]) }
    frame
    assert_equal t(:ura_po_vr_hole), PokeAccess::Puzzles.piece_name($game_map.events[34])
    assert_equal [t(:puzzle_progress, :label => t(:ura_po_vr_west), :n => 1, :of => 2)],
                 frame { $game_self_switches[[184, 34, "A"]] = true }
    refute_equal t(:ura_po_vr_hole), PokeAccess::Puzzles.piece_name($game_map.events[34])
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_po_vr_hint_west)
    $game_self_switches[[184, 35, "A"]] = true
    frame
    assert_includes info_key, t(:ura_po_vr_hint_center)
    refute_includes info_key, t(:ura_po_vr_hint_west)
    [38, 39].each { |id| $game_self_switches[[184, id, "A"]] = true }
    frame
    assert_includes info_key, t(:ura_po_vr_hint_northeast)
    [36, 37].each { |id| $game_self_switches[[184, id, "A"]] = true }
    frame
    refute_includes info_key, t(:ura_po_vr_hint_northeast)
  end

  test "Lanthanite Cave names its eight fixed ice blocks and says its rule once" do
    assert_includes arrival(106), t(:ura_po_lanthanite_rule)
    (9..16).each { |id| tile(id, 70 + id, 40, 2457) }
    frame
    (9..16).each { |id| assert_equal t(:ura_po_ice_block), PokeAccess::Puzzles.piece_name($game_map.events[id]) }
  end

  test "The Labyrinth says its rule and why each of its four passages lands the player elsewhere in the cave" do
    assert_includes arrival(80), t(:ura_po_lab_rule)
    { 2 => [22, 88], 6 => [54, 9], 3 => [23, 8], 4 => [5, 25] }.each do |id, to|
      ev = place(id, 5, 5, [TestCmd.new(101, ["passage"])])
      fire(ev)
      assert_equal t(:ura_po_lab_warp), PokeAccess::Puzzles.sent_back_line([5, 5, 80], to)
    end
    assert_nil PokeAccess::Puzzles.sent_back_line([5, 5, 80], [1, 1])
    refute_includes info_key.to_s, t(:ura_po_lab_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_po_lab_hint)
  end

  test "Larkspur's cell names its pieces while captive and gives the next step of the escape with the assist alone" do
    lines = arrival(75) { $game_variables[117] = 2 }
    assert_includes lines, t(:ura_po_cell_rule)
    [[11, :ura_po_cell_bed], [12, :ura_po_cell_wall], [20, :ura_po_cell_console], [30, :ura_po_cell_stuff]].each do |id, key|
      place(id, id, 20, [TestCmd.new(101, ["x"])])
      frame
      assert_equal t(key), PokeAccess::Puzzles.piece_name($game_map.events[id])
    end
    refute_includes info_key, t(:ura_po_cell_hint_bed)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_po_cell_hint_bed)
    $game_switches[120] = true
    frame
    assert_includes info_key, t(:ura_po_cell_hint_wall)
    $game_self_switches[[75, 12, "A"]] = true
    frame
    assert_includes info_key, t(:ura_po_cell_hint_console)
    $game_self_switches[[75, 20, "A"]] = true
    frame
    assert_includes info_key, t(:ura_po_cell_hint_stuff)
    $game_variables[117] = 3
    frame
    refute_includes info_key, t(:ura_po_cell_hint_stuff)
  end

  test "The cell says no rule once free of it" do
    refute_includes arrival(75) { $game_variables[117] = 0 }, t(:ura_po_cell_rule)
  end

  test "Ripley's sentinels say their reach and why they send the player back to the start" do
    assert_includes arrival(163), t(:ura_po_s51_rule)
    [[1, 18, 7], [2, 17, 18]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["spotted"])], "PU-s51") }
    frame
    assert_equal t(:ura_po_s51_3), PokeAccess::Puzzles.piece_name($game_map.events[1])
    assert_equal t(:ura_po_s51_4), PokeAccess::Puzzles.piece_name($game_map.events[2])
    fire($game_map.events[1])
    assert_equal t(:ura_po_s51_sent), PokeAccess::Puzzles.sent_back_line([18, 8, 163], [9, 11])
    place(5, 18, 31, [TestCmd.new(101, ["spotted"])], "PU-s51")
    fire($game_map.events[5])
    assert_equal t(:ura_po_s51_sent_here), PokeAccess::Puzzles.sent_back_line([18, 30, 163], [18, 31])
  end

  test "Ripley's sentinels add their patrol box with the assist alone and the hint says there is no way free of sight" do
    arrival(163)
    place(2, 17, 18, [TestCmd.new(101, ["spotted"])], "PU-s51")
    frame
    refute_includes PokeAccess::Puzzles.piece_name($game_map.events[2]), t(:ura_po_s51_patrol, :x0 => 17, :y0 => 16, :x1 => 22, :y1 => 21)
    refute_includes info_key, t(:ura_po_s51_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.piece_name($game_map.events[2]), t(:ura_po_s51_patrol, :x0 => 17, :y0 => 16, :x1 => 22, :y1 => 21)
    assert_includes info_key, t(:ura_po_s51_hint)
    place(5, 22, 19, [TestCmd.new(101, ["spotted"])], "PU-s51")
    frame
    assert_equal t(:ura_po_s51_4), PokeAccess::Puzzles.piece_name($game_map.events[5]),
                 "set at (22, 19) after seeing the player, sentinel 5 no longer walks the box it started in"
  end

  test "Dream Route 13 counts its three points and, with the assist alone, lists the one still missing" do
    assert_includes arrival(111), t(:ura_po_dream_rule)
    place(7, 25, 11, [TestCmd.new(0, [])])
    frame
    assert_equal [], listed.select { |r| r[2] == t(:ura_po_dream_tracker) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[25, 11, t(:ura_po_dream_tracker)]], listed.select { |r| r[2] == t(:ura_po_dream_tracker) }
    assert_equal [t(:puzzle_progress, :label => t(:ura_po_dream_trackers), :n => 1, :of => 3)],
                 frame { $game_switches[250] = true }
    assert_empty listed.select { |r| r[2] == t(:ura_po_dream_tracker) }
  end

  test "Abyssal Venesi says its rule and, with the assist alone, the spot of the good branch of the stage" do
    assert_includes arrival(71), t(:ura_po_abyss_rule)
    [[27, 18, 72], [24, 12, 73], [25, 23, 70], [28, 25, 75]].each { |id, x, y| place(id, x, y, [TestCmd.new(0, [])]) }
    $game_player.x = 18
    $game_player.y = 73
    $game_variables[30] = 0
    $game_variables[35] = 1
    frame
    refute_includes info_key, t(:ura_po_abyss_hint, :x => 23, :y => 70)
    assert_empty listed.select { |r| r[2] == t(:ura_po_abyss_way) }
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_includes info_key, t(:ura_po_abyss_hint, :x => 23, :y => 70)
    assert_equal [[23, 70, t(:ura_po_abyss_way)]], listed.select { |r| r[2] == t(:ura_po_abyss_way) }
    $game_variables[35] = 4
    frame
    assert_includes info_key, t(:ura_po_abyss_touch)
    $game_variables[30] = 17
    frame
    refute_includes info_key, t(:ura_po_abyss_touch)
  end

  test "Dream Mountain gives, with the assist alone, the next step of the sleeping girl's mission" do
    assert_includes arrival(84) { $game_variables[30] = 16 }, t(:ura_po_dm_rule)
    refute_includes info_key, t(:ura_po_dm_hint_slime)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_po_dm_hint_slime)
    { 17 => :ura_po_dm_hint_bridge, 18 => :ura_po_dm_hint_figure }.each do |step, key|
      $game_variables[30] = step
      frame
      assert_includes info_key, t(key)
    end
    $game_variables[30] = 19
    $game_variables[35] = 2
    frame
    assert_includes info_key, t(:ura_po_dm_hint_cave, :n => 3)
    $game_variables[30] = 20
    place(49, 42, 36, [TestCmd.new(101, ["teeth"])], "teeth")
    place(50, 49, 30, [TestCmd.new(101, ["teeth"])], "teeth")
    frame
    assert_includes info_key, t(:ura_po_dm_hint_teeth_near)
    $game_self_switches[[84, 49, "A"]] = true
    frame
    assert_includes info_key, t(:ura_po_dm_hint_teeth_far)
    place(50, 45, 33, [TestCmd.new(101, ["teeth"])], "teeth")
    frame
    assert_includes info_key, t(:ura_po_dm_hint_teeth_any)
    $game_self_switches[[84, 51, "A"]] = true
    frame
    assert_includes info_key, t(:ura_po_dm_hint_mimic)
    $game_self_switches[[84, 58, "C"]] = true
    frame
    refute_includes info_key, t(:ura_po_dm_hint_mimic)
  end

  test "Dream Mountain names its toothed boulders and its three caves from left to right" do
    arrival(84)
    [49, 97].each { |id| place(id, 20 + id, 30, [TestCmd.new(101, ["teeth"])], "teeth") }
    [42, 43, 44].each { |id| place(id, 20 + id, 40, [TestCmd.new(101, ["cave"])], "Cave") }
    frame
    assert_equal t(:ura_po_dm_teeth), PokeAccess::Puzzles.piece_name($game_map.events[49])
    assert_equal [:ura_po_dm_cave_1, :ura_po_dm_cave_2, :ura_po_dm_cave_3].map { |k| t(k) },
                 [42, 43, 44].map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
  end

  test "Route 16 says that its floor slides" do
    assert_includes arrival(132), t(:ura_po_r16_rule)
  end

  test "Mt. Tamaranch names its three passages and, with the assist alone, gives the next one by the variable" do
    assert_includes arrival(217), t(:ura_po_tam_rule)
    { 2 => :ura_po_tam_west, 3 => :ura_po_tam_east, 4 => :ura_po_tam_north }.each do |id, key|
      place(id, 5 + id, 13, [TestCmd.new(101, ["x"])])
      assert_equal t(key), PokeAccess::Puzzles.piece_name($game_map.events[id])
    end
    refute_includes info_key, t(:ura_po_tam_hint_west)
    PokeAccess::Config.puzzle_assist = true
    { 0 => :ura_po_tam_hint_west, 2 => :ura_po_tam_hint_west, 3 => :ura_po_tam_hint_north, 4 => :ura_po_tam_hint_east,
      5 => :ura_po_tam_hint_east, 6 => :ura_po_tam_hint_north, 7 => :ura_po_tam_hint_west,
      8 => :ura_po_tam_hint_exit }.each do |value, key|
      $game_variables[31] = value
      frame
      assert_includes info_key, t(key)
    end
  end

  test "The memory game numbers its tiles left to right and, with the assist alone, lists the next tile of the sequence" do
    assert_includes arrival(62), t(:ura_po_simon_rule)
    [3, 4, 5, 6].each { |id| place(id, 5 + 2 * id, 39, [TestCmd.new(101, ["tile"])], "Blue") }
    place(8, 10, 42, [TestCmd.new(101, ["button"])])
    frame
    assert_equal t(:ura_po_simon_tile, :n => 2), PokeAccess::Puzzles.piece_name($game_map.events[4])
    assert_equal t(:ura_po_simon_button), PokeAccess::Puzzles.piece_name($game_map.events[8])
    assert_equal [t(:puzzle_progress, :label => t(:ura_po_simon_rounds), :n => 1, :of => 4)],
                 frame { $game_variables[129] = 1 }
    frame { $game_variables[129] = 4 }
    assert_equal [], frame { $game_variables[129] = 5 }, "the free game past the fourth round counts on, the mod does not"
    refute_includes info_key.to_s, t(:puzzle_progress, :label => t(:ura_po_simon_rounds), :n => 5, :of => 4)
    $game_variables[129] = 1
    frame
    game = Object.new
    game.instance_variable_set(:@simonRunning, true)
    game.instance_variable_set(:@simonAnswer, [2, 0, 3])
    game.instance_variable_set(:@simonPlayer, [])
    $Simon = game
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[15, 39, t(:ura_po_simon_next)]], listed.select { |r| r[2] == t(:ura_po_simon_next) }
    game.instance_variable_set(:@simonPlayer, [2])
    assert_equal [[11, 39, t(:ura_po_simon_next)]], listed.select { |r| r[2] == t(:ura_po_simon_next) }
    game.instance_variable_set(:@simonRunning, false)
    assert_empty listed.select { |r| r[2] == t(:ura_po_simon_next) }
    $Simon = nil
  end

  private

  def with_yard_wall
    class << $game_map
      def passable?(x, y, dir)
        nx = x + (dir == 6 ? 1 : (dir == 4 ? -1 : 0))
        ny = y + (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
        !(ny == 30 && nx != 24)
      end
    end
    yield
  ensure
    class << $game_map
      remove_method :passable?
    end
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The yard's hint as the profile builds it, with the pushes.
  def patio_hint
    key, vars = PokeAccess::UraniumZetaPatio.hint
    t(key, vars)
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def on_map(map)
    Harness.load_puzzles("uranium")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def tile(id, x, y, tile_id)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => tile_id, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end

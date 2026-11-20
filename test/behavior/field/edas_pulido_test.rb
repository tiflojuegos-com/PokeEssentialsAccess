# Edas' optional puzzles on the shipped profile: the Tower of Oblivion's floors, the Catacumbión club, the torches of
# Catabrumas, the rocks of Monte Azur, the rooms of the Fragments of the Heart and the mazes of Carcitoma, each as it is
# heard without the puzzle assist and with it.
class EdasPulidoTest < PokeAccessTest
  SWITCHES = [85, 160, 163, 164, 165, 177, 187, 243, 246, 247, 251, 252, 253, 254]
  VARIABLES = [43, 49, 72, 77, 83, 84, 85]

  def setup
    super
    @scene_was = $scene
  end

  def teardown
    $scene = @scene_was
    Object.send(:remove_const, :LensOfTruth) if Object.const_defined?(:LensOfTruth)
    super
  end

  test "floor 0 names its tiles from the west, keeps their count to the assist and lists the next tile with the assist" do
    on_map(133) do
      { 14 => 24, 6 => 28, 4 => 35, 7 => 39 }.each do |id, x|
        place(id, x, 9, transfer(133, 32, 13), :trigger => 1, :sprite => "", :name => "#EOT HIDE/noShadow")
      end
      place(9, 32, 9, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])], :name => "Cristal")
      place(1, 31, 4, [TestCmd.new(0, [])], :sprite => "Antorcha pared", :name => "#EOT SHOW/noShadow")
    end
    assert_equal [t(:edas_tower_p0_rule)], @arrival
    assert_equal t(:edas_tower_tile, :n => 2), name_of(6)
    assert_equal [], tick { $game_variables[77] = 1 }
    assert_equal [], tick { $game_variables[77] = 0 }
    assert_empty right_ways
    fire($game_map.events[6])
    assert_equal t(:edas_tower_center), PokeAccess::Puzzles.sent_back_line([28, 9, 133], [32, 13, 133])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[28, 9]], right_ways
    assert_equal [progress(:edas_tower_steps, 1, 4), t(:edas_next, :what => t(:edas_tower_tile, :n => 4))],
                 tick { $game_variables[77] = 1 }
    assert_equal [PokeAccess.sentences([t(:puzzle_reset), progress(:edas_tower_steps, 0, 4)]),
                  t(:edas_next, :what => t(:edas_tower_tile, :n => 2))], tick { $game_variables[77] = 0 }
    $game_variables[77] = 10
    assert_equal [[32, 9]], right_ways
  end

  test "floor 0 names a wall torch lit or out only while the Eye of Truth shows it" do
    on_map(133) { place(1, 31, 4, [TestCmd.new(0, [])], :sprite => "Antorcha pared", :name => "#EOT SHOW/noShadow") }
    player_at(31, 6)
    refute_includes [t(:edas_cata_torch_out), t(:edas_cata_torch_lit)], name_of(1)
    assert_empty listed
    eye_up
    assert_equal [[31, 4, t(:edas_cata_torch_out)]], listed
    $game_variables[77] = 1
    assert_equal t(:edas_cata_torch_lit), name_of(1)
    player_at(32, 13)
    refute_equal t(:edas_cata_torch_lit), name_of(1)
    assert_empty listed
  end

  test "floor 1 names its crystals by corner and light while the eye shows them, and says why a loose tile sent the player back" do
    on_map(134) do
      { 23 => [5, 44], 63 => [11, 44], 24 => [5, 40], 62 => [11, 40] }.each do |id, (x, y)|
        place(id, x, y, [TestCmd.new(0, [])], :sprite => "Cristal Oscuro", :name => "EOT SHOW/noShadow")
      end
      place(44, 5, 19, transfer(134, 8, 22), :trigger => 1, :name => "#EOT HIDE")
    end
    $game_variables[77] = 10
    player_at(7, 43)
    refute_equal t(:edas_tower_crystal_dark, :dir => t(:dir_so)), name_of(23)
    assert_empty listed
    eye_up
    assert_equal t(:edas_tower_crystal_dark, :dir => t(:dir_so)), name_of(23)
    $game_variables[77] = 11
    assert_equal t(:edas_tower_crystal_lit, :dir => t(:dir_so)), name_of(23)
    refute_equal t(:edas_tower_crystal_dark, :dir => t(:dir_se)), name_of(63)
    assert_equal [[5, 44, t(:edas_tower_crystal_lit, :dir => t(:dir_so))]], listed
    fire($game_map.events[44])
    assert_equal t(:edas_tower_trap_back), PokeAccess::Puzzles.sent_back_line([5, 18, 134], [8, 22, 134])
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([t(:edas_tower_trap_back), t(:edas_tower_trap_hint)]),
                 PokeAccess::Puzzles.sent_back_line([5, 18, 134], [8, 22, 134])
  end

  test "floor 1 keeps the routes off its loose tiles with the assist alone" do
    on_map(134) { place(44, 5, 19, transfer(134, 8, 22), :trigger => 1, :name => "#EOT HIDE") }
    trap = PokeAccess::Routes.pkey(5, 19)
    without = PokeAccess::Routes::Controls.keep_off[trap]
    PokeAccess::Config.puzzle_assist = true
    assert_equal [nil, true], [without, PokeAccess::Routes::Controls.keep_off[trap]]
  end

  test "floor 2 names its wall pictures to the eye, tells a fight out of order by the bounce and names the next ghost with the assist" do
    on_map(135) { place(1, 27, 3, [TestCmd.new(0, [])], :sprite => "579", :name => "#EOT SHOW") }
    assert_equal [t(:edas_tower_p2_rule)], @arrival
    player_at(28, 5)
    refute_equal picture(579), name_of(1)
    eye_up
    assert_equal picture(579), name_of(1)
    assert_equal [[27, 3, picture(579)]], listed
    assert_equal t(:edas_tower_ghosts_back), PokeAccess::Puzzles.sent_back_line([8, 22, 134], [30, 57, 135], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([8, 44, 134], [30, 57, 135], :map)
    assert_equal [progress(:edas_tower_ghosts, 1, 4)], tick { $game_variables[77] = 21 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:edas_tower_ghosts, 2, 4), t(:edas_next, :what => PokeAccess::Data.species_name(414).to_s)],
                 tick { $game_variables[77] = 22 }
    on_map(135)
    assert_equal [], @arrival
  end

  test "floor 7 counts its steps and names the next way with the assist" do
    on_map(90, true) do
      { 6 => [9, 4], 8 => [1, 9], 9 => [17, 9], 10 => [9, 14] }.each do |id, (x, y)|
        place(id, x, y, transfer(90, 9, 10), :trigger => 1)
      end
    end
    assert_equal t(:edas_tower_way, :dir => t(:dir_o)), name_of(8)
    assert_equal [progress(:edas_tower_steps, 1, 4), t(:edas_next, :what => t(:edas_tower_way, :dir => t(:dir_o)))],
                 tick { $game_variables[85] = 1 }
    assert_includes info_key, progress(:edas_tower_steps, 1, 4)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [], tick { $game_variables[85] = 2 }
  end

  test "floor 4 names the ghost Meowth only while the Eye of Truth shows it, and counts and points at them with the assist" do
    on_map(137) { place(109, 24, 32, [TestCmd.new(0, [])], :sprite => "052", :name => "#EOTSHOW") }
    assert_equal [t(:edas_tower_trail_rule)], @arrival
    player_at(25, 34)
    assert_empty listed
    refute_equal t(:edas_tower_meowth), name_of(109)
    eye_up
    assert_equal [[24, 32, t(:edas_tower_meowth)]], listed
    assert_equal t(:edas_tower_meowth), name_of(109)
    player_at(25, 40)
    assert_empty listed
    refute_equal t(:edas_tower_meowth), name_of(109)
    assert_equal [], tick { $game_variables[83] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:edas_tower_meowth_found, 2, 4), t(:edas_tower_meowth_hint)], tick { $game_variables[83] = 2 }
    assert_equal [progress(:edas_tower_meowth_found, 4, 4), t(:edas_next, :what => t(:edas_tower_up))],
                 tick { $game_variables[83] = 10 }
  end

  test "floors 3 and 6 say how their keeper wakes with the assist alone, and nothing once it has shown" do
    on_map(136)
    assert_equal [], @arrival
    on_map(139, true)
    assert_equal [t(:edas_tower_keeper_hint)], @arrival
    on_map(136, true) { $game_switches[243] = true }
    assert_equal [], @arrival
  end

  test "floor 8 names its paintings, counts them on coming back from one and points at Choi's with the assist" do
    on_map(92) do
      [[7, 20, 24], [13, 8, 24], [44, 10, 34], [55, 18, 34], [57, 14, 4]].each do |id, x, y|
        place(id, x, y, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
      end
    end
    assert_equal [t(:edas_tower_p8_rule)], @arrival
    assert_equal t(:edas_tower_painting_vivinne), name_of(7)
    $game_switches[252] = true
    assert_equal progress(:edas_tower_paintings, 1, 4),
                 PokeAccess::Puzzles.sent_back_line([31, 13, 146], [10, 35, 92], :map)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:edas_tower_missing, :list => PokeAccess::Routes::Text.and_list(
      [t(:edas_tower_painting_vivinne), t(:edas_tower_painting_lobrego), t(:edas_tower_painting_nihkil)]), :n => 3)
    [251, 253, 254].each { |s| $game_switches[s] = true }
    assert_equal [[14, 4]], right_ways
    assert_includes info_key, t(:edas_next, :what => t(:edas_tower_painting_choi))
    on_map(92)
    assert_equal [], @arrival, "the rule is said on the first arrival alone"
  end

  test "the club names its notes while it holds the player, and shows the rug with the key with the assist" do
    on_map(46) do
      $game_switches[177] = true
      [[16, 7, 12], [11, 22, 17], [12, 2, 19]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["..."])]) }
    end
    assert_equal [t(:edas_club_rule)], @arrival
    assert_equal [[2, 19, t(:edas_club_note)], [7, 12, t(:edas_club_note)], [22, 17, t(:edas_club_note)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [13, 14, t(:edas_club_rug)]
    $game_switches[187] = true
    assert_empty listed
  end

  test "Catabrumas names its torches lit or out, and counts them and names the next corner with the assist" do
    on_map(128) do
      [[7, 47, 39], [6, 50, 7], [5, 14, 19], [8, 9, 48]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["..."])]) }
    end
    assert_equal [t(:edas_cata_rule)], @arrival
    assert_equal t(:edas_cata_torch_out), name_of(7)
    assert_equal [], tick { $game_variables[72] = 1 }
    assert_equal t(:edas_cata_torch_lit), name_of(7)
    PokeAccess::Config.puzzle_assist = true
    nxt = t(:edas_next, :what => t(:edas_cata_torch_at, :dir => t(:dir_no)))
    assert_equal [progress(:edas_cata_lit, 2, 4), nxt], tick { $game_variables[72] = 2 }
    assert_equal [[14, 19]], right_ways
  end

  test "Monte Azur names its rocks round the middle and keeps the order and its count to the assist" do
    on_map(81) do
      [[8, 30, 12], [7, 32, 14], [5, 28, 14], [6, 32, 12], [10, 28, 16]].each do |id, x, y|
        place(id, x, y, [TestCmd.new(101, ["..."])])
      end
    end
    assert_equal t(:edas_rock, :dir => t(:dir_ne)), name_of(6)
    assert_equal [], tick { $game_variables[43] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:edas_rock_steps, 2, 4), t(:edas_next, :what => t(:edas_rock, :dir => t(:dir_o)))],
                 tick { $game_variables[43] = 2 }
    assert_equal [PokeAccess.sentences([t(:edas_rock_reset), progress(:edas_rock_steps, 0, 4)]),
                  t(:edas_next, :what => t(:edas_rock, :dir => t(:dir_n)))], tick { $game_variables[43] = 0 }
    $game_switches[85] = true
    assert_empty listed
  end

  test "the sphinxes say their word with the assist, and the room of omnipresence says a portal back" do
    on_map(48) { place(1, 5, 16, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])], :sprite => "Esfinge") }
    assert_equal [], tick { fire($game_map.events[1]) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "Shean")], tick { fire($game_map.events[1]) }
    on_map(39) do
      $game_player.x = 19
      $game_player.y = 33
      place(13, 22, 34, transfer(39, 20, 33), :trigger => 1, :sprite => "portal suelo")
      place(12, 17, 34, transfer(39, 4, 25), :trigger => 1, :sprite => "portal suelo")
    end
    fire($game_map.events[13])
    assert_equal t(:edas_omni_back), PokeAccess::Puzzles.sent_back_line([22, 34, 39], [20, 33, 39])
    assert_empty right_ways
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[17, 34]], right_ways
  end

  test "the sea of the lost names its edges by side and lists the one that leads on with the assist" do
    on_map(99) do
      (8..11).each_with_index { |x, i| place(4 + i, x, 19, transfer(102, 9, 9), :trigger => 1) }
      (8..11).each_with_index { |y, i| place(8 + i, 0, y, transfer(100, 9, 9), :trigger => 1) }
    end
    assert_equal t(:edas_maze_exit, :dir => t(:dir_s)), name_of(5)
    assert_equal t(:edas_maze_exit, :dir => t(:dir_o)), name_of(9)
    assert_empty right_ways
    on_map(99, true) { (8..11).each_with_index { |x, i| place(4 + i, x, 19, transfer(102, 9, 9), :trigger => 1) } }
    assert_equal [t(:edas_maze_hint, :dir => t(:dir_s))], @arrival
    assert_equal [[8, 19], [9, 19], [10, 19], [11, 19]], right_ways
  end

  test "the forest of the absurd names each exit by its side and the path painted there, and lists the way on with the assist" do
    on_map(113) do
      (8..11).each_with_index { |x, i| place(11 + i, x, 0, transfer(119, 9, 13), :trigger => 1) }
      (5..7).each_with_index { |y, i| place(15 + i, 0, y, transfer(118, 18, 5), :trigger => 1) }
      (5..7).each_with_index { |y, i| place(8 + i, 19, y, transfer(117, 1, 5), :trigger => 1) }
    end
    assert_equal t(:edas_forest_exit_stone, :dir => t(:dir_n)), name_of(11)
    assert_equal t(:edas_forest_exit_dirt, :dir => t(:dir_o)), name_of(15)
    assert_equal t(:edas_forest_exit_stone, :dir => t(:dir_e)), name_of(8)
    assert_empty right_ways
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[19, 5], [19, 6], [19, 7]], right_ways
    on_map(121) { place(2, 8, 19, transfer(120, 9, 1), :trigger => 1) }
    assert_equal t(:edas_forest_exit_dirt, :dir => t(:dir_s)), name_of(2)
  end

  test "the corridor of the hasty names what can be searched and walks the assist through buttons and pass" do
    on_map(108) do
      [[23, 6, 1], [8, 15, 3], [18, 7, 3], [11, 14, 12], [12, 13, 12]].each do |id, x, y|
        place(id, x, y, [TestCmd.new(101, ["..."])])
      end
      place(7, 9, 1, transfer(108, 9, 12), :trigger => 2)
    end
    assert_equal [t(:edas_corr_rule)], @arrival
    assert_equal t(:edas_corr_crack), name_of(8)
    fire($game_map.events[7])
    assert_equal t(:edas_corr_back), PokeAccess::Puzzles.sent_back_line([9, 2, 108], [9, 12, 108])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[6, 1]], right_ways
    assert_equal [t(:edas_corr_hint_pass)], tick { $game_variables[49] = 1 }
    assert_equal [[9, 1]], right_ways
    assert_equal [t(:edas_next, :what => t(:edas_corr_crack))], tick { $game_switches[163] = true }
    assert_equal [[15, 3]], right_ways
    $game_variables[49] = 3
    $game_switches[165] = true
    assert_equal [[13, 12], [14, 12]], right_ways
  end

  test "a type sphinx says the type its page checks with the assist alone, and nothing once given" do
    check = [TestCmd.new(101, ["..."]), TestCmd.new(111, [12, "pbHasMoveType(7)"]), TestCmd.new(0, [])]
    on_map(35) { place(17, 9, 41, check, :sprite => "Esfinge", :name => "#EOTSHOW") }
    assert_equal [], tick { fire($game_map.events[17]) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:edas_sphinx_type, :type => PokeAccess::Data.type_name(7))], tick { fire($game_map.events[17]) }
    on_map(35, true) { place(17, 9, 41, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])], :sprite => "Esfinge") }
    assert_equal [], tick { fire($game_map.events[17]) }
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def progress(label, n, of)
    t(:puzzle_progress, :label => t(label), :n => n, :of => of)
  end

  def declare
    was = $VERBOSE
    $VERBOSE = nil
    Harness.load_puzzles("edas")
  ensure
    $VERBOSE = was
  end

  def on_map(map, assist = false)
    declare
    PokeAccess::Config.puzzle_assist = assist
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles::Auto.forget
    $game_map.map_id = map
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  def transfer(map, x, y)
    [TestCmd.new(201, [0, map, x, y, 8, 1]), TestCmd.new(0, [])]
  end

  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def player_at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # Edas' Eye of Truth raised, as its copy keeps it (0192): LensOfTruth with its range and the flag on Scene_Map.
  def eye_up
    unless Object.const_defined?(:LensOfTruth)
      lens = Module.new
      lens.const_set(:RANGE, 3)
      Object.const_set(:LensOfTruth, lens)
    end
    scene = Scene_Map.new
    scene.define_singleton_method(:eye_of_truth) { true }
    $scene = scene
  end

  def picture(species)
    t(:edas_tower_picture, :name => PokeAccess::Data.species_name(species).to_s)
  end

  def name_of(id)
    PokeAccess::Locator.target_name($game_map.events[id])
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _name| [x, y] }
  end

  def right_ways
    listed.select { |_x, _y, name| name == t(:puzzle_right_way) }.map { |x, y, _name| [x, y] }
  end
end

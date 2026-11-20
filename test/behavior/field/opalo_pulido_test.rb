# Opalo's optional and once unconfirmed puzzles on the shipped profile: the sewer levers, the machine gym, the Magic Keys,
# the casino heist, the Gatling cave door, Xatu's clues, Romualdo's treasure map, the outlaw, the Delibird keypad, the
# mine carts and the lasers of Area 151, each as it is heard without the puzzle assist and with it.
class OpaloPulidoTest < PokeAccessTest
  test "the sewer levers count those down, say when a wrong one puts them back, and give the order with the assist" do
    on_map(226)
    assert_empty @arrival
    assert_equal [progress(:op_sewer_levers, 1, 3)], tick { $game_variables[133] = 2 }
    assert_equal [PokeAccess.sentences([t(:op_sewer_reset), progress(:op_sewer_levers, 0, 3)])], tick { $game_variables[133] = 0 }
    gate = place(28, 20, 48, [], "", 1106)
    assert_equal t(:loc_sign_locked), PokeAccess::Puzzles.piece_name(gate)
    refute_includes info_key.to_s, t(:op_sewer_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_sewer_hint)
    $game_switches[434] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the machine gym tells the way through with the assist alone, and nothing once the medal is won" do
    on_map(46)
    refute_includes info_key.to_s, t(:op_g3_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g3_hint)
    on_map(46) { $game_switches[146] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Magic Keys are named and counted as found, spent ones too, and the Saloon counts its locks" do
    on_map(378)
    key = place(38, 18, 25, [TestCmd.new(0, [])], "", 7123)
    assert_equal t(:op_magic_key), PokeAccess::Puzzles.piece_name(key)
    assert_equal [], listed, "the keys keep to the lens category"
    assert_equal [progress(:op_magic_keys, 1, 4)], tick { $game_variables[205] = 1 }
    assert_equal [], tick { $game_variables[205] = 0; $game_variables[206] = 1 }, "a key spent on a lock is still found"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_magic_keys_hint)
    on_map(404)
    assert_equal [progress(:op_magic_locks, 1, 4)], tick { $game_variables[206] = 1 }
    lock = place(17, 7, 4, [TestCmd.new(101, ["!"])])
    assert_equal t(:op_magic_lock), PokeAccess::Puzzles.piece_name(lock)
  end

  test "the casino names its doors and tells with the assist alone, floor by floor, how the garage gets its power" do
    on_map(341)
    door = place(30, 82, 8, [], "", 1106)
    assert_equal t(:loc_sign_locked), PokeAccess::Puzzles.piece_name(door)
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_casino_hint_lever_floor)
    on_map(342)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_casino_hint_garage_floor)
    refute_includes info_key, t(:op_casino_hint_lever_floor)
    on_map(342) { $game_variables[174] = 6 }
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Gatling cave names its door and tells with the assist where its lever is, until it is pulled" do
    on_map(163)
    door = place(24, 52, 9, [], "", 583)
    assert_equal t(:loc_sign_locked), PokeAccess::Puzzles.piece_name(door)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_gatling_hint_floor)
    $game_switches[334] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Xatu's clue spots are listed with the assist alone, each while its riddle is open" do
    on_map(310)
    $game_switches[679] = true
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [19, 4, t(:op_xatu_clue)]
    $game_switches[680] = true
    refute_includes listed, [19, 4, t(:op_xatu_clue)]
    on_map(328) { $game_switches[683] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [49, 5, t(:op_xatu_clue)]
  end

  test "Romualdo's map is described as drawn, and with the assist the place and the treasure's spot are told" do
    on_map(132)
    with_pictures do
      assert_equal [[t(:op_romualdo_map), true]], picture_said("mapaRomualdo")
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[PokeAccess.sentences([t(:op_romualdo_map), t(:op_romualdo_place)]), true]], picture_said("mapaRomualdo")
    end
    on_map(89) { $game_switches[401] = true }
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [93, 20, t(:op_romualdo_treasure)]
    $game_switches[402] = true
    refute_includes listed, [93, 20, t(:op_romualdo_treasure)]
  end

  test "Area 151 names its lasers by their colour, its doors and its colour panel" do
    on_map(449)
    yellow = place(19, 39, 44, [], "rayosA")
    green = place(26, 70, 15, [], "rayosV")
    door = place(29, 23, 23, [], "", 1106)
    panel = place(16, 54, 47, [TestCmd.new(101, ["!"])])
    assert_equal t(:op_laser_yellow), PokeAccess::Puzzles.piece_name(yellow)
    assert_equal t(:op_laser_green), PokeAccess::Puzzles.piece_name(green)
    assert_equal t(:op_a151_door), PokeAccess::Puzzles.piece_name(door)
    assert_equal t(:op_color_panel), PokeAccess::Puzzles.piece_name(panel)
    on_map(441)
    red = place(28, 22, 39, [], "rayosR")
    assert_equal t(:op_laser_red), PokeAccess::Puzzles.piece_name(red)
  end

  test "the outlaw and the Delibird keypad are named" do
    on_map(393)
    outlaw = place(12, 2, 14, [TestCmd.new(101, ["!"])], "maton")
    assert_equal t(:op_outlaw), PokeAccess::Puzzles.piece_name(outlaw)
    on_map(196)
    pad = place(4, 28, 27, [TestCmd.new(101, ["!"])])
    assert_equal t(:op_code_panel), PokeAccess::Puzzles.piece_name(pad)
  end

  test "a mine cart is named by the way it is boarded, says its ride as it goes and, with the assist, where it goes" do
    on_map(290)
    cart = place(20, 35, 15, [TestCmd.new(0, [])], "vagon")
    left = t(:dir_left)
    assert_equal t(:op_cart_named, :dir => left), PokeAccess::Puzzles.piece_name(cart)
    $game_player.direction = 2
    assert_equal [t(:op_cart_named, :dir => left)], tick { fire(cart) }
    $game_player.direction = 4
    assert_equal [t(:op_cart_ride_said, :to => PokeAccess::Puzzles.offset_phrase(-22, -3))], tick { fire(cart) }
    $game_switches[663] = true
    assert_equal [t(:op_cart_ride_said, :to => PokeAccess::Puzzles.offset_phrase(-6, 10))], tick { fire(cart) }
    PokeAccess::Config.puzzle_assist = true
    $game_switches[664] = true
    assert_equal t(:op_cart_named_ride, :dir => left, :to => PokeAccess::Puzzles.offset_phrase(6, -10)),
                 PokeAccess::Puzzles.piece_name(cart)
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def progress(key, n, of); t(:puzzle_progress, :label => t(key), :n => n, :of => of); end

  # Declares the shipped puzzles as the harness loads the profile and puts the player on map with every flag of the
  # puzzles at rest; what is said on arriving is kept in @arrival.
  def on_map(map)
    Harness.load_puzzles("opalo")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    [146, 334, 401, 402, 434, 663, 664, 665, 666, 667, 668, 669, 670, 672, 679, 680, 681, 682, 683, 684, 764, 902].each do |s|
      $game_switches[s] = false
    end
    [133, 134, 135, 174, 205, 206].each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Puzzles::Auto.forget
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  # An event at (x, y) whose live page runs list, drawn with sprite or tile, placed on the map.
  def place(id, x, y, list, sprite = "", tile = 0)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page, :tile_id => tile)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # What the puzzles say on the next map frame, after the block.
  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # Runs the block with the profile's picture cues evaluated, then drops the picture observers it added.
  def with_pictures
    handlers = PokeAccess::PictureCues::HANDLERS.length
    path = File.join(Harness::ROOT, "games", "opalo", "painted_pictures.rb")
    verbose = $VERBOSE
    $VERBOSE = nil
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    $VERBOSE = verbose
    yield
  ensure
    PokeAccess::PictureCues::HANDLERS.slice!(handlers..-1) if handlers
    PokeAccess::PictureCues.reset_last
  end

  # What the profile says as the game shows a picture, each line with whether it interrupts.
  def picture_said(name)
    SpeakCapture.clear
    PokeAccess::OpaloPictures.on_picture(name)
    SpeakCapture.log.dup
  end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end

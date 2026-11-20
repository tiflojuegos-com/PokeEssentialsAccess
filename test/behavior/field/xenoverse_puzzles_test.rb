# Pokemon Xenoverse's puzzles on the shipped profile: the Root Gym's doors and signs, the Tide Gym's pillars and trap tiles,
# the Rhythm Gym's dance pads and crowd, the Shyleon Temple's pillars and hollows, El Purgatorio's timer and rooms, the
# Quasar Express's papers and the Magnemite of the lair's duct, each as heard with the puzzle assist and without it.
class XenoversePuzzlesTest < PokeAccessTest
  def setup
    super
    @self_switches = $game_self_switches
    $game_self_switches = {}
    class << $game_system
      attr_accessor :timer, :timer_working
    end
    $game_system.timer_working = false
  end

  def teardown
    $game_system.timer_working = false
    $game_self_switches = @self_switches
    super
  end

  test "names the Root Gym's doors by side and its signs, and with the assist says the door each hall's sign marks" do
    on_map(93)
    [[5, 24], [8, 25]].each { |id, x| place(id, x, 116, [door(93, 6, 102)], "", 1) }
    [[11, 36], [12, 37]].each { |id, x| place(id, x, 116, [door(93, 54, 102)], "", 1) }
    [[37, 30], [63, 31]].each { |id, x| place(id, x, 122, [TestCmd.new(101, ["O - X - X"])]) }
    assert_equal [t(:xv_root_door_left), t(:xv_root_door_right), t(:xv_root_sign)].sort, names.sort
    stand(30, 127)
    refute_includes info_key.to_s, t(:xv_root_hint_first)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:xv_root_hint_first)
    stand(30, 75)
    assert_includes info_key, t(:xv_root_hint_second)
    $game_switches[27] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "lists the Tide Gym's pillars and reads their riddle, the trap tiles with the assist alone, and says the fall" do
    on_map(143)
    pillar = place(93, 26, 14, [TestCmd.new(101, ["..."])], "pilastribraille")
    trap = place(13, 27, 10, [door(144, 28, 7)], "", 1)
    assert_equal [t(:xv_tide_pillar)], names
    assert PokeAccess::Puzzles.hidden_event?(trap)
    PokeAccess::World::Mechanics.used(pillar)
    assert_equal [[t(:xv_tide_riddle_grass), false]], tick
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::Puzzles.hidden_event?(trap)
    assert_equal [t(:xv_tide_pillar), t(:xv_tide_trap)].sort, names.sort
    on_map(144)
    assert_equal t(:xv_tide_fell), PokeAccess::Puzzles.sent_back_line([27, 10, 143], [28, 7, 144], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([40, 43, 147], [28, 7, 144], :map), "not from another map"
  end

  test "says where each new dance pad shows up and when the floor goes out, and the info key the newest one" do
    on_map(222)
    tick
    assert_equal t(:xv_dance_first), info_key
    $game_switches[394] = true
    said = tick.map(&:first)
    assert_includes said, t(:xv_dance_next, :dir => t(:dir_down))
    assert(said.any? { |s| s.include?(t(:xv_dance_on)) })
    $game_switches[395] = true
    assert_equal [[t(:xv_dance_next, :dir => t(:dir_right)), false]], tick
    assert_equal t(:xv_dance_next, :dir => t(:dir_right)), info_key
    [394, 395].each { |s| $game_switches[s] = false }
    assert(tick.map(&:first).any? { |s| s.include?(t(:xv_dance_off)) })
    $game_switches[411] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "names the Rock Room's crowd and tells the reset key while on the crowd's floor" do
    on_map(277)
    place(1, 6, 20, [TestCmd.new(355, ["pbPushThisBoulder"])], "hiphopboy", 1)
    assert_equal [t(:xv_rock_crowd)], names
    tick
    refute PokeAccess::Puzzles.active?
    $game_switches[943] = true
    assert_equal [[t(:xv_rock_reset_key), false]], tick
    assert_equal t(:xv_rock_reset_key), info_key
  end

  test "says each Shyleon pillar as it flashes and, with the assist, the order the stele takes" do
    on_map(289)
    tick
    { 430 => 4, 427 => 1, 428 => 2 }.each do |sw, n|
      $game_switches[sw] = true
      assert_equal [[t(:xv_shyleon_pillar, :n => n), false]], tick, "switch #{sw}"
      $game_switches[sw] = false
      assert_equal [], tick
    end
    PokeAccess::Config.puzzle_assist = true
    wrong = [TestCmd.new(250, ["error"], 1)]
    right = [TestCmd.new(102, [%w[A B], 1], 1), TestCmd.new(402, [0, "A"], 1), TestCmd.new(121, [432, 432, 0], 2)]
    assert_equal "Right", option(19, %w[Wrong Right], [wrong, right])
  end

  test "lists the statue's hollows until each mask is in place" do
    on_map(290)
    place(1, 14, 11, [TestCmd.new(101, ["..."])])
    assert_equal [t(:xv_shyleon_hollow_red)], names
    $game_switches[422] = true
    assert_equal [], names
  end

  test "says the time El Purgatorio's timer has left on the info key while it runs" do
    on_map(193)
    refute PokeAccess::Puzzles.active?
    $game_system.timer_working = true
    $game_system.timer = 125 * (Graphics.frame_rate rescue 40)
    assert_includes info_key, t(:xv_purgatory_time, :min => 2, :sec => 5)
    assert_includes info_key, t(:xv_purgatory_rule)
  end

  test "describes the Houndoom's photo, and with the assist names the chest's answer that keeps the player in" do
    on_map(193)
    photo = place(24, 15, 6, [TestCmd.new(231, [1, "houndoom"])])
    PokeAccess::World::Mechanics.used(photo)
    assert_equal [[t(:xv_purgatory_houndoom_shows, :pokemon => species(:HOUNDOOM)), false]], tick
    PokeAccess::Config.puzzle_assist = true
    sent_out = [TestCmd.new(201, [0, 191, 11, 9, 0, 0], 1)]
    assert_equal "Right", option(21, %w[Wrong Right], [sent_out, [TestCmd.new(355, ["pbReceiveItem(:PASS1)"], 1)]])
  end

  test "hides the invisible path's edges and says why the player is back at its start" do
    on_map(195)
    edge = place(1, 24, 46, [door(195, 25, 50)], "", 1)
    assert PokeAccess::Puzzles.hidden_event?(edge)
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 1)
    assert_equal t(:xv_purgatory_path_back), PokeAccess::Puzzles.sent_back_line([24, 46, 195], [25, 50, 195])
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, nil)
  end

  test "names the study's safe and, with the assist, says it is open" do
    on_map(179)
    place(31, 17, 10, [TestCmd.new(101, ["..."])])
    assert_equal [t(:xv_purgatory_safe)], names
    $game_system.timer_working = true
    $game_system.timer = 0
    refute_includes info_key, t(:xv_purgatory_safe_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:xv_purgatory_safe_hint)
  end

  test "names the Quasar Express's heap of papers, as the switch it hides with the assist, until pressed" do
    on_map(190)
    place(22, 7, 4, [TestCmd.new(101, ["..."])])
    assert_equal [t(:xv_quasar_papers)], names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_quasar_switch)], names
    $game_self_switches[[190, 22, "A"]] = true
    assert_equal [], names
  end

  test "names each Magnemite of the duct with the way it faces and, with the assist alone, tells the tiles in its sight" do
    on_map(378)
    magnemite = place(1, 34, 56, [TestCmd.new(101, ["..."])], "magnemite", 2, "Trainer(3)")
    magnemite.direction = 4
    World.next_frame
    assert_equal [t(:xv_lair_magnemite, :pokemon => species(:MAGNEMITE), :dir => t(:dir_left))], names
    assert PokeAccess::XenoLair.seen?(31, 56)
    refute PokeAccess::XenoLair.seen?(30, 56), "past its reach"
    refute PokeAccess::XenoLair.seen?(35, 56), "behind it"
    in_sight = t(:xv_lair_in_sight, :pokemon => species(:MAGNEMITE))
    refute_includes PokeAccess::Camera.tile_lines(31, 56), in_sight, "its reach is not drawn: the trap's, said with the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Camera.tile_lines(31, 56), in_sight
    $game_map.map_id = 369
    refute_includes PokeAccess::Camera.tile_lines(31, 56), in_sight, "on another map"
  end

  test "keeps the walks off a Magnemite's sight with the assist alone, a trap that sends the starter back" do
    on_map(378)
    magnemite = place(1, 34, 56, [TestCmd.new(101, ["..."])], "magnemite", 2, "Trainer(3)")
    magnemite.direction = 4
    World.next_frame
    moves = PokeAccess::Routes::Moves
    assert_equal [31, 56], moves.arrive(31, 56, 4), "without the assist the step is taken"
    PokeAccess::Config.puzzle_assist = true
    assert_nil moves.arrive(31, 56, 4)
    assert_equal [30, 56], moves.arrive(30, 56, 4), "past its reach"
    $game_map.map_id = 369
    assert_equal [31, 56], moves.arrive(31, 56, 4), "on another map"
  end

  test "names the casino's poster, as the button behind it with the assist, until the stairs open" do
    on_map(327)
    place(30, 20, 2, [TestCmd.new(101, ["..."])])
    assert_equal [t(:xv_casino_poster)], names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_casino_button)], names
    $game_switches[544] = true
    assert_equal [], names
  end

  test "lists the sewer nest's cracked tiles alone" do
    on_map(523)
    place(1, 8, 9, [TestCmd.new(121, [676, 676, 0])], "", 1)
    cracked = place(2, 8, 8, [TestCmd.new(201, [0, 304, 8, 48, 0, 0])], "", 1)
    cracked.tile_id = 825
    World.next_frame
    assert_equal [t(:xv_nest_cracked)], names
  end

  test "names Isola Buconero's plants alike, and with the assist which are cut and which hide a Gastly" do
    on_map(488)
    place(1, 25, 39, [TestCmd.new(250, ["Sword2"])], "cutcutie")
    place(2, 16, 31, [TestCmd.new(250, ["Saint4"])], "cutcutie")
    assert_equal [t(:xv_nest_plant)] * 2, names
    PokeAccess::Config.puzzle_assist = true
    gastly = t(:xv_nest_plant_gastly, :pokemon => species(:GASTLY))
    assert_equal [t(:xv_nest_plant_cut), gastly].sort, names.sort
  end

  test "lists the Regi tomb's tile and the move used there with the assist alone, until the tomb opens" do
    on_map(680)
    assert_empty names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_regi_spot, :move => PokeAccess::FieldMoves.name(:ROCKSMASH))], names
    $game_switches[1419] = true
    assert_empty names
  end

  test "hides the saloon's watched tiles until a bell draws them as ghosts, listing them before with the assist alone" do
    on_map(508)
    place(15, 14, 27, [TestCmd.new(101, ["..."])])
    tile = place(1, 31, 34, [TestCmd.new(201, [0, 18, 5, 5, 0, 0])], "", 1)
    assert PokeAccess::Puzzles.hidden_event?(tile)
    assert_equal [t(:xv_nest_bell)], names
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::Puzzles.hidden_event?(tile)
    assert_equal [t(:xv_nest_bell), t(:xv_nest_watched)].sort, names.sort
    PokeAccess::Config.puzzle_assist = false
    ghost = place(1, 31, 34, [TestCmd.new(201, [0, 18, 5, 5, 0, 0])], "Saulghost", 1)
    refute PokeAccess::Puzzles.hidden_event?(ghost)
    assert_equal [t(:xv_nest_bell), t(:xv_nest_ghost)].sort, names.sort
  end

  test "lists the guardian's watched tiles of Percorso 8 with the assist alone" do
    on_map(535)
    tile = place(22, 34, 8, [TestCmd.new(201, [0, 18, 5, 5, 0, 0])], "", 2)
    assert PokeAccess::Puzzles.hidden_event?(tile)
    assert_empty names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_nest_watched)], names
  end

  test "lists the glass bridge's cracked glass alone, by the page its switch shows" do
    on_map(633)
    intact = TestPage.new(:trigger => 1, :sprite => "piastrellealter", :list => [TestCmd.new(121, [1244, 1244, 0])])
    broken = TestPage.new(:trigger => 1, :sprite => "piastrellealter", :list => [TestCmd.new(201, [0, 636, 38, 18, 0, 0])],
                          :condition => { :switch1_valid => true, :switch1_id => 1244 })
    $game_map.events[60] = TestGameEvent.new(:id => 60, :x => 43, :y => 43, :pages => [intact, broken], :active_page => intact)
    $game_map.events[61] = TestGameEvent.new(:id => 61, :x => 42, :y => 43, :pages => [intact, broken], :active_page => broken)
    World.next_frame
    assert_equal [t(:xv_glass_cracked)], names
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A species' name as the data provider gives it.
  def species(id); PokeAccess::Data.species_name(id); end

  # Declares the shipped puzzles and puts the player on map with every flag off.
  def on_map(map)
    Harness.load_puzzles("xenoverse")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    [27, 227, 394, 395, 411, 422, 427, 428, 429, 430, 432, 544, 943, 1419].each { |s| $game_switches[s] = false }
    World.next_frame
  end

  # A Transfer Player command to (x, y) of map.
  def door(map, x, y)
    TestCmd.new(201, [0, map, x, y, 0, 0])
  end

  # An event at (x, y) whose live page runs list, drawn with sprite and fired by trigger, placed on the map.
  def place(id, x, y, list, sprite = "", trigger = 0, name = nil)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    opts = { :id => id, :x => x, :y => y, :pages => [page], :active_page => page }
    opts[:name] = name if name
    ev = TestGameEvent.new(opts)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The option right_choice picks of a menu on an event, its page made of the options and each one's commands.
  def option(id, options, branches)
    list = [TestCmd.new(102, [options, 1], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    place(id, 5, 5, list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
  end

  # Puts the player on (x, y).
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map(&:name)
  end

  # One frame of the puzzle: what it said.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  # What the info key says on the map now.
  def info_key
    PokeAccess::Info.map_text
  end
end

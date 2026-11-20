# Insurgence's checked "unconfirmed" puzzles (games/insurgence/puzzles/: selene_gym, abyssal_base's sewer, infernal_dungeon,
# deep_mantle, alpha_temple, hieroglyph_wall, mysterious_spire) on the shipped profile over events shaped like the game's:
# what a seeing player hears, and what the puzzle assist adds (the answer, the way).
class InsurgenceUnc1PuzzlesTest < PokeAccessTest
  MAPS = [286, 278, 503, 505, 508, 510, 511, 516, 531, 536, 448, 742]
  WORDS = {
    "ins_u1_shade_band" => "Shade band", "ins_u1_invisible" => "Character", "ins_u1_invisible_on" => "invisible",
    "ins_u1_invisible_off" => "visible", "ins_u1_invisible_now" => "Character invisible", "ins_u1_selene_hint" => "Straight up", "ins_u1_sewer" => "Slime sewer",
    "ins_u1_sewer_answer" => "Slime sewer, Seed Flare", "ins_u1_lava_curtain" => "Lava curtain",
    "ins_u1_suit_stand" => "Suit stand", "ins_u1_suit_answer" => "Answer Yes",
    "ins_u1_dungeon_hint" => "Suit first", "ins_u1_tesseract_spot" => "Tesseract spot",
    "ins_u1_mantle_present_hint" => "Go to the past", "ins_u1_mantle_past_hint" => "Walk to the exit",
    "ins_u1_temple_door" => "Temple door", "ins_u1_temple_door_sent" => "Temple door, another one",
    "ins_u1_stone_keyboard" => "Stone keyboard", "ins_u1_pyramid_wall" => "Hieroglyph wall",
    "ins_u1_portal_terminal" => "Portal terminal", "ins_u1_password_shelf" => "Shelf"
  }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    table = PokeAccess::I18n.table(PokeAccess::I18n.lang)
    WORDS.each { |k, v| table[k] ||= v }
  end

  def teardown
    World.clear_events
    [151, 477, 479, 486, 498, 518, 519, 599, 600].each { |i| $game_switches[i] = false }
    $game_variables[41] = 0
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, nil)
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Selene Gym groups the shade bands as one target and says when the character turns invisible" do
    on_map(286)
    [[1, 29, 43], [3, 31, 43], [6, 30, 43]].each { |id, x, y| silent(id, x, y, "invisi") }
    assert_equal [[30, 43, t(:ins_u1_shade_band)]], listed
    frame
    refute_match(/#{t(:ins_u1_invisible_off)}/, info_key.to_s, "the info key keeps quiet while the character shows")
    $game_switches[151] = true
    assert_match(/#{t(:ins_u1_invisible_on)}/, frame.join(" "))
    assert_match(/#{t(:ins_u1_invisible_now)}/, info_key)
    PokeAccess::Config.puzzle_assist = true
    assert_match(/#{t(:ins_u1_selene_hint)}\z/, info_key)
    $game_switches[151] = false
    assert_match(/#{t(:ins_u1_invisible_off)}/, frame.join(" "), "showing again is said as it happens")
  end

  test "Abyssal Base lists its slime sewer while it is slime, and the assist says how to cross it" do
    on_map(278)
    names = ["slime", "slime", "slime", "slime", "slime", "slime", "slime"]
    $game_map.define_singleton_method(:autotile_names) { names }
    assert_equal [[68, 22, t(:ins_u1_sewer)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[68, 22, t(:ins_u1_sewer_answer)]], listed
    names[4] = "water002"
    assert_equal [], listed
  end

  test "the Magma Suit stand and the lava curtain are named, and the assist says to answer Yes" do
    on_map(503)
    silent(2, 29, 14, "EV002")
    suit = silent(3, 36, 24, "EV003")
    assert_equal [[29, 14, t(:ins_u1_lava_curtain)], [36, 24, t(:ins_u1_suit_stand)]], listed
    frame
    assert_equal [], frame { fire(suit) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ins_u1_suit_answer)], frame { fire(suit) }
    assert_match(/#{t(:ins_u1_dungeon_hint)}\z/, info_key)
    $game_switches[486] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "putting the Magma Suit on says nothing of its own: the game's message is all there is" do
    on_map(503)
    silent(3, 36, 24, "EV003")
    frame
    $game_variables[41] = 15
    assert_equal [], frame
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame
  end

  test "Deep Mantle tells the present from the past with the assist and leaves the boulders out of the lists" do
    on_map(505)
    silent(44, 17, 42, "Tesseract_Spot_1")
    boulder = silent(3, 69, 24, "boulder")
    assert_equal [[17, 42, t(:ins_u1_tesseract_spot)]], listed
    assert PokeAccess::Puzzles.hidden_event?(boulder)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:ins_u1_mantle_present_hint)}. #{t(:ins_u1_tesseract_range)}", info_key
    on_map(508)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:ins_u1_mantle_past_hint)}. #{t(:ins_u1_tesseract_range)}", info_key
  end

  test "the variants of the past that the moved statue leads to name the Tesseract and the ruined statue, keep their pushable boulders and say what the rocks do" do
    [[510, :ins_u1_mantle_rocks_open], [511, :ins_u1_mantle_rocks_cut], [516, :ins_u1_mantle_rocks_cut]].each do |map, rocks|
      on_map(map)
      silent(2, 17, 42, "Tesseract_Spot_1")
      statue = silent(44, 33, 17, "DERELICT")
      boulder = silent(3, 69, 24, "boulder")
      assert_equal [[17, 42, t(:ins_u1_tesseract_spot)], [33, 17, t(:ins_u1_mantle_derelict)]], listed
      refute PokeAccess::Puzzles.hidden_event?(boulder), "boulders that are pushed are not hidden"
      assert_equal t(:ins_u1_mantle_derelict), PokeAccess::Puzzles.piece_name(statue)
      PokeAccess::Config.puzzle_assist = true
      assert_equal [t(:ins_u1_mantle_altered_hint), t(rocks), t(:ins_u1_tesseract_range)].join(". "), info_key
    end
  end

  test "Deep Mantle leaves the puzzle list once the Magma Stone is taken" do
    on_map(505)
    silent(44, 17, 42, "Tesseract_Spot_1")
    PokeAccess::Config.puzzle_assist = true
    refute_nil PokeAccess::Puzzles.info_line
    $game_switches[479] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Alpha Temple names the doors that carry within the floor and leaves the ones to other maps their own names" do
    on_map(531)
    inside = silent(2, 20, 17, "door")
    outside = silent(1, 14, 36, "door")
    assert_equal t(:ins_u1_temple_door), PokeAccess::Puzzles.piece_name(inside)
    assert_nil PokeAccess::Puzzles.piece_name(outside)
    assert_equal [[20, 17, t(:ins_u1_temple_door)]], listed
  end

  test "Alpha Temple's stone keyboard gives its word to the assist" do
    on_map(536)
    keyboard = silent(1, 13, 19, "EV001")
    assert_equal [[13, 19, t(:ins_u1_stone_keyboard)]], listed
    assert_equal [], frame { fire(keyboard) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "birth")], frame { fire(keyboard) }
  end

  test "the Holon Pyramid wall groups its row and the assist says the word" do
    on_map(448)
    [[14, 43, 22], [15, 42, 22], [12, 44, 22], [21, 45, 22], [20, 46, 22]].each { |id, x, y| silent(id, x, y, "EV0#{id}") }
    assert_equal [[44, 22, t(:ins_u1_pyramid_wall)]], listed, "the sealed door is part of its row, one target"
    $game_player.direction = 2
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame { fire($game_map.events[15]) }, "the keyboard only answers faced upward"
    $game_player.direction = 8
    assert_equal [t(:puzzle_answer, :a => "sekhmet")], frame { fire($game_map.events[15]) }
    assert_equal [t(:puzzle_answer, :a => "sekhmet")], frame { fire($game_map.events[12]) }
    $game_switches[518] = true
    assert_equal [], frame { fire($game_map.events[15]) }, "nothing to say once the word is known"
    $game_switches[519] = true
    assert_nil PokeAccess::Puzzles.piece_name($game_map.events[12])
  end

  test "the Mysterious Spire terminal and shelves are named, and the assist says the password" do
    on_map(742)
    terminal = silent(7, 34, 12, "EV007")
    [9, 10, 11, 12].each { |id| silent(id, 50 + id, 28, "EV0#{id}") }
    assert_equal [[34, 12, t(:ins_u1_portal_terminal)], [60, 28, t(:ins_u1_password_shelf)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "chandrasekhar")], frame { fire(terminal) }
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("insurgence")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    [151, 477, 479, 486, 498, 518, 519, 599, 600].each { |i| $game_switches[i] = false }
    $game_variables[41] = 0
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def silent(id, x, y, name = "EV#{id}")
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)] }.sort_by { |x, y, _n| [x, y] }
  end
end

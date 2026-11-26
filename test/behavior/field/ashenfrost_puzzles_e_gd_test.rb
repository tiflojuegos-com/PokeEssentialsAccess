# Ashen Frost's puzzles of part E (games/ashenfrost/puzzles/) on the shipped profile over events shaped like the game's: the pool
# room's pipes, the ballroom door, Rotom's cell, the ferry's windows, the Sableye chase, the inn's glasses, the tomb's candles,
# the chess pieces, the children's home vents, Sylvane's hide-and-seek and the Lab Manager. What is heard without the puzzle
# assist is what the screen shows; the answers come with it. I18n.t answers by key and values, so each line is checked by
# both. Gamedata pass.
class AshenFrostPuzzlesEGdTest < PokeAccessTest
  MAPS = [47, 49, 50, 52, 53, 107, 584, 585, 586, 587, 641, 645, 646, 648, 658, 661, 664, 665, 666, 667, 668]
  VARS = [190, 221, 223, 224, 225, 226, 238, 240, 242, 243, 244, 287]
  SWITCHES = [69, 70, 71, 256, 258, 259, 266, 269, 270, 271, 272, 273, 274]
  EVIDENCE = { :TESTGHOST => { :Name => "Ghostly Lady's Testimony" }, :CLUEBOX => { :Name => "Box Clue" },
               :TESTSCOT => { :Name => "Scottsborough's Testimony" }, :CLUEGLASSES => { :Name => "Glasses Clue" },
               :TESTLUCY => { :Name => "Lucy's Testimony" }, :TESTANO => { :Name => "Ano's Testimony" } }

  # The case system's evidence, as Marin's Case System keeps it.
  module EvidenceStub
    def self.compiledData; EVIDENCE; end
  end

  class << self
    attr_accessor :declared
  end

  def setup
    super
    keyed
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @evidence = Object.const_defined?(:Evidence)
    Object.const_set(:Evidence, EvidenceStub) unless @evidence
  end

  def teardown
    World.clear_events
    VARS.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    Object.send(:remove_const, :Evidence) unless @evidence
    mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the pool room says each switch's position as it turns, and the presses to position 1 only with the assist" do
    on_map(648)
    [223, 224, 225, 226].zip([3, 2, 4, 1]).each { |var, value| $game_variables[var] = value }
    [[18, 7], [19, 8], [20, 9], [21, 10]].each { |id, x| silent(id, x, 7) }
    frame
    assert_equal [[7, 7, value(:afe_pipe_red, 3)], [8, 7, value(:afe_pipe_orange, 2)], [9, 7, value(:afe_pipe_yellow, 4)],
                  [10, 7, value(:afe_pipe_green, 1)]], listed
    assert_equal [value(:afe_pipe_red, 4)], frame { $game_variables[223] = 4 }
    presses = [[:afe_pipe_red, 1], [:afe_pipe_orange, 3], [:afe_pipe_yellow, 1], [:afe_pipe_green, 0]]
    list = presses.map { |k, n| key_line(:afe_pipe_presses, :switch => key_line(k), :n => n) }.join(", ")
    refute_includes info_key.to_s, key_line(:afe_pipes_hint, :list => list)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afe_pipes_hint, :list => list)
    $game_switches[258] = true
    refute_includes info_key.to_s, key_line(:afe_pipes_hint, :list => list)
  end

  test "the ballroom door's tape is the assist's, only while the ladder stands and the door is shut" do
    on_map(645)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key.to_s, key_line(:afe_ballroom_hint)
    $game_switches[258] = true
    assert_includes info_key, key_line(:afe_ballroom_hint)
    $game_switches[259] = true
    refute_includes info_key.to_s, key_line(:afe_ballroom_hint)
    $game_switches[259] = false
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, key_line(:afe_ballroom_hint)
  end

  test "Rotom's cell names the ball where it is used, hides the drawn one, and the assist follows the ball, the drill and the car" do
    on_map(646)
    ball = drawn(8, 15, 13, "Object ball")
    silent(9, 16, 13)
    $game_self_switches[[646, 7, "A"]] = true
    frame
    assert_equal [[16, 13, key_line(:afe_rotom_ball)]], listed
    assert PokeAccess::Locator.hidden?(ball)
    refute_includes info_key.to_s, key_line(:afe_rotom_hint_ball)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afe_rotom_hint_ball)
    $game_self_switches[[646, 9, "A"]] = true
    refute PokeAccess::Locator.hidden?(ball)
    assert_equal [], listed
    assert_includes info_key, key_line(:afe_rotom_hint_drill)
    $game_self_switches[[646, 12, "B"]] = true
    assert_includes info_key, key_line(:afe_rotom_hint_car)
    $game_variables[221] = 2
    refute_includes info_key.to_s, key_line(:afe_rotom_hint_car)
  end

  test "the ferry's windows are listed once the case asks for them, the sparkling one apart, and the assist says which gives the clue" do
    on_map(641)
    drawn(6, 5, 15, "HiddenItem_Sparkle")
    silent(5, 8, 15)
    assert_equal [], listed
    $game_switches[256] = true
    assert_equal [[5, 15, key_line(:afe_window_sparkle)], [8, 15, key_line(:afe_window)]], listed
    refute_includes info_key.to_s, key_line(:afe_window_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afe_window_hint)
    $game_self_switches[[641, 6, "A"]] = true
    assert_equal [], listed
    refute_includes info_key.to_s, key_line(:afe_window_hint)
  end

  test "a Sableye running off is said while the chase lasts, and the side to speak from is beside the one standing now" do
    on_map(658)
    silent(32, 25, 21)
    fifth = silent(35, 10, 18)
    frame
    assert_equal [key_line(:afe_sableye_ran)], frame { $game_variables[238] = 1 }
    assert_equal [key_line(:afe_sableye_ran)], frame { $game_variables[238] = 3 }
    assert_equal [key_line(:afe_sableye_ran)], frame { $game_variables[238] = 2 }
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afe_sableye_side, :way => key_line(:afe_face_left))
    assert_equal [[26, 21, key_line(:afe_sableye_spot)]], listed
    $game_variables[238] = 5
    assert_equal [[9, 18, key_line(:afe_sableye_spot)]], listed
    fifth.x, fifth.y = 11, 19
    assert_equal [[10, 19, key_line(:afe_sableye_spot)]], listed, "sent back, the fifth stands at (11,19)"
    $game_variables[238] = 6
    assert_includes info_key, key_line(:afe_sableye_any_side)
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = false
    assert_equal [], frame { $game_variables[238] = 7 }
  end

  test "Truffles' smells are named by colour, the glasses' one marked with the assist, and Alice's evidence named in order" do
    on_map(661)
    smells = [[46, 6, 45, "Yellow"], [50, 23, 45, "Green"], [136, 11, 45, "Red"], [137, 16, 45, "Black"]]
    smells.each { |id, x, y, colour| drawn(id, x, y, "HiddenItem_Smell_#{colour}") }
    bed = $game_map.events[136]
    frame
    assert_equal [], listed
    assert_nil PokeAccess::Puzzles.piece_name(bed)
    $game_switches[71] = true
    assert_equal key_line(:afe_smell_red), PokeAccess::Puzzles.piece_name(bed)
    $game_variables[240] = 2
    assert_equal [[6, 45, key_line(:afe_smell_yellow)], [11, 45, key_line(:afe_smell_red)], [16, 45, key_line(:afe_smell_black)],
                  [23, 45, key_line(:afe_smell_green)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [11, 45, key_line(:afe_smell_clue)]
    assert_includes info_key, key_line(:afe_glasses_hint_smell)
    alice = silent(43, 37, 6)
    $game_switches[71] = false
    $game_variables[240] = 3
    frame
    assert_equal [], frame { mechanics.used(alice) }
    $game_self_switches[[661, 43, "B"]] = true
    said = frame { mechanics.used(alice) }
    assert_equal [key_line(:afe_alice_evidence, :list => "Glasses Clue, Lucy's Testimony, Ano's Testimony")], said
    $game_self_switches[[661, 43, "C"]] = true
    refute_includes info_key.to_s, key_line(:afe_glasses_hint_alice)
  end

  test "the tomb says each candle as it lights by where it stands, the spikes as they sink, and the round's order with the assist" do
    on_map(666)
    candle = silent(4, 9, 12)
    silent(10, 9, 13)
    frame
    assert_includes listed, [9, 13, key_line(:afe_candle_stand, :where => key_line(:afe_candle_c))]
    assert_equal [key_line(:afe_candle_lit, :where => key_line(:afe_candle_c))], frame { candle.character_name = "Object_Candles" }
    assert_equal [], frame { candle.character_name = "" }
    assert_equal [key_line(:afe_spikes_sank)], frame { $game_self_switches[[666, 13, "A"]] = true }
    refute_includes info_key.to_s, key_line(:afe_candles_rule)
    PokeAccess::Config.puzzle_assist = true
    frame
    first = [:afe_candle_bl, :afe_candle_tl, :afe_candle_c].map { |k| key_line(k) }.join(", ")
    assert_includes info_key, key_line(:afe_candles_hint, :list => first)
    order = [:afe_candle_tr, :afe_candle_c, :afe_candle_tr, :afe_candle_tl].map { |k| key_line(k) }.join(", ")
    assert_includes frame { $game_variables[244] = 1 }, key_line(:afe_candles_hint, :list => order), "the round, as it opens"
    assert_includes info_key, key_line(:afe_candles_hint, :list => order)
    last = [:afe_candle_tr, :afe_candle_br, :afe_candle_bl, :afe_candle_c, :afe_candle_tl].map { |k| key_line(k) }.join(", ")
    assert_includes frame { $game_variables[244] = 2 }, key_line(:afe_candles_hint, :list => last)
    $game_variables[244] = 3
    refute_includes info_key.to_s, key_line(:afe_candles_hint, :list => order)
    refute_includes info_key.to_s, key_line(:afe_candles_rule)
  end

  test "the chess count is the info key's from the first piece, never past six, and the assist lists the pieces missing" do
    on_map(665)
    refute_includes info_key.to_s, key_line(:afe_chess_pieces)
    $game_variables[242] = 2
    $game_switches[269] = true
    $game_switches[270] = true
    assert_includes info_key, progress(:afe_chess_pieces, 2, 6)
    frame
    assert_equal [], frame { $game_variables[242] = 3 }
    PokeAccess::Config.puzzle_assist = true
    hint = info_key
    [:afe_chess_henry, :afe_chess_eloise, :afe_chess_hart, :afe_chess_mordecai].each { |k| assert_includes hint, key_line(k) }
    [:afe_chess_lucile, :afe_chess_lue].each { |k| refute_includes hint, key_line(k) }
    $game_variables[242] = 7
    refute_includes info_key.to_s, key_line(:afe_chess_pieces)
  end

  test "the children's home names its vents by where they lead, and the assist counts the children and tells the way" do
    on_map(587)
    silent(17, 9, 2)
    silent(12, 60, 2)
    assert_equal [[9, 2, key_line(:afe_vent_bedroom)], [60, 2, key_line(:afe_vent_listen)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afe_home_hint_door)
    $game_self_switches[[584, 7, "A"]] = true
    $game_variables[190] = 2
    assert_includes info_key, key_line(:afe_home_hint_kids)
    assert_includes info_key, progress(:afe_home_kids, 2, 4)
    $game_variables[190] = 4
    refute_includes info_key.to_s, key_line(:afe_home_hint_kids)
  end

  test "Sylvane's hiders are named and counted only with the assist, which tells the rooms left" do
    on_map(50)
    silent(24, 11, 11)
    $game_variables[287] = 2
    assert_equal [], listed
    refute_includes info_key.to_s, key_line(:afe_hide_found)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[11, 11, key_line(:afe_hider)]], listed
    $game_self_switches[[47, 23, "A"]] = true
    rooms = [:afe_room_library, :afe_room_albums, :afe_room_eloise].map { |k| key_line(k) }.join(", ")
    assert_includes info_key, key_line(:afe_hide_hint, :list => rooms)
    assert_includes info_key, progress(:afe_hide_found, 1, 4)
    $game_variables[287] = 6
    refute_includes info_key.to_s, key_line(:afe_hide_found)
  end

  test "the Lab Manager's evidence and name are said with the assist by the page he is on" do
    on_map(107)
    manager = silent(12, 5, 4)
    frame
    assert_equal [], frame { mechanics.used(manager) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [key_line(:afe_lab_first, :list => "Ghostly Lady's Testimony")], frame { mechanics.used(manager) }
    $game_switches[69] = true
    $game_self_switches[[107, 12, "A"]] = true
    rounds = "Ghostly Lady's Testimony, Box Clue, Scottsborough's Testimony"
    assert_equal ["{afe_lab_answer list=#{rounds}}"], frame { mechanics.used(manager) }, "the name is the entry's"
    $game_self_switches[[107, 12, "B"]] = true
    assert_equal [], frame { mechanics.used(manager) }
    $game_switches[69] = false
    $game_self_switches = {}
    $game_switches[70] = true
    assert_equal [], frame { mechanics.used(manager) }
  end

  private

  # An i18n key and its values as the keyed I18n.t answers them: "{key name=value ...}", the names sorted.
  def key_line(key, vars = nil)
    parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
    "{#{parts.join(' ')}}"
  end

  # Makes I18n.t answer as key_line, so what the puzzles say is compared by its keys and values, not a language's text.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afe_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afe_kept_t)
    i18n.send(:remove_method, :afe_kept_t)
  end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("ashenfrost")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    VARS.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map: no graphic, a page that says something, as the game's controls are.
  def silent(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    place(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page]))
  end

  # An event drawn with sprite, its page saying something.
  def drawn(id, x, y, sprite)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :through => true,
                        :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    place(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page]))
  end

  # Puts an event on the map and lets a frame pass.
  def place(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # A count as the mod says it.
  def progress(label, n, of); key_line(:puzzle_progress, :label => key_line(label), :n => n, :of => of); end

  # A number as the mod says it beside its label.
  def value(label, v); key_line(:puzzle_value, :label => key_line(label), :v => v); end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name as the locator says it], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end

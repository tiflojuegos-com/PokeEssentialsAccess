# Pokemon Ashen Frost's optional puzzles of part F (games/ashenfrost/puzzles/): Palermo's three puzzle boxes, the Flores basement's
# switch, Missing Mom's room, Truffles' smells in Limegate Park, the Bouncer Stakeout's trail, the Number Man of Twisting Cave
# (answered by the core) and the Houndour Game. Without the assist, what the screen shows; with it, the answer.
class AshenFrostPuzzlesFTest < PokeAccessTest
  SWITCHES = [71]
  VARS = [1, 44, 45, 90]

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
    PokeAccess::Puzzles::Answers.forget
    PokeAccess::Puzzles::Reach.forget
    PokeAccess.take_tail
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the study's books and facts are named by the colour their words give, and listed until the box opens" do
    on_map(366, 10, 8)
    book = place(11, 3, 4, "HiddenItem.noshadow", 0, "HiddenItem_Sparkle")
    violet = place(10, 16, 13, "Indigo")
    place(18, 12, 3, "Box.noshadow", 0, "Object_Box")
    assert_equal "{aff_book_red}", PokeAccess::Puzzles.piece_name(book)
    assert_equal "{aff_fact_violet}", PokeAccess::Puzzles.piece_name(violet), "EV10 is named Indigo and checks violet"
    assert_includes listed, [3, 4, "{aff_book_red}"]
    assert_includes listed, [12, 3, "{aff_puzzle_box}"]
    refute_includes info_key, "aff_study_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{aff_study_hint}"
    $game_self_switches[[366, 18, "B"]] = true
    assert_equal [], listed
    refute_includes info_key, "aff_study_hint"
  end

  test "the kitchen's box is named until it gives its paper" do
    on_map(364, 14, 5)
    box = place(19, 14, 4, "Box.noshadow", 0, "Object_Box")
    assert_equal "{aff_puzzle_box}", PokeAccess::Puzzles.piece_name(box)
    assert_includes listed, [14, 4, "{aff_puzzle_box}"]
    $game_self_switches[[364, 19, "B"]] = true
    assert_equal [], listed
  end

  test "the piano room's sheets are named, and the red one is the assist's until the piano is played" do
    on_map(367, 8, 10)
    red = place(5, 8, 9, "HiddenItem.noshadow", 0, "HiddenItem_Sparkle")
    blue = place(6, 9, 9, "HiddenItem.noshadow", 0, "HiddenItem_Sparkle")
    assert_equal "{aff_sheet_red}", PokeAccess::Puzzles.piece_name(red)
    assert_equal "{aff_sheet_blue}", PokeAccess::Puzzles.piece_name(blue)
    refute_includes info_key, "aff_piano_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{aff_piano_hint}"
    $game_self_switches[[367, 15, "A"]] = true
    refute_includes info_key, "aff_piano_hint"
    refute(listed.any? { |_x, _y, name| name.include?("aff_sheet") })
  end

  test "the basement's switch and spikes are named, and the assist says the shortcut below the combination door alone" do
    on_map(646, 15, 47)
    switch = place(26, 14, 47, "Switch")
    spikes = place(25, 14, 43, "Spikes")
    spikes.tile_id = 1336
    assert_equal "{aff_wall_switch}", PokeAccess::Puzzles.piece_name(switch)
    assert_equal "{aff_spikes}", PokeAccess::Puzzles.piece_name(spikes)
    assert_includes listed, [14, 47, "{aff_wall_switch}"]
    refute_includes info_key, "aff_switch_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{aff_switch_hint}"
    $game_player.y = 10
    refute_includes info_key, "aff_switch_hint", "the part above the combination door"
    $game_player.y = 47
    $game_self_switches[[646, 25, "A"]] = true
    assert_equal "{aff_spikes_down}", PokeAccess::Puzzles.piece_name(spikes)
    refute_includes info_key, "aff_switch_hint"
    assert_equal [], listed
  end

  test "agreeing to pay at the greeter, the assist says whether the mother waits in the room drawn" do
    on_map(128, 6, 8)
    place(2, 6, 7, "Counter(4)", 2, "NPC_132")
    $game_variables[45] = 1
    $game_variables[1] = 2
    with_money(5000) do
      assert_equal [], greeter_yes
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["{aff_mom_here}"], greeter_yes
      $game_variables[1] = 0
      assert_equal ["{aff_mom_elsewhere}"], greeter_yes
      $game_variables[45] = 2
      assert_equal [], greeter_yes, "the mother already found"
    end
    $game_variables[45] = 1
    with_money(4999) { assert_equal [], greeter_yes, "with less than the fee no room is drawn" }
  end

  test "Truffles' smells are named while the search is on, sniffed ones say so, and the assist counts the three" do
    on_map(138, 5, 20)
    $game_switches[71] = true
    smell = place(38, 2, 21, "HiddenItem", 0, "HiddenItem_Smell")
    place(39, 4, 19, "HiddenItem", 0, "HiddenItem_Smell_Red")
    assert_equal "{aff_smell}", PokeAccess::Puzzles.piece_name(smell)
    $game_self_switches[[138, 38, "A"]] = true
    $game_variables[44] = 1
    assert_equal "{aff_smell_done}", PokeAccess::Puzzles.piece_name(smell)
    assert_includes listed, [4, 19, "{aff_smell}"]
    refute_includes info_key, "aff_smell"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{puzzle_progress label={aff_smells} n=1 of=3}"
    assert_includes info_key, "{aff_smell_hint}"
    $game_variables[44] = 4
    assert_equal 3, PokeAccess::AshenTruffles.sniffed, "the boy's smell brings the variable past the three"
    $game_switches[71] = false
    assert_equal [], listed
    refute_includes info_key, "aff_smell"
  end

  test "the Stantler's trail is listed and explained with the assist alone, while it waits" do
    on_map(103, 22, 13)
    place(41, 21, 11, "Print 1", 1)
    $game_variables[90] = 2
    assert_equal [], listed
    refute_includes info_key, "aff_trail_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [21, 11, "{aff_trail}"]
    assert_includes info_key, "{aff_trail_hint}"
    $game_variables[90] = 1
    assert_equal [], listed, "before the stakeout"
    $game_variables[90] = 3
    assert_equal [], listed
    refute_includes info_key, "aff_trail_hint"
  end

  test "Twisting Cave's Number Man has its answer, 0, said by the core after his question with the assist alone" do
    on_map(695, 15, 3)
    list = [TestCmd.new(355, ["activateQuest(:Quest136)"]), TestCmd.new(101, ["Hello, hello, hello!"]),
            TestCmd.new(101, ["Tell me how many Lonardo"]), TestCmd.new(401, ["gangsters are hiding in this cave"]),
            TestCmd.new(103, [92, 1]), TestCmd.new(111, [1, 92, 0, 0, 0]), TestCmd.new(101, ["You got it!"], 1),
            TestCmd.new(111, [12, "pbReceiveItem(:PEARL)"], 1), TestCmd.new(123, ["A", 0], 2), TestCmd.new(0, [], 2),
            TestCmd.new(412, [], 1), TestCmd.new(0, [], 1), TestCmd.new(411, []), TestCmd.new(101, ["Wrong!"], 1),
            TestCmd.new(0, [], 1), TestCmd.new(412, []), TestCmd.new(0, [])]
    place(4, 15, 2, "Number Man", 0, "NPC_92")
    assert_nil answered_after(list, 2, 4)
    PokeAccess::Config.puzzle_assist = true
    assert_nil answered_after(list, 1, 4), "the greeting"
    assert_equal "{puzzle_answer a=0}", answered_after(list, 2, 4)
  end

  test "the Houndour are named by their place in the row while the game is on" do
    on_map(705, 29, 26)
    dogs = [[39, 28], [40, 29], [41, 30]].map { |id, x| place(id, x, 24, "Houndour", 0, "228") }
    place(42, 31, 24, "Houndour Game", 0, "NPC_119")
    assert_equal [nil, nil, nil], dogs.map { |d| PokeAccess::Puzzles.piece_name(d) }
    $game_self_switches[[705, 42, "A"]] = true
    assert_equal %w[{aff_houndour_left} {aff_houndour_middle} {aff_houndour_right}],
                 dogs.map { |d| PokeAccess::Puzzles.piece_name(d) }
    assert_includes listed, [29, 24, "{aff_houndour_middle}"]
    $game_self_switches[[705, 42, "B"]] = true
    assert_equal [], listed
  end

  test "the Houndour Game's yes tells the jump and shuffle, and the assist which one holds the prize and its yes" do
    on_map(705, 29, 26)
    place(42, 31, 24, "Houndour Game", 0, "NPC_119")
    assert_equal ["{aff_houndour_shuffle}"], host_yes
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["{aff_houndour_shuffle}", "{aff_houndour_prize}"], host_yes
    prize = place(40, 29, 24, "Houndour B", 0, "228")
    wrong = place(39, 28, 24, "Houndour A", 0, "228")
    assert_equal "Yes", right_option(prize, houndour_menu("pbReceiveItem(:TOXICORB)"))
    assert_nil right_option(wrong, houndour_menu("pbSEPlay('buzzer')"))
  end

  private

  # A Houndour's page while the game is on: its question, and a yes that runs script.
  def houndour_menu(script)
    [TestCmd.new(101, ["Is this your choice?"]), TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]),
     TestCmd.new(111, [12, script], 1), TestCmd.new(0, [], 2), TestCmd.new(412, [], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [1, "No"]), TestCmd.new(0, [], 1), TestCmd.new(404, []), TestCmd.new(0, [])]
  end

  # The option the assist names of an event's menu, its page running on the map's interpreter.
  def right_option(ev, list)
    int = $game_system.map_interpreter
    was = PokeAccess.ivar(int, :@event_id)
    int.instance_variable_set(:@event_id, ev.id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 1)
  ensure
    int.instance_variable_set(:@event_id, was) if int
  end

  # An interpreter on an event's page at command i, with the menu options taken so far by indent.
  def interpreter(id, list, i, branch = {})
    int = Object.new
    { :@list => list, :@index => i, :@event_id => id, :@branch => branch }.each { |k, v| int.instance_variable_set(k, v) }
    int
  end

  # What is said as a menu's first option starts on event id's page.
  def chose_first(id)
    list = [TestCmd.new(102, [%w[Yes No], 1]), TestCmd.new(402, [0, "Yes"]), TestCmd.new(0, [], 1), TestCmd.new(404, [])]
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(interpreter(id, list, 1, { 0 => 0 }))
    SpeakCapture.lines
  end

  def greeter_yes; chose_first(2); end

  # Runs the block with a player holding that much money.
  def with_money(n)
    player = Struct.new(:money).new(n)
    kept = PokeAccess::Engine.method(:player)
    PokeAccess::Engine.define_singleton_method(:player) { player }
    yield
  ensure
    PokeAccess::Engine.define_singleton_method(:player, kept)
  end

  def host_yes; chose_first(42); end

  # What is promised for right after the Show Text at list[i] of event id's page.
  # What the core's answers say after the Show Text at list[i] of event id.
  def answered_after(list, i, id)
    PokeAccess::Puzzles::Answers.forget
    PokeAccess.take_tail
    PokeAccess::Puzzles::Answers.before_text(interpreter(id, list, i))
    PokeAccess.take_tail
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}".
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :aff_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :aff_kept_t)
    i18n.send(:remove_method, :aff_kept_t)
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

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end

# What the assist says at Ashen Frost's own entry screens, the whole profile loaded in a process of its own: the word passCheck
# takes and the melody pbCallFlute plays, each from the game's own call.
class AshenFrostAssistAnswersTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "world_builder")

    # 001_MichaelUtilities.rb's check of a typed code, which opens the entry screen.
    def passCheck(_code, _helptext, _min, _max, _flag = false); false; end

    # Ocarina.rb's call, which opens the melody's screen.
    def pbCallFlute(n, i); [n, i]; end
  RUBY

  PLAY = <<-'RUBY'
    def assisted
      PokeAccess::Config.puzzle_assist = true
      yield
    ensure
      PokeAccess::Config.puzzle_assist = false
    end

    probe(:word_plain) { said { passCheck("Raph", "Combination:", 0, 4, false) } }
    probe(:word_assist) { assisted { said { passCheck("Raph", "Combination:", 0, 4, false) } } }
    probe(:crossword_assist) { assisted { said { passCheck("Priya", "Actress", 0, 5, false) } } }
    probe(:song_plain) { said { pbCallFlute(0, 332) } }
    probe(:songs_assist) { assisted { (0..10).map { |n| said { pbCallFlute(n, 332) } } } }
  RUBY

  profile "ashenfrost", WORLD, PLAY, "gamedata"

  test "with the assist, passCheck's word is said before the entry screen's own line, and nothing more without it" do
    letters = [t(:ashen_letters, :n => 4), false]
    assert_equal [letters], played(:word_plain)
    assert_equal [[t(:puzzle_answer, :a => "Raph"), false], letters], played(:word_assist)
    assert_equal [t(:puzzle_answer, :a => "Priya"), false], played(:crossword_assist)[0]
  end

  test "with the assist, each song of the ocarina's table is said by the arrows of its sheet; none without it" do
    assert_equal [], played(:song_plain)
    words = lambda { |notes| t(:puzzle_answer, :a => notes.map { |n| t("dir_#{n}".to_sym) }.join(", ")) }
    songs = [%w[up right right down left left], %w[left left down right right down], %w[down down right right up right],
             %w[up right right down], %w[up left right left], %w[up up right left], %w[left down right down],
             %w[left down right left], %w[up right right down left down down right right up right],
             %w[left down down down left right down right up right]]
    assert_equal songs.map { |s| [[words.call(s), false]] } + [[]], played(:songs_assist)
  end
end

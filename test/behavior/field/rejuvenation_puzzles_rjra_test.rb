# Pokemon Rejuvenation's remate A (games/rejuvenation/puzzles/): the Zorrialyn Labyrinth's floors and the Zorua room's
# shorter plan. Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesRjraTest < PokeAccessTest
  SWITCHES = [1028]
  VARS = [514, 559, 560, 595]
  DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
  Mon = Struct.new(:name, :types, :egg) do
    def egg?; egg; end
    def hasType?(t); types.include?(t); end
  end

  def setup
    super
    keyed
    Harness.load_puzzles("rejuvenation")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @trainer = defined?($Trainer) ? $Trainer : nil
    @player = defined?($player) ? $player : nil
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    $Trainer = @trainer
    $player = @player
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "B1 names the king's inscription and the sealed door; the assist adds the objective, the steps and the way out" do
    on_map(533, 53, 70)
    $game_variables[595] = 600
    place(42, 2, 79, "EV042")
    door = (43..51).map { |id| place(id, 103 + (id - 43) % 3, 69 + (id - 43) / 3, "EV0#{id}", 0, "tile") }
    place(53, 104, 61, "EV053", 1)
    assert_includes listed_names, "{rjra_lab_panel}"
    assert_equal 1, listed_names.count("{rjra_lab_door}")
    assert_equal "{rjra_lab_shut n=1}", info_key
    refute_includes listed_names, "{rjra_lab_goal}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjra_lab_b1_hint steps=600}"
    assert_includes listed_names, "{rjra_lab_goal}"
    PokeAccess::Puzzles.tick
    door.each { |ev| ev.character_name = "" }
    $game_variables[559] = 1
    lines = said { PokeAccess::Puzzles.tick }
    assert_includes lines.join(" "), "{rjra_lab_open n=1}"
    assert_includes lines.join(" "), "{rjra_lab_b1_out steps=600}"
    refute_includes listed_names, "{rjra_lab_door}"
    assert_includes listed_names, "{rjra_lab_exit}"
    $game_variables[559] = 2
    refute_includes info_key, "rjra_lab"
  end

  test "B1 keeps walks off the Cofagrigus' sight, and only there" do
    PokeAccess::Config.avoid_trainers = false
    on_map(533, 30, 80)
    assert PokeAccess::Routes::Sight.watched?
    on_map(536, 30, 80)
    refute PokeAccess::Routes::Sight.watched?
  end

  test "B2 names the coffin until its battle opens the barrier, and the assist sends the player to the exit" do
    on_map(536, 103, 40)
    $game_variables[559] = 3
    $game_variables[595] = 840
    place(6, 113, 47, "EV006", 0, "tile")
    place(83, 18, 83, "EV083", 1)
    assert_includes listed_names, "{rjra_lab_coffin}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjra_lab_b2_hint steps=840}"
    $game_variables[559] = 4
    World.next_frame
    refute_includes listed_names, "{rjra_lab_coffin}"
    assert_includes listed_names, "{rjra_lab_exit}"
    assert_includes info_key, "{rjra_lab_b2_out steps=840}"
  end

  test "B3's assist names the party members that are both Rock and Water, or says none is" do
    on_map(537, 11, 95)
    $game_variables[559] = 6
    $player = nil
    $Trainer = Struct.new(:party).new([Mon.new("Kabuto", [:ROCK, :WATER], false), Mon.new("Geodude", [:ROCK, :GROUND], false),
                                       Mon.new("Egg", [:ROCK, :WATER], true), Mon.new("Corsola", [:WATER, :ROCK], false)])
    assert_equal %w[Kabuto Corsola], PokeAccess::RejuvLabyrinth.rock_water
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjra_lab_b3_hint party={rjra_lab_b3_party names=Kabuto, Corsola} steps=0}"
    $Trainer = Struct.new(:party).new([Mon.new("Geodude", [:ROCK, :GROUND], false)])
    assert_includes info_key, "{rjra_lab_b3_hint party={rjra_lab_b3_none} steps=0}"
    $game_variables[559] = 7
    World.next_frame
    assert_includes listed_names, "{rjra_lab_pool}"
    assert_includes info_key, "{rjra_lab_b3_out steps=0}"
  end

  test "B4 counts the Luvdisc beaten up to three and the assist goes for them in the shortest order" do
    on_map(541, 53, 20)
    $game_variables[559] = 9
    { 36 => [19, 81], 37 => [80, 19], 38 => [70, 44], 39 => [84, 80] }.each do |id, (x, y)|
      place(id, x, y, "Luvdisc", 1, "pkmn_Luvdisc_1")
    end
    place(79, 53, 81, "EV079", 1)
    lab = PokeAccess::RejuvLabyrinth
    assert_equal 37, lab.next_luvdisc
    $game_map.events[37].character_name = ""
    assert_equal 39, lab.next_luvdisc
    PokeAccess::Puzzles.tick
    $game_variables[560] = 1
    lines = said { PokeAccess::Puzzles.tick }
    assert_includes lines.join(" "), "{puzzle_progress label={rjra_lab_luvdisc} n=1 of=3}"
    $game_variables[560] = 4
    assert_nil lab.next_luvdisc
    assert_includes info_key, "{puzzle_progress label={rjra_lab_luvdisc} n=3 of=3}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed_names, "{rjra_lab_exit}"
    $game_variables[560] = 0
    $game_player.x, $game_player.y = 53, 80
    assert_nil lab.next_luvdisc
    assert_includes info_key, "{rjra_lab_b4_out steps=0}"
  end

  test "the floors' constants stand on the data: the pool dives, the light surfaces and the plan order is the shortest" do
    lab = PokeAccess::RejuvLabyrinth
    assert_includes (52..54).to_a.product((7..9).to_a), lab::POOL
    assert_includes (24..26).to_a.product((84..86).to_a), lab::SURFACE
    assert_equal [37, 39, 38, 36], lab::LUVDISC
  end

  test "the Zorua plan takes the 249 pushes the statues need alone, each from behind its statue, Sableye south first" do
    zorua = PokeAccess::RejuvZorua
    assert_equal 249, zorua::PLAN.size
    assert_equal [39, 2, [18, 81]], zorua::PLAN[0]
    pos = {}
    zorua::START.each { |id, xy| pos[id] = xy.dup }
    zorua::PLAN.each do |id, dir, from|
      assert_equal [pos[id][0] - DIRS[dir][0], pos[id][1] - DIRS[dir][1]], from
      pos[id] = [pos[id][0] + DIRS[dir][0], pos[id][1] + DIRS[dir][1]]
    end
    assert_equal zorua::GOALS, pos
  end

  test "a layout the plan passes twice, with the push said last lost to a load, picks the push on the player's side" do
    zorua = PokeAccess::RejuvZorua
    pos = {}
    zorua::START.each { |id, xy| pos[id] = xy.dup }
    zorua::PLAN.first(148).each { |id, dir, _| pos[id] = [pos[id][0] + DIRS[dir][0], pos[id][1] + DIRS[dir][1]] }
    tiles = zorua::STATUES.map { |id| pos[id] }
    assert_equal [148, 156], zorua.states[tiles]
    at = [$game_player.x, $game_player.y]
    [[[18, 80], 148], [[18, 86], 156]].each do |(x, y), want|
      zorua.forget
      $game_player.x, $game_player.y = x, y
      assert_equal want, zorua.index_for(tiles)
    end
    zorua.forget
    $game_player.x, $game_player.y = 18, 80
    zorua.instance_variable_set(:@index, 155)
    assert_equal 156, zorua.index_for(tiles), "the push after the one said last wins over the nearest"
  ensure
    $game_player.x, $game_player.y = at if at
    zorua.forget
  end

  private

  def said
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  def listed_names
    PokeAccess::Puzzles.category_targets.map do |tg|
      tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name.to_s : PokeAccess::Puzzles.piece_name(tg)
    end
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjra_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjra_kept_t)
    i18n.send(:remove_method, :rjra_kept_t)
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
end

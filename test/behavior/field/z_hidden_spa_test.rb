# Pokemon Z's Balneario Oculto (maps 468 and 345) on the shipped profile: Urano's four riddles, told in turn by var 253,
# each announced as it opens with what it asks for listed; the paintings go by what they show, the plaques that change them
# having nothing else to list them; the assist alone gives the answers.
class ZHiddenSpaTest < PokeAccessTest
  ROOMS = 468
  ENTRANCE = 345
  DEALT = [1, 2, 3, 4]
  PICTURES = { 1 => :z_spa_pic_pikachu, 2 => :z_spa_pic_purple, 3 => :z_spa_pic_wigglytuff, 4 => :z_spa_pic_goldeen }

  test "says nothing as the paintings are dealt on the first arrival, and lists nothing before" do
    on_map(ROOMS, 0, [0, 0, 0, 0])
    tick
    assert_empty PokeAccess::Puzzles.category_targets
    refute PokeAccess::Puzzles.active?
    DEALT.each_with_index { |v, i| $game_variables[249 + i] = v }
    assert_equal [], tick
    assert_equal paintings(DEALT), PokeAccess::Puzzles.category_targets
  end

  test "lists the paintings by what each shows before any riddle is told, the info key left to its usual job" do
    on_map(ROOMS)
    assert_equal paintings(DEALT), PokeAccess::Puzzles.category_targets
    refute PokeAccess::Puzzles.active?
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "says what a touched painting now shows, and the info key all four" do
    on_map(ROOMS, 7)
    tick
    $game_variables[249] = 4
    assert_equal [[painting(1, 4), false]], tick
    assert_equal "#{t(:z_spa4_title)}. #{line([4, 2, 3, 4])}", info_key
    assert_equal paintings([4, 2, 3, 4]), PokeAccess::Puzzles.category_targets
  end

  test "says a number no picture goes with as the number" do
    on_map(ROOMS)
    tick
    $game_variables[250] = 9
    assert_equal [[t(:puzzle_value, :label => t(:z_spa_painting, :n => 2), :v => 9), false]], tick
  end

  test "announces each riddle as Urano tells it, and nothing over his lines between them" do
    on_map(ROOMS)
    tick
    { 1 => :z_spa1_title, 2 => nil, 3 => :z_spa2_title, 4 => nil, 5 => :z_spa3_title, 6 => nil,
      7 => :z_spa4_title }.each do |stage, title|
      $game_variables[253] = stage
      assert_equal title ? [[t(title), false]] : [], tick, "stage #{stage}"
    end
  end

  test "announces a riddle with its answer when the assist is on, and the info key repeats it" do
    { 1 => [:z_spa1_title, :z_spa1_hint], 3 => [:z_spa2_title, :z_spa2_hint], 5 => [:z_spa3_title, :z_spa3_hint],
      7 => [:z_spa4_title, :z_spa4_hint] }.each do |stage, (title, hint)|
      on_map(ENTRANCE, stage - 1)
      PokeAccess::Config.puzzle_assist = true
      tick
      $game_variables[253] = stage
      assert_equal [["#{t(title)}. #{t(hint)}", false]], tick, "stage #{stage}"
      assert_includes info_key, t(hint)
      PokeAccess::Config.puzzle_assist = false
      refute_includes info_key, t(hint)
    end
  end

  test "says on the info key that Urano has the next riddle after each one solved, on both maps" do
    [2, 4, 6].each do |stage|
      on_map(ENTRANCE, stage)
      assert_equal t(:z_spa_back), info_key, "stage #{stage}"
      on_map(ROOMS, stage)
      assert_equal "#{t(:z_spa_back)}. #{line(DEALT)}", info_key, "stage #{stage}"
    end
  end

  test "lists the mirror for the first riddle, where it is" do
    on_map(ROOMS, 1)
    assert_equal [spot(27, 9, t(:z_spa_mirror))] + paintings(DEALT), PokeAccess::Puzzles.category_targets
    assert_equal "#{t(:z_spa1_title)}. #{line(DEALT)}", info_key
    on_map(ENTRANCE, 1)
    assert_empty PokeAccess::Puzzles.category_targets
    assert_equal t(:z_spa1_title), info_key
  end

  test "lists the candles still to touch for the second riddle, the third with no sprite of its own, and counts them" do
    on_map(ENTRANCE, 3)
    candle(20, 19, 26)
    candle(21, 5, 10)
    candle(26, 48, 23)
    assert_equal [candle_target(20, 19, 26), candle_target(21, 5, 10), candle_target(26, 48, 23)],
                 PokeAccess::Puzzles.category_targets
    assert_equal t(:z_spa2_title), info_key, "no count before the first"
    tick
    place(26, 48, 23, [TestCmd.new(0, [])])
    $game_variables[254] = 1
    assert_equal [[t(:puzzle_progress, :label => t(:z_spa_candles), :n => 1, :of => 3), false]], tick, "a candle says nothing itself"
    assert_equal [candle_target(20, 19, 26), candle_target(21, 5, 10)], PokeAccess::Puzzles.category_targets
    assert_equal "#{t(:z_spa2_title)}. #{t(:puzzle_progress, :label => t(:z_spa_candles), :n => 1, :of => 3)}", info_key
  end

  test "lists only the paintings in the rooms while the candles and the clown are asked for" do
    [[3, :z_spa2_title], [5, :z_spa3_title]].each do |stage, title|
      on_map(ROOMS, stage)
      assert_equal paintings(DEALT), PokeAccess::Puzzles.category_targets, "stage #{stage}"
      assert_equal "#{t(title)}. #{line(DEALT)}", info_key
    end
  end

  test "lists the clown for the third riddle" do
    on_map(ENTRANCE, 5)
    place(23, 32, 25, [TestCmd.new(101, ["!"])], "payaso")
    assert_equal [spot(32, 25, t(:z_spa_clown))], PokeAccess::Puzzles.category_targets
  end

  test "sends the player to Urano's challenge once the paintings are solved, then leaves the info key alone" do
    on_map(ROOMS, 7)
    tick
    $game_switches[775] = true
    assert_equal [], tick, "Urano's own lines say it"
    assert_equal t(:z_spa_last), info_key
    assert_empty PokeAccess::Puzzles.category_targets, "the paintings no longer matter"
    $game_switches[778] = true
    assert_equal [], tick
    refute PokeAccess::Puzzles.active?
    assert_nil PokeAccess::Puzzles.info_line
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Declares the shipped puzzles as the harness loads the profile and puts the player on map at riddle stage, the paintings
  # showing shown and their four plaques (events 12-15) in place.
  def on_map(map, stage = 0, shown = DEALT)
    Harness.load_puzzles("pokemon_z")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    shown.each_with_index { |v, i| $game_variables[249 + i] = v }
    $game_variables[253] = stage
    $game_variables[254] = 0
    [775, 778].each { |s| $game_switches[s] = false }
    (0..3).each { |i| place(12 + i, 14 + 2 * i, 25, [TestCmd.new(122, [])]) } if map == ROOMS
    World.next_frame
  end

  # An event at (x, y) whose live page runs list, drawn with sprite, placed on the map.
  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A candle still to touch.
  def candle(id, x, y)
    place(id, x, y, [TestCmd.new(122, [])])
  end

  # A candle still to touch, as the locator lists it.
  def candle_target(id, x, y)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(:z_spa_candle), :puzzle_hidden, id)
  end

  # A named point, as the locator lists it.
  def spot(x, y, name)
    PokeAccess::Locator::SurfaceTarget.new(x, y, name, :puzzle_spot, nil)
  end

  # Painting n showing value, as said.
  def painting(n, value)
    t(:puzzle_value, :label => t(:z_spa_painting, :n => n), :v => t(PICTURES[value]))
  end

  # The four paintings showing values, as the locator lists them.
  def paintings(values)
    values.each_with_index.map do |v, i|
      PokeAccess::Locator::SurfaceTarget.new(14 + 2 * i, 25, painting(i + 1, v), :puzzle_value, 12 + i)
    end
  end

  # The four paintings showing values, as the info key says them.
  def line(values)
    values.each_with_index.map { |v, i| painting(i + 1, v) }.join(", ")
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

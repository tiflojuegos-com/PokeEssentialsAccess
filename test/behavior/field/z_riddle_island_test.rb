# Pokemon Z's Isla Certijo (map 123) on the shipped profile: the Riddle King's four riddles, opened in turn by switches
# 226-232, each announced as it opens, read by the info key and listed by the locator; the assist alone gives answers.
class ZRiddleIslandTest < PokeAccessTest
  ISLAND = 123
  RIDDLE_SWITCHES = (226..232).to_a
  STARS = [226]
  FIRST_RETURN = [226, 227]
  SIGNS = [226, 227, 228]
  SECOND_RETURN = [226, 227, 228, 229]
  PIKACHU = [226, 227, 228, 229, 230]
  LAST = [226, 227, 228, 229, 230, 231]
  BEATEN = RIDDLE_SWITCHES

  test "announces each riddle as its switch opens it, and nothing over the King's own lines" do
    on_island([])
    tick
    { STARS => [[t(:riddle1_title), false]], FIRST_RETURN => [], SIGNS => [[t(:riddle2_title), false]],
      SECOND_RETURN => [], PIKACHU => [[t(:riddle3_title), false]], LAST => [[t(:riddle4_title), false]],
      BEATEN => [] }.each do |on, said|
      switches(on)
      assert_equal said, tick, "switches #{on.inspect} on"
    end
  end

  test "announces a riddle with its answer when the assist is on" do
    on_island([])
    PokeAccess::Config.puzzle_assist = true
    tick
    switches(STARS)
    assert_equal [["#{t(:riddle1_title)}. #{t(:riddle1_hint)}", false]], tick
  end

  test "leaves the info key to its usual job before the challenge is accepted" do
    on_island([])
    refute PokeAccess::Puzzles.active?
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "lists only the King's statue before the challenge is accepted and once he is beaten" do
    { "before" => [], "beaten" => BEATEN }.each do |stage, on|
      on_island(on)
      star_bushes
      assert_equal [spot(30, 10, t(:riddle_king))], PokeAccess::Puzzles.category_targets, stage
    end
  end

  test "says on the info key that the King has the next riddle after each one solved" do
    [FIRST_RETURN, SECOND_RETURN].each do |on|
      on_island(on)
      assert_equal t(:riddle_back), info_key, "switches #{on.inspect} on"
    end
  end

  test "lists the star bushes still to press, and the King's statue" do
    on_island(STARS)
    star_bushes
    assert_equal [spot(30, 10, t(:riddle_king)),
                  target(24, 16, t(:riddle_star), :puzzle_hidden, 9),
                  target(30, 30, t(:riddle_star), :puzzle_hidden, 8),
                  target(40, 22, t(:riddle_star), :puzzle_hidden, 5),
                  target(18, 35, t(:riddle_star), :puzzle_hidden, 7)],
                 PokeAccess::Puzzles.category_targets, "bush 6, already found, is left out"
  end

  test "lists no bush for a star event with no live page or missing from the map" do
    on_island(STARS)
    place(9, 24, 16, [TestCmd.new(101, ["!"])])
    place(8, 30, 30, nil)
    assert_equal [spot(30, 10, t(:riddle_king)), target(24, 16, t(:riddle_star), :puzzle_hidden, 9)],
                 PokeAccess::Puzzles.category_targets, "8 has no page whose conditions hold; 6, 5 and 7 are not there"
  end

  test "keeps the star count off the info key while none is found" do
    on_island(STARS)
    assert_equal t(:riddle1_title), info_key
  end

  test "reads the star count on the info key once one is found" do
    on_island(STARS)
    [1, 2].each do |found|
      $game_variables[112] = found
      assert_equal "#{t(:riddle1_title)}. #{count(:riddle_stars, found, 5)}", info_key, "#{found} found"
    end
  end

  test "leaves a star found to the game: its count is not announced" do
    on_island(STARS)
    tick
    $game_variables[112] = 1
    assert_equal [], tick
  end

  test "gives the stars' answer on the info key with the assist" do
    on_island(STARS)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:riddle1_title)}. #{t(:riddle1_hint)}", info_key
  end

  test "says a sign's new number as it is pressed" do
    on_island(SIGNS)
    signs
    tick
    $game_variables[113] = 2
    assert_equal [[sign(1, 2), false]], tick
  end

  test "lists each sign with its number, and the plate that checks them" do
    on_island(SIGNS)
    signs
    show_on_signs([2, 1, 3, 2])
    assert_equal [spot(30, 10, t(:riddle_king)), spot(15, 59, t(:riddle_plate)),
                  target(12, 57, sign(1, 2), :puzzle_value, 11), target(18, 57, sign(2, 1), :puzzle_value, 12),
                  target(12, 60, sign(3, 3), :puzzle_value, 13), target(18, 60, sign(4, 2), :puzzle_value, 14)],
                 PokeAccess::Puzzles.category_targets
  end

  test "reads every sign and their sum on the info key" do
    on_island(SIGNS)
    show_on_signs([2, 1, 3, 2])
    assert_equal "#{t(:riddle2_title)}. #{signs_line([2, 1, 3, 2])}. #{t(:puzzle_sum, :n => 8)}", info_key
  end

  test "gives the signs' answer on the info key with the assist" do
    on_island(SIGNS)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:riddle2_title)}. #{signs_line([0, 0, 0, 0])}. #{t(:puzzle_sum, :n => 0)}. #{t(:riddle2_hint)}",
                 info_key
  end

  test "says where a pushed Pikachu went from the player" do
    on_island(PIKACHU)
    pikachu = pikachu_and_arrow
    tick
    { [15, 20] => "3 #{t(:dir_right)}", [15, 23] => "3 #{t(:dir_right)}, 3 #{t(:dir_down)}",
      [10, 17] => "2 #{t(:dir_left)}, 3 #{t(:dir_up)}" }.each_with_index do |((x, y), dist), i|
      pikachu.x = x
      pikachu.y = y
      assert_equal [[t(:puzzle_track_rel, :label => t(:riddle_pikachu), :dist => dist), i > 0]], tick,
                   "at (#{x}, #{y})"
    end
  end

  test "says with the assist how far a pushed Pikachu still is from Donphan's corner, or that it is in" do
    on_island(PIKACHU)
    pikachu = pikachu_and_arrow
    PokeAccess::Config.puzzle_assist = true
    tick
    { [16, 20] => "38 #{t(:dir_right)}, 20 #{t(:dir_down)}", [53, 42] => "1 #{t(:dir_right)}",
      [60, 45] => "1 #{t(:dir_up)}", [73, 39] => "1 #{t(:dir_left)}, 1 #{t(:dir_down)}",
      [54, 40] => nil, [72, 44] => nil, [60, 42] => nil }.each_with_index do |((x, y), dist), i|
      pikachu.x = x
      pikachu.y = y
      said = if dist
               t(:puzzle_track_goal, :label => t(:riddle_pikachu), :dist => dist, :goal => goal)
             else
               t(:puzzle_track_in, :label => t(:riddle_pikachu), :goal => goal)
             end
      assert_equal [[said, i > 0]], tick, "at (#{x}, #{y})"
    end
  end

  test "cuts its last line on a pushed Pikachu with the next one while nothing else was said since" do
    on_island(PIKACHU)
    pikachu = pikachu_and_arrow
    tick
    PokeAccess.speak(t(:riddle3_title), false)
    cuts = [15, 16, 17].map do |x|
      pikachu.x = x
      tick.map { |pair| pair[1] }
    end
    PokeAccess.speak(t(:riddle3_title), false)
    pikachu.x = 18
    cuts.push(tick.map { |pair| pair[1] })
    assert_equal [[false], [true], [true], [false]], cuts
  end

  test "says no second time that the Pikachu is in Donphan's corner when the line said last already tells it" do
    on_island(PIKACHU)
    pikachu = pikachu_and_arrow
    PokeAccess::Config.puzzle_assist = true
    tick
    PokeAccess.speak(t(:puzzle_track_in, :label => t(:riddle_pikachu), :goal => goal), false)
    pikachu.x = 54
    pikachu.y = 40
    assert_equal [], tick
  end

  test "lists the Pikachu itself and the arrow that puts it back, and Donphan's corner only with the assist" do
    on_island(PIKACHU)
    pikachu = pikachu_and_arrow
    listed = [spot(30, 10, t(:riddle_king)), spot(12, 18, t(:riddle_reset)), pikachu]
    assert_equal listed, PokeAccess::Puzzles.category_targets, "without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal listed + [target(54, 42, goal, :puzzle_goal, 16)], PokeAccess::Puzzles.category_targets,
                 "with it"
  end

  test "names the Pikachu it lists by its sprite's species" do
    on_island(PIKACHU)
    assert_equal "Especie25", PokeAccess::Locator.target_name(pikachu_and_arrow), "species 25, as the engine names it"
  end

  test "reads on the info key where the Pikachu stands, and with the assist how far from the corner and the answer" do
    on_island(PIKACHU)
    pikachu_and_arrow.x = 15
    name = t(:riddle_pikachu)
    assert_equal "#{t(:riddle3_title)}. #{t(:puzzle_track_rel, :label => name, :dist => "3 #{t(:dir_right)}")}",
                 info_key, "without the assist"
    PokeAccess::Config.puzzle_assist = true
    far = t(:puzzle_track_goal, :label => name, :dist => "39 #{t(:dir_right)}, 20 #{t(:dir_down)}", :goal => goal)
    assert_equal "#{t(:riddle3_title)}. #{far}. #{t(:riddle3_hint)}", info_key, "with it"
  end

  test "routes Donphan's corner, with the assist alone, as the push of the Pikachu into it" do
    on_island(PIKACHU)
    pikachu_by_the_corner
    corner = target(54, 42, goal, :puzzle_goal, 16)
    PokeAccess::Config.puzzle_assist = true
    plan = PokeAccess::Locator.route_plan(corner)
    assert_equal [:assisted, [6], [53, 42]], [plan.kind, plan.route, plan.gate && [plan.gate[:x], plan.gate[:y]]],
                 "a step to stand behind it, then the push that puts it in"
    assert_nil PokeAccess::Puzzles.carry_plan(spot(30, 10, t(:riddle_king))), "any other target is routed as usual"
    PokeAccess::Config.puzzle_assist = false
    assert_nil PokeAccess::Puzzles.carry_plan(corner), "and without the assist neither is the corner"
  end

  test "counts aloud each time the King is asked again only with the assist" do
    { false => [], true => [[count(:riddle_asked, 2, 7), false]] }.each do |assist, said|
      on_island(LAST)
      PokeAccess::Config.puzzle_assist = assist
      $game_variables[118] = 1
      tick
      $game_variables[118] = 2
      assert_equal said, tick, "assist #{assist}"
    end
  end

  test "reads the last riddle on the info key, with the asks and the answer only with the assist" do
    on_island(LAST)
    $game_variables[118] = 3
    assert_equal t(:riddle4_title), info_key, "without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:riddle4_title)}. #{count(:riddle_asked, 3, 7)}. #{t(:riddle4_hint)}", info_key, "with it"
  end

  test "counts no ask once the King is beaten, even with the assist" do
    on_island(BEATEN)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[118] = 7
    tick
    $game_variables[118] = 8
    assert_equal [], tick, "talking to him again after the fight"
  end

  test "says nothing over the King's own words when he is beaten" do
    on_island(LAST)
    tick
    switches(BEATEN)
    assert_equal [], tick
  end

  test "says on the info key that the island is solved once the King is beaten" do
    on_island(BEATEN)
    assert_equal true, PokeAccess::Puzzles.active?, "the info key still belongs to the island"
    assert_equal t(:riddle_solved), info_key
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Declares the shipped Pokemon Z puzzles as the harness loads the profile (games/pokemon_z/puzzles.rb, through
  # Harness.source) and puts the player on the island with the riddle switches in on turned on.
  def on_island(on)
    path = File.join(Harness::ROOT, "games", "pokemon_z", "puzzles.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    $game_map.map_id = ISLAND
    switches(on)
    World.next_frame
  end

  # Turns on the riddle switches in on and off the rest.
  def switches(on)
    RIDDLE_SWITCHES.each { |s| $game_switches[s] = on.include?(s) }
  end

  # An event at (x, y) whose live page runs list, drawn with sprite, placed on the map.
  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The five star bushes, events 9, 8, 6, 5 and 7: 6 already found (its page runs nothing), the rest still to press
  # (their page shows text).
  def star_bushes
    [[9, 24, 16], [8, 30, 30], [5, 40, 22], [7, 18, 35]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["!"])]) }
    place(6, 24, 41, [TestCmd.new(0, [])])
  end

  # The four number signs, events 11 to 14.
  def signs
    [[11, 12, 57], [12, 18, 57], [13, 12, 60], [14, 18, 60]].each { |id, x, y| place(id, x, y, [TestCmd.new(122, [])]) }
  end

  # The numbers the four signs show (variables 113 to 116).
  def show_on_signs(values)
    values.each_with_index { |v, i| $game_variables[113 + i] = v }
  end

  # The Pikachu (event 16) at (13, 20) and its reset arrow (event 2) at (12, 18), the player at (12, 20); returns the
  # Pikachu.
  def pikachu_and_arrow
    $game_player.x = 12
    $game_player.y = 20
    place(2, 12, 18, [TestCmd.new(101, ["?"])], "flecha")
    place(16, 13, 20, [TestCmd.new(209, [])], "025")
  end

  # Rows 41 and 42 walled in and open from x 51 to Donphan's corner at x 54, the player on (51, 42) and the Pikachu
  # (event 16) on (53, 42) as Z draws it: walked into facing east, it steps a tile east where the map lets it. Row 41
  # is a way to the corner past it, with no push.
  def pikachu_by_the_corner
    $game_map.load_grid(Array.new(41) { "#" * 56 } + ["#" * 51 + "....#", "#" * 51 + "@...#"])
    step_east = TestMoveRoute.new([TestMoveCmd.new(3), TestMoveCmd.new(0)])
    pikachu = World.touch(:id => 16, :x => 53, :y => 42, :sprite => "025",
                          :list => [World.if_facing(6), TestCmd.new(209, [0, step_east], 1), TestCmd.new(0, [], 1),
                                    World.end_])
    pikachu.blocking = true
    def pikachu.passableStrict?(x, y, d)
      $game_map.passable?(x, y, d)
    end
  end

  # Runs one map frame of the puzzles and returns what it said, as [text, interrupt] pairs.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  # What the info key says on the map now.
  def info_key
    PokeAccess::Info.map_text
  end

  # A locator target the puzzles list.
  def target(x, y, name, key, ref = nil)
    PokeAccess::Locator::SurfaceTarget.new(x, y, name, key, ref)
  end

  # A named point of the island for the locator.
  def spot(x, y, name)
    target(x, y, name, :puzzle_spot)
  end

  # Sign n showing value, as said.
  def sign(n, value)
    t(:puzzle_value, :label => t(:riddle_sign, :n => n), :v => value)
  end

  # The four signs showing values, as the info key says them.
  def signs_line(values)
    values.each_with_index.map { |v, i| sign(i + 1, v) }.join(", ")
  end

  # Donphan's corner, the Pikachu's goal, as said.
  def goal
    t(:riddle_goal)
  end

  # A counter labelled by key at n of total, as said.
  def count(key, n, total)
    t(:puzzle_progress, :label => t(key), :n => n, :of => total)
  end
end

# The locator's list: each target known by an identity that outlives rebuilds, ordered and numbered as chosen, built
# at the first J or L, its selection kept on the map, back to all for a category gone or empty; page verdicts memoized.
class TargetListTest < PokeAccessTest
  T = PokeAccess::I18n
  # Four people: A (id 4) six presses away on foot and seven straight; B (id 3) two straight and thirteen on foot round
  # the wall; C (id 1) in an alcove off the way to B; D (id 2) walled in.
  WALLED = ["##########",
            "#@.......#",
            "#######.##",
            "#.......##",
            "####.#####",
            "#.########",
            "##########"]
  PEOPLE = { :a => [4, 8, 1], :b => [3, 1, 3], :c => [1, 4, 4], :d => [2, 1, 5] }
  # An open room with the player in its middle, and a person on each side of them: the nearer to the right and below.
  OPEN = ["#########",
          "#.......#",
          "#.......#",
          "#...@...#",
          "#.......#",
          "#.......#",
          "#########"]
  AROUND = { :right => [1, 6, 3], :left => [2, 1, 3], :below => [3, 4, 4], :above => [4, 4, 1] }

  test "orders by straight distance, nearest first, the walls not counted" do
    with_target_list do |loc, _evs|
      assert_equal [3, 2, 1, 4], pressed_order(loc)
    end
  end

  test "measures the straight distance to either side of the player, ties going by the fixed order" do
    with_target_list(OPEN, AROUND) do |loc, _evs|
      assert_equal [3, 1, 4, 2], pressed_order(loc)
    end
  end

  test "orders by the fewest presses on foot, those with no way last" do
    with_target_list do |loc, _evs|
      PokeAccess::Config.target_order = :walk
      assert_equal [4, 1, 3, 2], pressed_order(loc)
    end
  end

  test "orders by event id in the fixed order" do
    with_target_list do |loc, _evs|
      PokeAccess::Config.target_order = :fixed
      assert_equal [1, 2, 3, 4], pressed_order(loc)
    end
  end

  test "numbers a target by its place, its rank among those listed, or its rank among them all" do
    with_target_list do |loc, evs|
      PokeAccess::Config.hide_unreachable = :unreachable
      loc.rebuild_targets
      { :off => [[1, 3], [2, 3], [3, 3]], :dynamic => [[2, 3], [1, 3], [3, 3]],
        :static => [[3, 4], [1, 4], [4, 4]] }.each do |mode, want|
        PokeAccess::Config.target_numbering = mode
        assert_equal want, [:b, :c, :a].map { |k| loc.number_of(evs[k]) }, "numbering #{mode}"
      end
    end
  end

  test "numbers a hidden target only by its rank among them all" do
    with_target_list do |loc, evs|
      PokeAccess::Config.hide_unreachable = :unreachable
      loc.rebuild_targets
      got = [:off, :dynamic, :static].map do |mode|
        PokeAccess::Config.target_numbering = mode
        loc.number_of(evs[:d])
      end
      assert_equal [nil, nil, [2, 4]], got
    end
  end

  test "a static number keeps its gap when a target before it goes or is hidden" do
    with_target_list do |loc, evs|
      PokeAccess::Config.target_numbering = :static
      loc.rebuild_targets
      before = loc.number_of(evs[:a])
      PokeAccess::Tags.set_hidden($game_map.map_id, 1, true)
      $game_map.events.delete(2)
      World.next_frame
      loc.rebuild_targets
      assert_equal [[4, 4], [4, 4]], [before, loc.number_of(evs[:a])]
    end
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 1)
  end

  test "J goes on from the selection, and past one gone, to the one after it in the order" do
    with_target_list do |loc, _evs|
      PokeAccess::Config.target_order = :fixed
      picked = (1..2).map { loc.step(1); loc.target.id }
      $game_map.events.delete(2)
      World.next_frame
      loc.step(1)
      assert_equal [1, 2, 3], picked + [loc.target.id]
    end
  end

  test "L past a selection gone goes to the one before it, round the list from the first" do
    { 1 => 4, 3 => 2 }.each do |gone, want|
      with_target_list do |loc, _evs|
        PokeAccess::Config.target_order = :fixed
        press_to(loc, gone)
        $game_map.events.delete(gone)
        World.next_frame
        loc.step(-1)
        assert_equal want, loc.target.id, "with #{gone} gone"
      end
    end
  end

  test "J with no target on the map says there are none" do
    $game_map.load_grid(["#####", "#@..#", "#####"])
    PokeAccess::Locator.step(1)
    assert_equal [[T.t(:loc_no_targets), true]], SpeakCapture.log
  end

  test "J goes round the marks, made afresh at every press" do
    loc = PokeAccess::Locator
    $game_map.load_grid(["########", "#@.....#", "########"])
    PokeAccess::Marks.set($game_map.map_id, 3, 1, "uno")
    PokeAccess::Marks.set($game_map.map_id, 5, 1, "dos")
    loc.instance_variable_set(:@cat_id, :marks)
    assert_equal ["uno", "dos", "uno"], (1..3).map { loc.step(1); loc.target.name }
  ensure
    PokeAccess::Marks.delete($game_map.map_id, 3, 1)
    PokeAccess::Marks.delete($game_map.map_id, 5, 1)
    loc.instance_variable_set(:@cat_id, :all)
  end

  test "an empty category gives way to all, said before the target" do
    with_target_list do |loc, _evs|
      loc.instance_variable_set(:@cat_id, :signs)
      loc.step(1)
      assert_equal [:all, true], [loc.category, said_first?(T.t(:loc_category, :cat => T.t(:tcat_all), :n => 4))]
    end
  end

  test "a category no longer offered gives way to all, said before the target" do
    with_target_list do |loc, _evs|
      loc.instance_variable_set(:@cat_id, :marks)
      loc.step(1)
      assert_equal [:all, true], [loc.category, said_first?(T.t(:loc_category, :cat => T.t(:tcat_all), :n => 4))]
    end
  end

  test "Shift+L says the category and its first target after it, so L goes on to the second" do
    with_target_list do |loc, _evs|
      loc.instance_variable_set(:@cat_id, :all)
      loc.cycle_category(1)
      shown = [loc.category, loc.target.id, said_first?(T.t(:loc_category, :cat => T.t(:tcat_people), :n => 4))]
      loc.step(1)
      assert_equal [:people, 3, true, 2], shown + [loc.target.id]
    end
  end

  test "Shift+L into an empty category says it whole and turns a guide on off without a word" do
    with_guide_state do
      with_target_list do |loc, _evs|
        loc.step(1)
        PokeAccess::Guide.switch(:cane, true)
        SpeakCapture.clear
        loc.cycle_category(1)
        guide_frame
        assert_equal [[T.t(:loc_category, :cat => T.t(:tcat_objects), :n => 0)], false],
                     [SpeakCapture.lines, PokeAccess::Guide.on?]
      end
    end
  end

  test "entering a map says its name and drops the list, building none until the first J" do
    with_target_list do |loc, _evs|
      loc.step(1)
      count_rebuilds do |n|
        $game_map.map_id = 35
        SpeakCapture.clear
        loc.announce_map_change
        entered = [SpeakCapture.log.dup, n[0], loc.target]
        loc.step(1)
        assert_equal [[["Mapa 35", false]], 0, nil, 1, 3], entered + [n[0], loc.target.id]
      end
    end
  end

  test "a teleport within the map keeps the selection, the list rebuilt once where it is next read" do
    with_target_list do |loc, evs|
      PokeAccess::Config.target_numbering = :off
      loc.step(1)
      selected = loc.target
      loc.announce_internal_teleport
      $game_player.x = 6
      $game_player.y = 3
      loc.announce_internal_teleport
      rebuilds = count_rebuilds do |n|
        loc.ensure_target
        once = n[0]
        loc.ensure_target
        [once, n[0]]
      end
      assert_same selected, loc.target, "the selection kept"
      assert_equal [[1, 1], [[1, 4], [2, 4], [3, 4], [4, 4]]],
                   [rebuilds, [:c, :a, :b, :d].map { |k| loc.number_of(evs[k]) }],
                   "rebuilt at the next read and not at the one after, ordered from where the player now stands"
    end
  end

  test "keeps a selection still on the map without rebuilding the list" do
    with_target_list do |loc, _evs|
      loc.step(1)
      selected = loc.target
      rebuilds = count_rebuilds { |n| loc.ensure_target; n[0] }
      assert_equal [0, true], [rebuilds, loc.target.equal?(selected)]
    end
  end

  test "a selection gone is replaced by the target now at its place, or by the first past the list's end" do
    { [2, [2]] => 3, [3, [3, 4]] => 1, [4, [3, 4]] => 1, [1, [1, 2, 3, 4]] => nil }.each do |(selected, gone), want|
      with_target_list do |loc, _evs|
        PokeAccess::Config.target_order = :fixed
        press_to(loc, selected)
        gone.each { |id| $game_map.events.delete(id) }
        World.next_frame
        loc.ensure_target
        got = loc.target && loc.target.id
        want.nil? ? assert_nil(got, "all gone") : assert_equal(want, got, "#{selected} selected, #{gone.inspect} gone")
      end
    end
  end

  test "a wide doorway keeps one identity whichever of its tiles stands for it" do
    loc = PokeAccess::Locator
    $game_map.load_grid(["##########", "#@.......#", "#........#", "##########"])
    doorway
    loc.instance_variable_set(:@cat_id, :exits)
    loc.step(1)
    near_left = [loc.target.id, loc.identity(loc.target)]
    $game_player.x = 8
    loc.rebuild_targets
    assert_equal [[7, [:event, 5]], 5, [:event, 5]], [near_left, loc.target.id, loc.identity(loc.target)],
                 "the left tile stands for it from the left, the right one from the right, one identity throughout"
  ensure
    loc.instance_variable_set(:@cat_id, :all)
  end

  test "keeps apart exits side by side that land in different places" do
    loc = PokeAccess::Locator
    { "another map" => [[0, 5, 4, 4], [0, 6, 4, 4]],
      "far apart on one map" => [[0, 5, 4, 4], [0, 5, 9, 4]] }.each do |what, (a, b)|
      $game_map.load_grid(["##########", "#@.......#", "#........#", "##########"])
      left = World.touch(:id => 7, :x => 6, :y => 2, :list => [TestCmd.new(201, a)])
      right = World.touch(:id => 5, :x => 7, :y => 2, :list => [TestCmd.new(201, b)])
      loc.instance_variable_set(:@cat_id, :exits)
      PokeAccess::Config.target_numbering = :off
      loc.rebuild_targets
      assert_equal [[1, 2], [2, 2]], [loc.number_of(left), loc.number_of(right)], "landing on #{what}"
    end
  ensure
    loc.instance_variable_set(:@cat_id, :all)
  end

  test "a wide doorway that loses a tile is known by the tile left" do
    loc = PokeAccess::Locator
    $game_map.load_grid(["##########", "#@.......#", "#........#", "##########"])
    doorway
    loc.instance_variable_set(:@cat_id, :exits)
    loc.step(1)
    $game_map.events.delete(5)
    World.next_frame
    loc.step(1)
    assert_equal [7, [:event, 7]], [loc.target.id, loc.identity(loc.target)]
  ensure
    loc.instance_variable_set(:@cat_id, :all)
  end

  test "lists, with hide_noninteractive, only the targets the player can do something with" do
    with_target_list(WALLED, {}) do |loc, _evs|
      talker = TestGameEvent.new(:id => 6, :x => 3, :y => 1,
                                 :pages => [TestPage.new(:sprite => "npc", :list => [TestCmd.new(101, ["Hola"])])])
      $game_map.events[6] = talker
      mute = World.event(:id => 7, :x => 5, :y => 1)
      PokeAccess::Config.target_numbering = :off
      { false => [[1, 2], [2, 2]], true => [[1, 1], nil] }.each do |hide, want|
        PokeAccess::Config.hide_noninteractive = hide
        loc.rebuild_targets
        assert_equal want, [loc.number_of(talker), loc.number_of(mute)], "hide_noninteractive #{hide}"
      end
    end
  end

  test "keeps an event's page verdict until the verdicts are dropped" do
    loc = PokeAccess::Locator
    page, ball = item_ball
    first = loc.item_ball?(ball)
    page.list.shift
    kept = loc.item_ball?(ball)
    loc.clear_verdicts
    assert_equal [true, true, false], [first, kept, loc.item_ball?(ball)],
                 "an item ball, kept so while its pages are not read again, read afresh once dropped"
  end

  test "reads an event's pages afresh once its live page changes" do
    loc = PokeAccess::Locator
    page, ball = item_ball
    first = loc.item_ball?(ball)
    page.list.shift
    ball.instance_variable_set(:@list, [TestCmd.new(0, [])])
    assert_equal [true, false], [first, loc.item_ball?(ball)]
  end

  private

  # Runs the block on rows with the people placed ({ name => [id, x, y] }), shown in the people category in the near
  # order; the block gets the locator and the events by name, the category put back after.
  def with_target_list(rows = WALLED, people = PEOPLE)
    PokeAccess::Config.target_order = :near
    loc = PokeAccess::Locator
    $game_map.load_grid(rows)
    evs = {}
    people.each { |k, (id, x, y)| evs[k] = World.event(:id => id, :x => x, :y => y) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    loc.clear_targets
    loc.instance_variable_set(:@cat_id, :people)
    yield loc, evs
  ensure
    loc.clear_targets
    loc.instance_variable_set(:@cat_id, :all)
  end

  # The ids of the targets J selects, press after press, once round a list of n.
  def pressed_order(loc, n = 4)
    (1..n).map { loc.step(1); loc.target.id }
  end

  # Presses J until the target with id is selected, once round the list at most.
  def press_to(loc, id)
    PEOPLE.length.times do
      loc.step(1)
      return if loc.target && loc.target.id == id
    end
  end

  # True when the last line said starts with line, said before the target.
  def said_first?(line)
    SpeakCapture.lines.last.to_s.start_with?("#{line}. ")
  end

  # Runs the block counting the locator's rebuilds of its list, yielding the count as a one-element array.
  def count_rebuilds
    n = [0]
    real = PokeAccess::Locator.method(:rebuild_targets)
    PokeAccess::Locator.define_singleton_method(:rebuild_targets) { n[0] += 1; real.call }
    yield n
  ensure
    PokeAccess::Locator.define_singleton_method(:rebuild_targets, real)
  end

  # A doorway two tiles wide, at (6, 2) (event 7) and (7, 2) (event 5), to two spots side by side of map 5.
  def doorway
    World.touch(:id => 7, :x => 6, :y => 2, :list => [TestCmd.new(201, [0, 5, 4, 4])])
    World.touch(:id => 5, :x => 7, :y => 2, :list => [TestCmd.new(201, [0, 5, 5, 4])])
  end

  # An item ball event and its page: [page, event].
  def item_ball
    page = TestPage.new(:trigger => 0, :sprite => "Object ball",
                        :list => [TestCmd.new(355, ["pbItemBall(:POTION)"]), TestCmd.new(0, [])])
    [page, TestGameEvent.new(:id => 22, :name => "Item", :pages => [page])]
  end
end

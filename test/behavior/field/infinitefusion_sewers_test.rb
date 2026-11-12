# Celadon Sewers' two dry plank approaches, flooded crossings and water consoles.
# Commands mirror the two identical map corpora inspected in IF 6.8.2 and 6.9.1.
class InfiniteFusionSewersTest < PokeAccessTest
  test "both dry approaches are named step-onto controls with cues, with either assist setting" do
    on_map(431)
    dry_events
    [false, true].each do |assist|
      PokeAccess::Config.puzzle_assist = assist
      targets = PokeAccess::Puzzles.category_targets
      assert_equal [3, 16], targets.map(&:ref).sort
      assert_equal [t(:if_sewers_first_approach), t(:if_sewers_second_approach)], targets.sort_by(&:ref).map(&:name)
      assert targets.all? { |target| PokeAccess::Puzzles.onto?(target) }
      assert_equal :control, PokeAccess::Sound::Scene.family_of($game_map.events[3])
      assert_equal :control, PokeAccess::Sound::Scene.family_of($game_map.events[16])
    end
  end

  test "helper sensors and the overhead plank do not create misleading targets or a chorus of cues" do
    on_map(431)
    dry_events
    assert_equal [3, 16], PokeAccess::Puzzles.category_targets.map(&:ref).sort
    [2, 4, 5, 11, 13, 17].each do |id|
      assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[id]), "helper #{id}"
    end
  end

  test "the first completed approach disappears while the second remains and its saved state is read" do
    on_map(431)
    dry_events
    PokeAccess::Puzzles.tick
    $game_switches[127] = true
    approach(3, 12, 21, 127, true)
    World.next_frame
    targets = PokeAccess::Puzzles.category_targets
    assert_equal [16], targets.map(&:ref)
    assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[3])
    line = PokeAccess::Puzzles.info_line
    assert_kind_of String, line
    assert_includes line, t(:if_sewers_first_plank)
    assert_includes line, t(:if_sewers_lowered)
    $game_switches[129] = true
    approach(16, 20, 31, 129, true)
    World.next_frame
    assert_empty PokeAccess::Puzzles.category_targets
  end

  test "the flooded map uses its own plank event ids and lists completed crossings as exact floor goals" do
    on_map(446)
    $game_switches[130] = true
    static_plank(9, 10, 21)
    static_plank(6, 18, 31)
    static_plank(2, 10, 12)
    targets = PokeAccess::Puzzles.category_targets
    assert_equal [[10, 21], [18, 31]], targets.map { |target| [target.x, target.y] }.sort
    assert_equal [t(:if_sewers_first_plank), t(:if_sewers_second_plank)], targets.sort_by(&:x).map(&:name)
    $game_switches[127] = true
    World.next_frame
    targets = PokeAccess::Puzzles.category_targets
    first = targets.find { |target| target.x == 10 }
    assert_equal t(:if_sewers_first_crossing), first.name
    assert PokeAccess::Puzzles.onto?(first)
    assert_equal t(:if_sewers_second_plank), targets.find { |target| target.x == 18 }.name
    $game_switches[129] = true
    World.next_frame
    second = PokeAccess::Puzzles.category_targets.find { |target| target.x == 18 }
    assert_equal t(:if_sewers_second_crossing), second.name
    assert PokeAccess::Puzzles.onto?(second)
  end

  test "either control room names the water console and distinguishes its actual east and west exits" do
    [447, 448].each do |map|
      on_map(map)
      World.event(:id => 1, :kind => :sign, :x => 9, :y => 5)
      $game_map.events[1].instance_variable_get(:@list).push(TestCmd.new(121, [130, 130, 0]))
      west = World.event(:id => 2, :kind => :door, :x => 3, :y => 5)
      east = World.event(:id => 3, :kind => :door, :x => 15, :y => 5)
      World.next_frame
      assert_equal [1], PokeAccess::Puzzles.category_targets.map(&:ref)
      assert_equal t(:if_sewers_water_control), PokeAccess::Puzzles.piece_name($game_map.events[1])
      assert_equal t(:if_sewers_west_exit), PokeAccess::Puzzles.piece_name(west)
      assert_equal t(:if_sewers_east_exit), PokeAccess::Puzzles.piece_name(east)
      assert_equal :door, PokeAccess::Sound::Scene.family_of(west)
      assert_equal :door, PokeAccess::Sound::Scene.family_of(east)
    end
  end

  test "strategy is optional while the water and plank states remain available" do
    on_map(447)
    World.event(:id => 1, :kind => :sign)
    [false, true].each do |assist|
      PokeAccess::Config.puzzle_assist = assist
      line = PokeAccess::Puzzles.info_line
      assert_kind_of String, line
      [:if_sewers_water_level, :if_sewers_first_plank, :if_sewers_second_plank].each do |key|
        assert_includes line, t(key)
      end
      if assist
        assert_includes line, t(:if_sewers_hint)
      else
        refute_includes line, t(:if_sewers_hint)
      end
    end
  end

  test "navigation and puzzle reads never operate the mechanism or change gameplay state" do
    on_map(431)
    dry_events
    PokeAccess::Config.puzzle_assist = true
    before = Marshal.dump([$game_switches, $game_variables, $game_player.x, $game_player.y, $game_player.direction])
    3.times do
      PokeAccess::Puzzles.category_targets
      PokeAccess::Puzzles.info_line
      PokeAccess::Puzzles.tick
      PokeAccess::Sound::Scene.family_of($game_map.events[3])
    end
    assert_equal before, Marshal.dump([$game_switches, $game_variables, $game_player.x, $game_player.y, $game_player.direction])
  end

  test "unrelated maps and absent mechanism events keep their existing behavior" do
    on_map(99)
    dry_events
    assert_empty PokeAccess::World::Mechanics.instances
    assert_empty PokeAccess::Puzzles.category_targets
    [431, 446].each do |map|
      on_map(map)
      assert_empty PokeAccess::Puzzles.category_targets
    end
  end

  private

  def t(key); PokeAccess::I18n.t(key); end

  def on_map(map)
    Harness.load_puzzles("infinitefusion")
    World.clear_events
    $game_map.map_id = map
    $game_map.width = 45
    $game_map.height = 50
    [127, 128, 129, 130].each { |flag| $game_switches[flag] = false }
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
  end

  def approach(id, x, y, flag, done = false)
    pages = [TestPage.new(:trigger => 1, :list => [TestCmd.new(121, [128, 128, 0]), TestCmd.new(0, [])]),
             TestPage.new(:condition => { :switch1_valid => true, :switch1_id => flag }, :list => [TestCmd.new(0, [])])]
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :active_page => pages[done ? 1 : 0])
    World.next_frame
  end

  def static_plank(id, x, y)
    page = TestPage.new(:list => [TestCmd.new(0, [])], :through => true)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => 414, :pages => [page])
    World.next_frame
  end

  def dry_events
    approach(3, 12, 21, 127)
    approach(16, 20, 31, 129)
    [[4, 12, 20], [5, 12, 22], [11, 12, 18], [17, 21, 31]].each do |id, x, y|
      World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(121, [128, 128, id == 11 || id == 17 ? 1 : 0])])
    end
    [[2, 10, 21, 127], [13, 18, 31, 129]].each do |id, x, y, flag|
      pages = [TestPage.new(:trigger => 2, :list => [TestCmd.new(0, [])]),
               TestPage.new(:trigger => 2, :condition => { :switch1_valid => true, :switch1_id => 128 },
                 :list => [World.move_player([[14, [0, 2]]]), TestCmd.new(121, [flag, flag, 0]), TestCmd.new(121, [128, 128, 1]), TestCmd.new(0, [])])]
      $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :tile_id => 414)
    end
    World.next_frame
  end
end

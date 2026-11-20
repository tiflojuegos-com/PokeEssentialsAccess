# Pokemon Africanvs' optional and side puzzles on the shipped profile (games/africanus/puzzles): the chest on rails of the
# Dionysus Palace, the fires of the Cyclopean Cave, Constantinople's dyes and Utica's arrow plates; what each says with
# no help and what the assist adds.
class AfricanvsPulidoTest < PokeAccessTest
  VARIABLES = [81, 106, 115]

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @player = [$game_player.x, $game_player.y]
  end

  def teardown
    World.clear_events
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @player
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the palace's chest is named, says when it sticks and, with the assist, where to use it from each stretch" do
    assert_includes arrival(64) { place(1, 12, 8, [TestCmd.new(101, ["..."])], "Cofre") }, t(:af_rail_rule)
    assert_equal [[12, 8, t(:af_rail_chest)]], listed
    assert_equal [t(:af_rail_stuck)], frame { $game_variables[81] = 7 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:af_rail_push_up)], frame { $game_variables[81] = 3 }
    assert_includes listed, [28, 7, t(:af_rail_push_here)]
    $game_variables[81] = 8
    refute PokeAccess::Puzzles.active?
    on_map(63)
    tile(13, 17, 16, 1045)
    assert_equal [[17, 16, t(:af_palace_sword)]], listed
  end

  test "the cave's fires are numbered and, with the assist, the one of each step is the right way" do
    on_map(263)
    { 12 => [13, 3], 5 => [5, 12], 1 => [14, 11] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["..."])], "Luz1") }
    $game_variables[106] = 2
    assert_equal [[5, 12, fire(9)], [13, 3, fire(4)], [14, 11, fire(8)]], listed
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[13, 3]], right_ways
    $game_variables[106] = 3
    assert_equal [[5, 12]], right_ways
    assert_includes listed, [14, 11, t(:af_fire_reset, :n => 8)]
    $game_variables[106] = 8
    refute PokeAccess::Puzzles.active?
    assert_includes listed, [14, 11, t(:af_fire_reset, :n => 8)]
    PokeAccess::Config.puzzle_assist = false
    assert_includes listed, [14, 11, fire(8)]
  end

  test "Constantinople's jars say their colour, and the banners are counted with the assist" do
    on_map(277)
    { 50 => [69, 52], 51 => [70, 47], 52 => [70, 45], 53 => [65, 47], 49 => [66, 50] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(101, ["..."])], "000")
    end
    assert_equal [[65, 47, t(:af_dye_green)], [66, 50, t(:af_dye_wash)], [69, 52, t(:af_dye_blue)],
                  [70, 45, t(:af_dye_red)], [70, 47, t(:af_dye_yellow)]], listed
    frame
    assert_empty frame { $game_variables[115] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_progress, :label => t(:af_banners), :n => 2, :of => 4)], frame { $game_variables[115] = 2 }
    $game_variables[115] = 4
    refute PokeAccess::Puzzles.active?
  end

  test "Utica's plates, seen through the amulet alone, are named and kept off with the assist, the arrows out of the lists" do
    on_map(52)
    plate = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(101, ["..."])])
    put_event(TestGameEvent.new(:id => 10, :name => "#EOT SHOW", :x => 37, :y => 35, :tile_id => 1207, :pages => [plate]))
    arrow = TestPage.new(:trigger => 0, :sprite => "000", :list => [TestCmd.new(0, [])])
    put_event(TestGameEvent.new(:id => 9, :name => "flecha1", :x => 33, :y => 35, :pages => [arrow]))
    refute_includes listed, [37, 35, t(:af_arrow_plate)]
    refute PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(37, 35)], "unseen without the assist"
    PokeAccess::Config.set(:puzzle_assist, true)
    World.next_frame
    assert_equal [[37, 35, t(:af_arrow_plate)]], listed
    assert PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(37, 35)]
  ensure
    PokeAccess::Config.set(:puzzle_assist, false)
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # A cave fire's name by its number.
  def fire(n)
    t(:af_fire, :n => n)
  end

  # What the puzzles say on arriving at map, the block placing its events first.
  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  # Puts the player on map with the profile's puzzles declared, nothing placed and the assist off.
  def on_map(map)
    Harness.load_puzzles("africanus")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  # Places an event on the map.
  def put_event(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # An action event with one page of the commands and sprite given.
  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    put_event(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page))
  end

  # An event drawn with a tile and no commands.
  def tile(id, x, y, tile_id)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    put_event(TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => tile_id, :pages => [page]))
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category's tiles as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end

  # The tiles listed as the right way.
  def right_ways
    listed.select { |_x, _y, name| name == t(:puzzle_right_way) }.map { |x, y, _name| [x, y] }
  end
end

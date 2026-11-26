# Pokemon Reminiscencia's puzzles of part 2 (games/reminiscencia/puzzles/): the Ribombee of the Profundidades del Bosque
# Foliodoro, named on the wall below them, where their scene starts, until it has run.
class ReminiscenciaPuzzlesRm2Test < PokeAccessTest
  def setup
    super
    @selfs = $game_self_switches
    @map = $game_map.map_id
    $game_self_switches = {}
  end

  def teardown
    World.clear_events
    $game_self_switches = @selfs
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the wall below the Ribombee is named for them and stands for both until their scene has run" do
    on_map(411)
    wall, bees = clearing
    assert_equal t(:rm2_foliodoro_ribombee), PokeAccess::Locator.target_name(wall)
    assert_equal [[12, 3, t(:rm2_foliodoro_ribombee)]], listed
    bees.each { |b| assert PokeAccess::Locator.hidden?(b), b.name }
    $game_self_switches[[411, 1, "A"]] = true
    PokeAccess::Caches.reset_all
    World.next_frame
    assert_empty listed
    bees.each { |b| refute PokeAccess::Locator.hidden?(b), b.name }
  end

  test "the same events on another map keep the core's names" do
    on_map(412)
    wall, bees = clearing
    refute_equal t(:rm2_foliodoro_ribombee), PokeAccess::Locator.target_name(wall)
    assert_empty listed
    bees.each { |b| refute PokeAccess::Locator.hidden?(b), b.name }
  end

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # Declares the shipped puzzles and puts the player on map with every flag at rest.
  def on_map(map)
    Harness.load_puzzles("reminiscencia")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_self_switches.clear
    World.next_frame
  end

  # The clearing as the map lays it out: the touched wall (event 1, a transfer within the map and a line) and the two drawn
  # Ribombee above it (events 4 and 5), as [wall, [bees]].
  def clearing
    scene = [TestCmd.new(201, [0, 411, 12, 5, 0, 0]), TestCmd.new(101, ["!"])]
    wall = place(1, 12, 3, scene, :trigger => 1, :name => "size(2,1)")
    bees = [place(4, 12, 2, [], :sprite => "Ribombee", :name => "Ribombee1", :through => true),
            place(5, 13, 2, [], :sprite => "Ribombee", :name => "Ribombee2", :through => true)]
    [wall, bees]
  end

  # An event at (x, y) whose live page runs list, placed on the map.
  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list,
                        :through => opts.fetch(:through, false))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The puzzles category as [x, y, name].
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }
  end
end

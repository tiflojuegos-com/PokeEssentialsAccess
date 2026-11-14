# Everything joins ordinary events and the same eligible targets as the dedicated categories.
# Routing and filtering are checked independently from sound playback.
class EverythingTargetsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Target = Loc::SurfaceTarget

  def setup
    super
    @original_map = $game_map
    @original_player = $game_player
  end

  def teardown
    super
  ensure
    $game_map = @original_map
    $game_player = @original_player
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
  end

  test "everything includes puzzles terrain and marks without repeating a stable identity" do
    corridor
    person = World.event(:id => 21, :x => 2, :y => 1, :name => "Person")
    puzzle = Target.new(3, 1, "Plank approach", :puzzle_cell)
    surface = Target.new(4, 1, "Grass", :surf_tallgrass, :surface)
    mark = Target.new(5, 1, "My marker", :mark)
    with_sources([puzzle, puzzle.dup], [surface], [mark]) do
      assert_equal [person, puzzle, surface, mark], Loc.candidates(:all)
      assert_equal [puzzle, puzzle.dup], Loc.candidates(:puzzles)
      assert_equal [surface], Loc.candidates(:surfaces)
      assert_equal [mark], Loc.candidates(:marks)
    end
  end

  test "a named puzzle control replaces its ordinary event but not another target at the same tile" do
    corridor
    event = World.event(:id => 22, :x => 3, :y => 1, :name => "Switch")
    control = Target.new(3, 1, "Water console", :puzzle_control, event.id)
    mark = Target.new(3, 1, "Remember this", :mark)
    with_sources([control], [], [mark]) do
      assert_equal [control, mark], Loc.candidates(:all)
      assert_equal "Water console", Loc.target_name(control)
    end
  end

  test "declared event spots keep their source identity and replace the ordinary event in everything" do
    corridor
    event = World.event(:id => 22, :x => 3, :y => 1, :name => "Plate")
    [true, false].each do |onto|
      spot = PokeAccess::Puzzles.spot_targets([{:event => event.id, :label => "Puzzle plate", :onto => onto}]).first
      assert_equal event.id, spot.ref
      with_sources([spot], [], []) { assert_equal [spot], Loc.candidates(:all) }
    end
  end

  test "moving an event spot preserves its identity and refreshes the ordinary event association" do
    corridor
    event = World.event(:id => 22, :x => 3, :y => 1, :name => "Moving plate")
    spec = [{:event => event.id, :label => "Moving puzzle plate", :onto => true}]
    original = PokeAccess::Puzzles.spot_targets(spec).first
    event.x = 5
    World.next_frame
    moved = PokeAccess::Puzzles.spot_targets(spec).first
    assert_equal [5, 1], [moved.x, moved.y]
    assert_equal Loc.identity(original), Loc.identity(moved)
    with_sources([moved], [], []) { assert_equal [moved], Loc.candidates(:all) }
  end

  test "coordinate spots stay separate even when an event was supplied as a fallback" do
    corridor
    event = World.event(:id => 22, :x => 3, :y => 1, :name => "Independent event")
    [nil, event.id].each do |fallback|
      spot = PokeAccess::Puzzles.spot_targets([{:at => [5, 1], :event => fallback, :label => "Fixed floor", :onto => true}]).first
      assert_nil spot.ref
      with_sources([spot], [], []) { assert_equal [event, spot], Loc.candidates(:all) }
    end
  end

  test "an explicitly hidden event does not return through its puzzle representation" do
    corridor
    event = World.event(:id => 22, :x => 3, :y => 1, :name => "Switch")
    control = Target.new(3, 1, "Water console", :puzzle_control, event.id)
    actual = Loc.method(:tag_hidden?)
    Loc.define_singleton_method(:tag_hidden?) { |ev| ev == event || actual.call(ev) }
    with_sources([control], [], []) { assert_empty Loc.candidates(:all) }
  ensure
    Loc.define_singleton_method(:tag_hidden?, actual) if actual
  end

  test "everything filters unreachable synthetic targets while their own category stays complete" do
    load_grid(["#########", "#@..#...#", "#########"])
    near = Target.new(3, 1, "Near plate", :puzzle_cell)
    far = Target.new(6, 1, "Sealed plate", :puzzle_cell)
    PokeAccess::Config.hide_noninteractive = true
    PokeAccess::Config.hide_unreachable = :unreachable
    with_sources([near, far], [], []) do
      assert_equal [near], listed
      assert_equal [near, far], Loc.filtered(Loc.candidates(:puzzles), :puzzles)
      assert_equal [6, 6], Loc.route_plan(near).route
    end
  end

  test "room filtering covers puzzle terrain and marker targets by their actual route" do
    load_grid(["#############", "#@....#.....#", "#.....#.....#", "#############"])
    World.touch(:id => 90, :x => 4, :y => 2, :list => [TestCmd.new(201, [0, $game_map.map_id, 8, 2])])
    PokeAccess::Pathfinder.invalidate_cache(true)
    local = Target.new(3, 1, "Local plate", :puzzle_cell)
    remote = Target.new(10, 1, "Remote plate", :puzzle_cell)
    grass = Target.new(10, 2, "Remote grass", :surf_tallgrass, :surface)
    mark = Target.new(9, 1, "Remote marker", :mark)
    PokeAccess::Config.hide_unreachable = :room
    with_sources([local, remote], [grass], [mark]) do
      assert_equal [0, 1, 1, 1], [local, remote, grass, mark].map { |t| Loc.room_depth(t) }
      assert_equal [local], listed.select { |t| t.is_a?(Target) }
      assert_equal [local, remote], Loc.filtered(Loc.candidates(:puzzles), :puzzles)
    end
  end

  test "rebuilding everything preserves a puzzle selection by identity and refreshes its position" do
    corridor
    source = [Target.new(3, 1, "Moving puzzle piece", :puzzle_control, 81)]
    with_sources(source, [], []) do
      listed
      Loc.instance_variable_set(:@target, source.first)
      source[0] = Target.new(5, 1, "Moving puzzle piece", :puzzle_control, 81)
      listed
      assert_same source.first, Loc.target
      assert_equal [5, 1], [Loc.target.x, Loc.target.y]
    end
  end

  test "an unavailable puzzle provider does not remove ordinary events terrain or markers" do
    corridor
    person = World.event(:id => 21, :x => 2, :y => 1, :name => "Person")
    grass = Target.new(3, 1, "Grass", :surf_tallgrass, :surface)
    mark = Target.new(4, 1, "Marker", :mark)
    with_sources([], [grass], [mark]) do
      PokeAccess::Puzzles.define_singleton_method(:category_targets) { raise IOError, "unavailable optional puzzle" }
      assert_equal [person, grass, mark], Loc.candidates(:all)
    end
  end

  test "repeated target providers cannot advance regions after the time allowance is spent" do
    load_grid(["#" * 82, "#@" + "." * 79 + "#", "#" * 82])
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    regions = PokeAccess::Routes::Regions.foot
    regions.tiles
    walked = regions.instance_variable_get(:@head)
    10.times { regions.tiles }
    assert_equal false, regions.done?
    assert_equal 8, walked
    assert_equal walked, regions.instance_variable_get(:@head)
  end

  private

  # A simple legal corridor with no terrain or events from another fixture.
  def corridor
    load_grid(["#########", "#@......#", "#########"])
  end

  # Both engine harnesses use the same existing tile-world fixture and original route planner.
  def load_grid(rows)
    $game_map = TileWorld.new(rows)
    $game_player = TileWorldPlayer.new(*$game_map.start)
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
  end

  # The actual rebuilt Everything list; the caller can inspect selection afterwards.
  def listed
    Loc.instance_variable_set(:@cat_id, :all)
    Loc.rebuild_targets
    Loc.instance_variable_get(:@targets)
  end

  # Substitute only the three target providers, restoring them even after a failed assertion.
  def with_sources(puzzles, surfaces, marks)
    bindings = [[PokeAccess::Puzzles, :category_targets, puzzles], [Loc, :surface_targets, surfaces], [Loc, :mark_targets, marks]]
    actual = bindings.map { |owner, name, _list| [owner, name, owner.method(name)] }
    bindings.each { |owner, name, list| owner.define_singleton_method(name) { list } }
    yield
  ensure
    actual.each { |owner, name, method| owner.define_singleton_method(name, method) } if actual
  end
end

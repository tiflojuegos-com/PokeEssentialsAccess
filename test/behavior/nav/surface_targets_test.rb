# The surfaces category (Locator.surface_targets): the nearest tile of each surface on or beside a tile the player can
# get to, however far, not one near behind a wall; named by a game's own rule first; kept while the player stays put.
class SurfaceTargetsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  T = PokeAccess::I18n
  # A corridor with the player at its left end, over a wall row and a sealed room.
  CORRIDOR = ["#" * 42,
              "#@" + ("." * 39) + "#",
              "#" * 42,
              "#" + ("." * 40) + "#",
              "#" * 42]

  test "lists each surface where the player can walk or stand beside, however far, and none in a sealed room" do
    $game_map.load_grid(CORRIDOR)
    $game_map.set_terrain(38, 1, 10)
    $game_map.set_terrain(5, 2, 7)
    $game_map.set_terrain(2, 3, 12)
    assert_equal({ :surf_tallgrass => [38, 1, T.t(:surf_tallgrass)], :surf_water => [5, 2, T.t(:surf_water)] },
                 by_kind(Loc.surface_targets),
                 "grass thirty-seven tiles on, water in the wall beside the corridor, not the ice behind it")
  end

  test "lists afresh on the same tile once an event ends that opened the way to a surface" do
    $game_map.load_grid(["#######", "#@....#", "#######"])
    $game_map.set_terrain(5, 1, 10)
    tree = World.event(:id => 9, :x => 3, :y => 1, :sprite => "Object tree 1")
    tree.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    before = by_kind(Loc.surface_targets).keys
    $game_map.events.delete(9)
    World.next_frame
    Loc.instance_variable_set(:@interp_running, true)
    Loc.refresh_on_event_end
    assert_equal [[], [:surf_tallgrass]], [before, by_kind(Loc.surface_targets).keys]
  end

  test "lists the nearest tile of each surface" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    $game_map.set_terrain(3, 2, 7)
    $game_map.set_terrain(6, 2, 7)
    assert_equal({ :surf_water => [3, 2, T.t(:surf_water)] }, by_kind(Loc.surface_targets))
  end

  test "names a tile by a game's label rule before the standard label" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    $game_map.set_terrain(6, 2, 7)
    rules = PokeAccess::World::Terrain.instance_variable_get(:@label_rules)
    rule = lambda { |x, y| { [3, 1] => :surf_sand, [6, 2] => :surf_puddle }[[x, y]] }
    PokeAccess::World::Terrain.label_rule(&rule)
    assert_equal({ :surf_sand => [3, 1, T.t(:surf_sand)], :surf_puddle => [6, 2, T.t(:surf_puddle)] },
                 by_kind(Loc.surface_targets), "the floor it names and the water it names otherwise")
  ensure
    rules.delete(rule) if rules
  end

  test "a surface a game's rule names stays selected by its kind as the player walks: J goes on, a rebuild follows it" do
    $game_map.load_grid(["##############",
                         "#@...........#",
                         "##############"])
    $game_map.set_terrain(11, 2, 10)
    rules = PokeAccess::World::Terrain.instance_variable_get(:@label_rules)
    rule = lambda { |x, y| [[4, 2], [8, 2]].include?([x, y]) ? :ins_surf_sludge : nil }
    PokeAccess::World::Terrain.label_rule(&rule)
    Loc.instance_variable_set(:@cat_id, :surfaces)
    Loc.step(-1)
    first = [Loc.target.key, Loc.target.x]
    $game_player.x = 8
    Loc.rebuild_targets
    followed = [Loc.target.x, !Loc.number_of(Loc.target).nil?]
    Loc.step(-1)
    assert_equal [[:ins_surf_sludge, 4], [8, true], :surf_tallgrass], [first, followed, Loc.target.key],
                 "the sludge, followed to its nearest tile, then the grass"
  ensure
    rules.delete(rule) if rules
    Loc.instance_variable_set(:@cat_id, :all)
  end

  test "keeps the list while the player stands on the same tile, and finds it afresh from another" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    $game_map.set_terrain(6, 2, 7)
    first = Loc.surface_targets
    again = Loc.surface_targets
    $game_player.x = 2
    moved = Loc.surface_targets
    assert_equal [true, false, { :surf_water => [6, 2, T.t(:surf_water)] }],
                 [first.equal?(again), moved.equal?(first), by_kind(moved)]
  end

  test "offers the surfaces as the targets of their category" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    $game_map.set_terrain(6, 2, 7)
    Loc.instance_variable_set(:@cat_id, :surfaces)
    Loc.step(1)
    assert_equal [6, 2, T.t(:surf_water), :surf_water], Loc.target.to_a.first(4)
  ensure
    Loc.instance_variable_set(:@cat_id, :all)
  end

  test "with the order by walking distance, offers each surface at its tile the fewest presses away on foot" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "#######.##",
                         "#.......##",
                         "##########"])
    $game_map.set_terrain(1, 4, 7)
    $game_map.set_terrain(9, 1, 7)
    PokeAccess::Config.target_order = :near
    near = by_kind(Loc.surface_targets)[:surf_water][0, 2]
    PokeAccess::Config.target_order = :walk
    walk = by_kind(Loc.surface_targets)[:surf_water][0, 2]
    assert_equal [[1, 4], [9, 1]], [near, walk], "three tiles straight below, round the wall; eight along the corridor"
  end

  test "names a surface in the language chosen now, though its list was made in another" do
    $game_map.load_grid(["##########", "#@.......#", "##########"])
    $game_map.set_terrain(6, 2, 7)
    PokeAccess::Config.language = :es
    es = [Loc.target_name(Loc.surface_targets[0]), T.t(:surf_water)]
    PokeAccess::Config.set(:language, :en)
    en = [Loc.target_name(Loc.surface_targets[0]), T.t(:surf_water)]
    assert_equal [es[1], en[1], true], [es[0], en[0], es[1] != en[1]]
  end

  test "lists nothing on a map with no surface of note" do
    $game_map.load_grid(["#####", "#@..#", "#####"])
    assert_equal [], Loc.surface_targets
  end

  private

  # The targets as { surface kind => [x, y, name] }.
  def by_kind(targets)
    out = {}
    targets.each { |t| out[t.key] = [t.x, t.y, t.name] }
    out
  end
end

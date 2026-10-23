# Rooms of one map joined by transfers to itself (Rejuvenation's houses): the locator counts, orders, keeps and notes
# targets by the rooms away they lie, and the way found under a budget, or standing in for a search it cut, counts them.
class OtherRoomTest < PokeAccessTest
  Locator = PokeAccess::Locator
  # Three rooms in a row, the player in A at (7, 1): A holds Ana (id 96) and the pad at (4, 2) to B (id 90); B holds
  # Berto (id 92) and the pad at (11, 1) to C (id 93); C holds Carla (id 91). The ids put Carla first in fixed order.
  ROWS = ["###################",
          "#......@#...#.....#",
          "#.......#...#.....#",
          "###################"].freeze

  test "while hiding, each target lies as many rooms away as the fewest transfers to it" do
    targets = rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [0, 1, 2], targets.map { |t| Locator.room_depth(t) }
  end

  test "while hiding, a map edge lies its rooms away too, and a surface none" do
    rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    edge = Locator::SurfaceTarget.new(15, 1, "salida a Ruta 7", nil, 7)
    water = Locator::SurfaceTarget.new(15, 1, "agua", :surf_water)
    assert_equal 2, Locator.room_depth(edge), "an edge"
    assert_nil Locator.room_depth(water), "a surface"
  end

  test "while hiding, no target is counted in rooms while the regions are still walking" do
    targets = rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1000
    assert_equal [nil, nil, nil], targets.map { |t| Locator.room_depth(t) }
    assert_equal false, PokeAccess::Routes::Regions.foot.done?, "the regions' walk being cut short"
  end

  test "while hiding, no room is counted on a map whose transfers cannot be read" do
    targets = rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    failing_warp_map { assert_equal [nil, nil, nil], targets.map { |t| Locator.room_depth(t) } }
  end

  test "with hiding off no room is counted" do
    targets = rooms_world
    assert_equal [nil, nil, nil], targets.map { |t| Locator.room_depth(t) }
  end

  test "on a map without transfers no target is counted in rooms, while hiding too" do
    targets = rooms_world
    $game_map.events.delete(90)
    $game_map.events.delete(93)
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [nil, nil, nil], targets.map { |t| Locator.room_depth(t) }
  end

  test "while hiding, the list has the player's room first, then each room by how far away, nearest first in each" do
    rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    { :near => [90, 96, 92, 93, 91], :walk => [90, 96, 92, 93, 91] }.each do |order, want|
      PokeAccess::Config.target_order = order
      assert_equal want, listed_ids, "in the #{order} order"
    end
  end

  test "the fixed order keeps the ids' order while rooms are told apart" do
    rooms_world
    PokeAccess::Config.hide_unreachable = :unreachable
    PokeAccess::Config.target_order = :fixed
    assert_equal [90, 91, 92, 93, 96], listed_ids
  end

  test "with hiding off the nearest come first whatever their room" do
    rooms_world
    PokeAccess::Config.target_order = :near
    assert_equal [92, 90, 93, 96, 91], listed_ids
  end

  test "at :room only the player's own room is listed, its transfer pad included" do
    rooms_world
    PokeAccess::Config.hide_unreachable = :room
    assert_equal [90, 96], listed_ids
  end

  test "while hiding, a target in the next room is said to be in another room, right after its name" do
    berto = rooms_world[1]
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [["Berto, #{one_room_away}, #{nth(3)}, #{along(2, :dir_right)}, #{steps(5)}", true]], said(berto)
  end

  test "while hiding, a target two rooms away is said with how many rooms away it lies" do
    carla = rooms_world[2]
    PokeAccess::Config.hide_unreachable = :unreachable
    two_rooms = PokeAccess::I18n.t(:loc_rooms_away, :n => 2)
    assert_equal [["Carla, #{two_rooms}, #{nth(2)}, #{along(9, :dir_right)}, #{steps(8)}", true]], said(carla)
  end

  test "while hiding, a target in the player's own room is said with no note" do
    ana = rooms_world[0]
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [["Ana, #{nth(5)}, #{along(6, :dir_left)}, #{along(1, :dir_down)}, #{steps(6)}", true]], said(ana)
  end

  test "with hiding off the note comes from the route said, without the regions walked for it" do
    berto = rooms_world[1]
    PokeAccess::Config.target_order = :near
    assert_equal [["Berto, #{one_room_away}, #{nth(3)}, #{along(2, :dir_right)}, #{steps(5)}", true]], said(berto),
                 "through one pad"
    assert_equal false, PokeAccess::Routes::Regions.foot.done?, "the regions not walked"
  end

  test "with hiding off a target in the player's own room is said with no note" do
    ana = rooms_world[0]
    assert_equal [["Ana, #{nth(5)}, #{along(6, :dir_left)}, #{along(1, :dir_down)}, #{steps(6)}", true]], said(ana)
  end

  test "Brief leaves the room note out, Medium and Full say it" do
    berto = rooms_world[1]
    assert_equal [false, true, true], vb_levels { said(berto)[0][0].include?(one_room_away) }
  end

  test "past the node budget, the way that stands in for the search counts the rooms it crosses" do
    [:regions, :astar].each do |algo|
      rooms_world
      PokeAccess::Config.path_algorithm = algo
      PokeAccess::Config.astar_max = 1
      assert_equal [2, 1], [rooms_crossed(16, 1), rooms_crossed(9, 1)], "#{algo}: to Carla, to Berto"
    end
  end

  test "under a time budget the way to another room counts the rooms it crosses" do
    [:regions, :astar].each do |algo|
      rooms_world
      PokeAccess::Config.path_algorithm = algo
      PokeAccess::Config.route_limit = :time
      PokeAccess::Config.route_budget_ms = 10_000
      assert_equal [2, 1], [rooms_crossed(16, 1), rooms_crossed(9, 1)], "#{algo}: to Carla, to Berto"
    end
  end

  test "partway up a side stair nothing stands in for a search past the node budget, which is cut" do
    [:regions, :astar].each do |algo|
      rooms_world
      PokeAccess::Config.path_algorithm = algo
      PokeAccess::Config.astar_max = 1
      on_side_stair do
        r = PokeAccess::Routes::Planner.walk(16, 1)
        assert_equal [:cut, nil], [r.status, r.route], "#{algo}: to Carla"
      end
    end
  end

  test "the flood that stands in for the search is kept for the bridge level it was made on" do
    rooms_world
    PokeAccess::Config.path_algorithm = :astar
    PokeAccess::Config.astar_max = 1
    cost = PokeAccess::Routes::CostModel.new(:shortest)
    mode = PokeAccess::Routes::Moves::LEDGE
    assert_equal 1, rooms_crossed(9, 1), "the flood's way to Berto"
    refute_nil PokeAccess::Routes::Flood.kept(cost, mode), "the flood kept"
    $PokemonGlobal.bridge = 2
    assert_nil PokeAccess::Routes::Flood.kept(cost, mode), "none kept for the bridge's level"
  end

  private

  # Loads the three rooms with their pads and targets, the route caches dropped; returns [Ana, Berto, Carla].
  def rooms_world
    $game_map.load_grid(ROWS.map { |r| r.dup })
    World.touch(:id => 90, :x => 4, :y => 2, :list => [TestCmd.new(201, [0, $game_map.map_id, 10, 2])])
    World.touch(:id => 93, :x => 11, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 14, 2])])
    targets = [World.event(:name => "Ana", :id => 96, :x => 1, :y => 2),
               World.event(:name => "Berto", :id => 92, :x => 9, :y => 1),
               World.event(:name => "Carla", :id => 91, :x => 16, :y => 1)]
    PokeAccess::Pathfinder.invalidate_cache(true)
    targets
  end

  # The ids of the targets the locator lists under :all, rebuilt now; the category shown put back after.
  def listed_ids
    was = Locator.instance_variable_get(:@cat_id)
    Locator.instance_variable_set(:@cat_id, :all)
    Locator.rebuild_targets
    Locator.instance_variable_get(:@targets).map { |t| t.id }
  ensure
    Locator.instance_variable_set(:@cat_id, was)
  end

  # What is said of target t selected in the list under :all, as J says it: [[line, whether it interrupts]].
  def said(t)
    listed_ids
    Locator.instance_variable_set(:@target, t)
    SpeakCapture.clear
    Locator.announce_selected(true)
    SpeakCapture.log
  end

  # The transfers the route on foot to act on (x, y) goes through, or :no_route.
  def rooms_crossed(x, y)
    route = walk_route(x, y)
    route ? route.rooms : :no_route
  end

  # Runs the block with Routes::Effects.warp_map? raising, as on a map whose transfers cannot be read; the real one put
  # back after.
  def failing_warp_map
    effects = PokeAccess::Routes::Effects
    real = effects.method(:warp_map?)
    effects.define_singleton_method(:warp_map?) { |*_a| raise IOError, "the transfers cannot be read" }
    yield
  ensure
    effects.define_singleton_method(:warp_map?, real)
  end

  # Runs the block with the player partway up a side stair, where the engine answers every step from the stair; off it
  # after.
  def on_side_stair
    def $game_player.on_middle_of_stair?; true; end
    World.next_frame
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :on_middle_of_stair?)
    World.next_frame
  end

  # The note on a target one room away.
  def one_room_away
    PokeAccess::I18n.t(:loc_other_room)
  end

  # A target's number n among the five listed.
  def nth(n)
    PokeAccess::I18n.t(:loc_count, :n => n, :total => 5)
  end

  # n tiles toward the direction named by key, as the locator gives where a target lies.
  def along(n, key)
    "#{n} #{PokeAccess::I18n.t(key)}"
  end

  # The walk of n presses to a target.
  def steps(n)
    PokeAccess::I18n.t(:loc_steps, :n => n)
  end
end

# Platforms that carry the player between two stops as they run by themselves (Routes::Rides, Reborn's Charous Hall):
# a parallel page that tests the player's tile and moves them with Through on is a ride from that stop, the stops open
# air but for the platform resting there.
class RidesTest < PokeAccessTest
  Rides = PokeAccess::Routes::Rides
  # Two floors joined by a shaft of air: the bottom stop on (3, 4), the top one on (3, 2).
  SHAFT = ["#######",
           "#.....#",
           "#######",
           "#######",
           "#######",
           "#..@..#",
           "#######"]

  test "rides a platform from the stop it leaves from to the other one" do
    on_shaft([3, 4]) do
      route = walk_route(1, 1, true)
      refute_nil route, "the top floor is reached by the platform"
      assert_includes moved(traced(3, 5, 0, route)), [3, 2, :carry], "stepping onto the bottom stop rides to the top one"
    end
  end

  test "waits on the stop the platform leaves from rather than stepping off and back on" do
    on_shaft([3, 4]) do
      $game_player.x, $game_player.y = 3, 4
      assert Rides.waiting?(walk_route(1, 1, true)), "the platform sets out with the player on it"
      refute Rides.waiting?(walk_route(5, 5, true)), "a way that leaves the stop for good steps off"
      $game_player.x, $game_player.y = 3, 5
      refute Rides.waiting?(walk_route(1, 1, true)), "off the stop there is nothing to wait for"
    end
    on_shaft([3, 4], {}, true, 2) do
      $game_player.x, $game_player.y = 3, 4
      route = walk_route(1, 1, true)
      refute_nil route, "the ride its other pages make is still taken"
      refute Rides.waiting?(route), "a platform resting on a page that sets off no one is not waited for"
    end
  end

  test "boards a stop while its platform rests at the other one" do
    on_shaft([3, 2]) do
      refute_nil walk_route(1, 1, true), "the platform comes back for the player"
    end
  end

  test "reads both ways of a platform, each from its stop" do
    on_shaft([3, 4]) do |lift|
      assert_equal [[3, 4, 3, 2], [3, 2, 3, 4]], Rides.rides_of(lift)
    end
  end

  test "takes no ride from a page a story switch shows" do
    on_shaft([3, 4], { :switch1_valid => true, :switch1_id => 40 }, true, 2) do |lift|
      assert_equal [[3, 2, 3, 4]], Rides.rides_of(lift), "the way down, which the platform's variable shows, is kept"
      assert_nil walk_route(1, 1, true), "a switch no machine of the map sets may never show the page up"
    end
  end

  test "takes a page that moves the player without Through on for no ride" do
    on_shaft([3, 4], {}, false) do |lift|
      assert_equal [], Rides.rides_of(lift)
    end
  end

  private

  # The shaft with its platform (event 30) resting on stop, run by variable 60: its first page (shown with cond) takes
  # the player up from the bottom stop, its second, shown with the variable at 1 or more, down from the top one, and
  # its third, a touch page, rests; live is the page shown now. The grid's air holds whoever stands on a drawn event
  # that stops no one there.
  def on_shaft(stop, cond = {}, through = true, live = 0)
    $game_map.load_grid(SHAFT)
    up = TestPage.new(:trigger => 4, :list => ride_list([3, 4], 4, 0, through, 2), :condition => cond)
    down = TestPage.new(:trigger => 4, :list => ride_list([3, 2], 1, 0, through, 0),
                        :condition => { :variable_valid => true, :variable_id => 60, :variable_value => 1 })
    rest = TestPage.new(:trigger => 1, :condition => { :variable_valid => true, :variable_id => 60, :variable_value => 3 })
    pages = [up, down, rest]
    lift = TestGameEvent.new(:id => 30, :x => stop[0], :y => stop[1], :tile_id => 384, :pages => pages,
                             :active_page => pages[live])
    $game_map.events[30] = lift
    World.next_frame
    def $game_map.blocked?(x, y)
      return false if @events.values.any? { |e| e.tile_id.to_i > 0 && !e.through && e.x == x && e.y == y }
      super
    end
    yield lift
  ensure
    $game_map.singleton_class.send(:remove_method, :blocked?) if $game_map.singleton_methods.include?(:blocked?)
  end

  # A platform page's list: it sets off along step (1 down, 4 up), with the player on from it, and sets the variable to
  # value.
  def ride_list(from, step, indent, through, value)
    codes = through ? [37, step, step, 38] : [step, step]
    [TestCmd.new(209, [0, TestMoveRoute.new([TestMoveCmd.new(step), TestMoveCmd.new(step), TestMoveCmd.new(0)])]),
     TestCmd.new(122, [47, 47, 0, 6, -1, 0]), TestCmd.new(122, [48, 48, 0, 6, -1, 1]),
     TestCmd.new(111, [1, 47, 0, from[0], 0], indent), TestCmd.new(111, [1, 48, 0, from[1], 0], indent + 1),
     World.move_player(codes, indent + 2), TestCmd.new(0, [], indent + 2), World.end_(indent + 1),
     TestCmd.new(0, [], indent + 1), World.end_(indent), TestCmd.new(122, [60, 60, 0, 0, value]), TestCmd.new(0, [])]
  end

  # The traced steps as [x, y, kind].
  def moved(steps)
    steps.map { |s| [s.x, s.y, s.kind] }
  end
end

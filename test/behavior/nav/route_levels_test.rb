# Stairs between two floors drawn on one map (Routes::Effects.level_switches, Reborn's Lower Level): a touch page that
# turns a switch on and moves the player carries them as if it set nothing, once another turns that switch off; and
# pushes a page sends further from some tiles (Effects.tile_pushes, Reborn's Crustles tumbling down a slope).
class RouteLevelsTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  # The upper floor on the right, the lower one on the left, walled apart: the stair down on (3, 1), the stair up on
  # (3, 3), each a dead end but for the step it carries.
  FLOORS = ["#######",
            "###...#",
            "#..#..#",
            "#...#.#",
            "#######"]
  # A pushable on (2, 2) above a ledge (2, 3) it tumbles over to (2, 4) when pushed down from where it stands.
  SLOPE = ["#####",
           "#...#",
           "#...#",
           "#####",
           "#...#",
           "#####"]

  test "stairs that turn a level switch on one way and off the other carry the player between the floors" do
    floors(true) do
      refute_nil walk_route(1, 3, true), "down the stair on (3, 1)"
      assert_equal [410], Effects.level_switches.keys
    end
  end

  test "a stair that turns on a switch no other one turns off carries no one" do
    floors(false) do
      assert_nil walk_route(1, 3, true)
      assert_equal({}, Effects.level_switches)
    end
  end

  test "a toggle whose own pages the switch it sets turns over is no level" do
    floors(false) do
      on = TestPage.new(:trigger => 1, :list => [TestCmd.new(121, [410, 410, 0]), World.move_player([3]), TestCmd.new(0, [])])
      off = TestPage.new(:trigger => 1, :condition => { :switch1_valid => true, :switch1_id => 410 },
                         :list => [TestCmd.new(121, [410, 410, 1]), World.move_player([2]), TestCmd.new(0, [])])
      $game_map.events[42] = TestGameEvent.new(:id => 42, :x => 5, :y => 3, :pages => [on, off])
      World.next_frame
      assert_equal({}, Effects.level_switches)
    end
  end

  test "a push its page sends further from a tile, by where the piece stands, tumbles it there" do
    slope do |rock|
      assert_equal({ [2, 2, 2] => [0, 2] }, Effects.tile_pushes(rock))
      PokeAccess::Config.puzzle_assist = true
      plan = PokeAccess::Routes::Planner.carry(rock, [2, 4, 2, 4])
      assert_equal [:assisted, [2, 2]], [plan.kind, [plan.gate[:x], plan.gate[:y]]]
      assert_equal [], plan.route.to_a, "pushed down from where the player stands"
    end
  end

  private

  # The floors with the player on (5, 1); with up, the stair back up turns the switch off.
  def floors(up)
    $game_map.load_grid(FLOORS)
    $game_player.x = 5
    $game_player.y = 1
    stair(40, 3, 1, 4, 0, 5)
    stair(41, 3, 3, 6, 1, 8) if up
    yield
  end

  # A stair on (x, y): stepped on facing d, it sets switch 410 to value (0 on, 1 off) and moves the player one tile
  # diagonally (move code).
  def stair(id, x, y, d, value, code)
    World.touch(:id => id, :x => x, :y => y,
                :list => [World.if_facing(d), TestCmd.new(121, [410, 410, value], 1), World.move_player([code], 1),
                          TestCmd.new(0, [], 1), World.end_])
  end

  # The slope with the player on (2, 1) and the pushable (event 50) below them.
  def slope
    $game_map.load_grid(SLOPE)
    $game_player.x = 2
    $game_player.y = 1
    drop = TestMoveRoute.new([TestMoveCmd.new(37), TestMoveCmd.new(1), TestMoveCmd.new(1), TestMoveCmd.new(38),
                              TestMoveCmd.new(0)])
    list = [TestCmd.new(122, [47, 47, 0, 6, 0, 0]), TestCmd.new(122, [48, 48, 0, 6, 0, 1]),
            TestCmd.new(111, [1, 47, 0, 2, 0], 0), TestCmd.new(111, [1, 48, 0, 2, 0], 1), World.if_facing(2, 2),
            TestCmd.new(209, [0, drop], 3), TestCmd.new(0, [], 3), World.end_(2), TestCmd.new(0, [], 2), World.end_(1),
            TestCmd.new(0, [], 1), World.end_(0), TestCmd.new(355, ["pbPushThisObject"]), TestCmd.new(0, [])]
    rock = TestGameEvent.new(:id => 50, :x => 2, :y => 2, :name => "Rock",
                             :pages => [TestPage.new(:trigger => 0, :sprite => "rock", :list => list)])
    rock.blocking = true
    def rock.passableStrict?(x, y, d)
      !$game_map.blocked?(x + (d == 6 ? 1 : (d == 4 ? -1 : 0)), y + (d == 2 ? 1 : (d == 8 ? -1 : 0)))
    end
    $game_map.events[50] = rock
    World.next_frame
    yield rock
  ensure
    PokeAccess::Config.puzzle_assist = false
  end
end

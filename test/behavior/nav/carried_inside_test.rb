# A puzzle's goal whose tracked piece is already inside its box, the phase still open (the game has not yet set the
# switch that closes it): the route key says the piece's own line (puzzle_track_in), not that the player is beside it,
# and the guides end with that line rather than with the arrival. On the way there, pushing the piece on the same way,
# the guide says how to push it once.

class CarriedInsideTest < PokeAccessTest
  test "says the piece is in its goal for the route to it" do
    with_piece(6) do |loc, goal|
      loc.instance_variable_set(:@target, goal)
      loc.instance_variable_set(:@targets_stale, false)
      SpeakCapture.clear
      loc.announce_route
      assert_equal [inside_line], SpeakCapture.lines
    end
  end

  test "ends the guide with the piece's line, not with the arrival" do
    with_piece(6) do |loc, goal|
      with_guide_state do
        steps_aim(loc, goal)
        SpeakCapture.clear
        guide_frame
        assert_equal [inside_line], SpeakCapture.lines
      end
    end
  end

  test "the guide's end keeps quiet when the piece's own line has just said it is in its goal" do
    with_piece(6) do |loc, goal|
      with_guide_state do
        steps_aim(loc, goal)
        PokeAccess::Puzzles.say_track(inside_line)
        SpeakCapture.clear
        guide_frame
        assert_equal [[], false], [SpeakCapture.lines, PokeAccess::Guide.on?(:steps)]
      end
    end
  end

  test "pushing the piece on the same way, the guide says how to push it once, the piece's line telling the rest" do
    with_piece(3) do |loc, goal, piece|
      with_guide_state do
        steps_aim(loc, goal)
        walk_to(loc, 1, 1)
        first = walk_to(loc, 2, 1)
        pushes = [[4, 3], [5, 4]].map { |px, x| piece.x = px; walk_to(loc, x, 1) }
        assert_equal [1, true, [[], []]], [first.length, first[0].to_s.include?(PokeAccess::I18n.t(:toward_right)), pushes]
      end
    end
  end

  test "after a leg said between them, the guide says how to push the piece again" do
    with_piece(3) do |loc, goal, piece|
      with_guide_state do
        steps_aim(loc, goal)
        walk_to(loc, 2, 1)
        piece.x = 4
        walk_to(loc, 2, 2)
        walk_to(loc, 2, 1)
        assert_equal 1, walk_to(loc, 3, 1).length
      end
    end
  end

  test "with the cane alone, walking on along the row to the piece rather than pushing it, the guide says the push again" do
    with_piece(3) do |loc, goal, piece|
      with_guide_state do
        guide_aim(loc, goal)
        walk_to(loc, 1, 1)
        first = walk_to(loc, 2, 1)
        piece.x = 5
        walk_to(loc, 3, 1)
        assert_equal [1, first], [first.length, walk_to(loc, 4, 1)]
      end
    end
  end

  private

  # The piece's line once it is inside its goal.
  def inside_line
    PokeAccess::I18n.t(:puzzle_track_in, :label => "Pikachu", :goal => "Meta")
  end

  # The Pikachu on (x, y), touched: solid, stepped one tile the way the player faces where the tile beyond is open.
  def pikachu(id, x, y)
    list = []
    [[2, 1], [4, 2], [6, 3], [8, 4]].each do |d, code|
      list.push(TestCmd.new(111, [6, -1, d], 0))
      list.push(TestCmd.new(209, [0, TestMoveRoute.new([TestMoveCmd.new(code), TestMoveCmd.new(0)])], 1))
      list.push(TestCmd.new(0, [], 1))
      list.push(TestCmd.new(412, [], 0))
    end
    ev = World.touch(:id => id, :name => "pikachu", :x => x, :y => y, :trigger => 1, :sprite => "025", :list => list)
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      return true if through
      !$game_map.blocked?(x + (d == 6 ? 1 : (d == 4 ? -1 : 0)), y + (d == 2 ? 1 : (d == 8 ? -1 : 0)))
    end
    ev
  end

  # Runs the block on a room whose phase tracks the Pikachu on (x, 1) into its goal (6..7, 1..2), with the assist on,
  # yielding the locator, the goal's target and the piece.
  def with_piece(x)
    mech = PokeAccess::World::Mechanics
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@target)
    $game_map.load_grid(["#########",
                         "#@......#",
                         "#.......#",
                         "#########"])
    piece = pikachu(16, x, 1)
    mech.declare($game_map.map_id, :kind => :state,
                 :phases => [{ :when => lambda { true },
                               :track => { :event => 16, :label => "Pikachu", :goal => [6, 1, 7, 2],
                                           :goal_label => "Meta" } }])
    mech.forget
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    goal = PokeAccess::Puzzles.category_targets.find { |x| x.respond_to?(:key) && x.key == :puzzle_goal }
    yield loc, goal, piece
  ensure
    loc.instance_variable_set(:@target, saved)
    PokeAccess::Config.puzzle_assist = false
    mech.instance_variable_set(:@defs, {})
    mech.forget
    World.clear_events
    $game_map.clear_grid
  end
end

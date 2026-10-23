# A touch event that carries the player on only with the arrow held (core/nav/held_carry.rb), shaped as Insurgence's
# diagonal stairs that fire on arrival: reached with the key let go, how to take it is said once the player has stood
# still there a moment; carried on, or arriving another way or on a carry that needs no key, nothing is.
class HeldCarryTest < PokeAccessTest
  # Facing left with the left button held: a diagonal step down and left, Through on.
  STAIR = [World.if_facing(4), TestCmd.new(111, [11, 4], 1), World.move_player([37, 5, 38], 2), World.end_(1),
           World.end_]

  test "standing still on a stair the held key would have carried on from says the key to hold, once" do
    on_map(STAIR) do
      arrive(4, 1, 4)
      idle(PokeAccess::HeldCarry::WAIT)
      idle(PokeAccess::HeldCarry::WAIT)
      assert_equal [[hint, false]], SpeakCapture.log
    end
  end

  test "nothing is said before the player has stood there a moment" do
    on_map(STAIR) do
      arrive(4, 1, 4)
      idle(PokeAccess::HeldCarry::WAIT - 2)
      assert_nothing_spoken
    end
  end

  test "carried on, or arriving facing a way the stair does not carry, says nothing" do
    on_map(STAIR) do
      arrive(4, 1, 4)
      arrive(3, 2, 4)
      idle(PokeAccess::HeldCarry::WAIT)
      arrive(4, 1, 2)
      idle(PokeAccess::HeldCarry::WAIT)
      assert_nothing_spoken
    end
  end

  test "a carry that needs no key held says nothing" do
    on_map([World.if_facing(4), World.move_player([37, 5, 38], 1), World.end_]) do
      arrive(4, 1, 4)
      idle(PokeAccess::HeldCarry::WAIT)
      assert_nothing_spoken
    end
  end

  test "coming back to the stair with the key let go again says the key again" do
    on_map(STAIR) do
      arrive(4, 1, 4)
      idle(PokeAccess::HeldCarry::WAIT + 1)
      arrive(5, 1, 6)
      arrive(4, 1, 4)
      idle(PokeAccess::HeldCarry::WAIT + 1)
      assert_equal [hint, hint], SpeakCapture.lines
    end
  end

  test "the route guide asks for the key held on a stair that fires on arrival, not on one that fires on a bump" do
    on_map(STAIR) do
      World.touch(:id => 2, :x => 6, :y => 0, :list => STAIR)
      assert_equal [true, false], [PokeAccess::Routes::Moves.held?(4, 1), PokeAccess::Routes::Moves.held?(6, 0)]
    end
  end

  test "the frames of a step still moving onto the stair do not count, so a slow step carried on says nothing" do
    on_map(STAIR) do
      mid_step do
        arrive(4, 1, 4)
        idle(PokeAccess::HeldCarry::WAIT + 4)
      end
      idle(1)
      arrive(3, 2, 4)
      idle(PokeAccess::HeldCarry::WAIT + 1)
      assert_nothing_spoken
    end
  end

  private

  # The line that says to hold the left arrow.
  def hint
    PokeAccess::I18n.t(:nav_hold_key, :key => PokeAccess::I18n.t(:key_arrow_left))
  end

  # Runs the block on an open strip with the stair event at (4, 1), cleared after.
  def on_map(list)
    $game_map.load_grid(["#########", "#.......#", "#.......#", "#########"])
    World.touch(:id => 1, :x => 4, :y => 1, :list => list)
    PokeAccess::HeldCarry.reset
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  # The player at (x, y) facing dir, one frame after arriving.
  def arrive(x, y, dir)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
    PokeAccess::HeldCarry.tick
  end

  # Runs the block with the player partway through a step, as the engine has them from the frame x and y change.
  def mid_step
    $game_player.define_singleton_method(:moving?) { true }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :moving?)
  end

  # n more frames, the player standing still unless the caller has them mid-step.
  def idle(n)
    n.times do
      PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial.to_i + 1)
      PokeAccess::HeldCarry.tick
    end
  end
end

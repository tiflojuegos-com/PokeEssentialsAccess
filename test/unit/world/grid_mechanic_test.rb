# The floor grid (Pokemon Z's runes): a cell's state is read once the step onto it has ended and the game's touch event
# has toggled it, a cell crossed without stopping is said with its new state, and the cells a new letter resets are
# left unsaid so the letter is heard whole, as are those the game resets after the win.

class GridMechanicTest < PokeAccessTest
  CELLS = [[1, 1], [2, 1], [3, 1]].freeze

  test "reads a cell once the step onto it has ended and its touch event has run" do
    lit = [false, false, false]
    grid(lit) do |frame|
      assert_equal [[:tone, 0]], frame.call(1, 1, true)
      assert_equal [], frame.call(1, 1, true)
      assert_equal [], frame.call(1, 1, false)
      lit[0] = true

      assert_equal [[:cell, 0, true]], frame.call(1, 1, false)
    end
  end

  test "waits while the game's event is still running" do
    lit = [false, false, false]
    grid(lit) do |frame|
      frame.call(1, 1, true)
      frame.call(1, 1, false, true)
      frame.call(1, 1, false, true)
      lit[0] = true

      assert_equal [], frame.call(1, 1, false)
      assert_equal [[:cell, 0, true]], frame.call(1, 1, false)
    end
  end

  test "says the new state of a cell crossed without stopping" do
    lit = [false, false, false]
    grid(lit) do |frame|
      frame.call(1, 1, true)
      frame.call(1, 1, false)
      lit[0] = true

      assert_equal [[:tone, 1], [:cell, 0, true]], frame.call(2, 1, true)
    end
  end

  test "leaves unsaid the cells a new letter resets" do
    lit = [true, false, false]
    target = { :name => "X", :pattern => [true, false, false] }
    grid(lit, lambda { target }) do |frame|
      frame.call(1, 1, true)
      3.times { frame.call(1, 1, false) }
      target = { :name => "Y", :pattern => [false, true, false] }
      lit[0] = false

      assert_equal [[:target, target, true]], frame.call(1, 1, false)
      assert_equal [], frame.call(1, 1, false)
    end
  end

  test "leaves unsaid the cells the game resets after the win" do
    lit = [false, false, true]
    won = false
    grid(lit, lambda { nil }, lambda { won }) do |frame|
      frame.call(3, 1, true)
      3.times { frame.call(3, 1, false) }
      won = true
      assert_equal [[:solved, :puzzle_solved]], frame.call(3, 1, false)
      lit[2] = false

      assert_equal [], frame.call(3, 1, false, true)
    end
  end

  private

  # Runs the block on a three-cell grid lit as lit says, its letter given by target and its win by solved, with a
  # frame lambda: put the player on (x, y), moving or not, the game's event running or not, and get what the grid
  # said. The player's and the interpreter's own answers are put back after.
  def grid(lit, target = lambda { nil }, solved = lambda { false })
    b = PokeAccess::World::Mechanics::Builder.new(:grid)
    b.cells(3, CELLS.map { |c| c.dup })
    b.lit { |i| lit[i] }
    b.active { true }
    b.solved { solved.call }
    b.target { target.call }
    type = PokeAccess::World::Mechanics::Grid
    inst = PokeAccess::World::Mechanics::Instance.new(b.spec, :grid, type, 999, {}, [], [], nil)
    type.enter(inst)
    state = { :moving => false, :running => false }
    $game_player.define_singleton_method(:moving?) { state[:moving] }
    interp = $game_system.map_interpreter
    idle = interp.method(:running?)
    interp.define_singleton_method(:running?) { state[:running] }
    yield(lambda do |x, y, moving, running = false|
      $game_player.x = x
      $game_player.y = y
      state[:moving] = moving
      state[:running] = running
      out = []
      type.update(inst, out)
      out
    end)
  ensure
    class << $game_player; remove_method :moving?; end
    interp.define_singleton_method(:running?, idle) if idle
  end
end

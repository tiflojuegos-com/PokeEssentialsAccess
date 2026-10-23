# SceneWatcher.wire on a game screen: the reader holds the screen while the screen's own loop runs, each frame's poll
# sees it, and it is let go when the loop returns or raises; the loop's value and its exception still reach the game.

# A game screen with a blocking loop: main ticks the frame pollers once, as the engine's Input.update does, and
# returns; crash ticks them and raises mid-frame.
class SwWireLoopScene_pa
  def main
    PokeAccess::Frame.run_pollers
    :loop_done
  end

  def crash
    PokeAccess::Frame.run_pollers
    raise "fangame screen blew up"
  end
end

class SceneWatcherWireTest < PokeAccessTest
  # What wire asks of a reader, recorded: the scene it holds, watch and unwatch in order, and the scene each poll saw.
  class Watcher
    attr_reader :scene, :calls, :polled

    def initialize; clear; end

    def clear
      @scene = nil
      @calls = []
      @polled = []
    end

    def watch(s)
      @scene = s
      @calls.push(:watch)
    end

    def unwatch
      @scene = nil
      @calls.push(:unwatch)
    end

    def poll; @polled.push(@scene); end
  end

  WATCHER = Watcher.new
  PokeAccess::SceneWatcher.wire("SwWireLoopScene_pa", :main, WATCHER)
  PokeAccess::SceneWatcher.wire("SwWireLoopScene_pa", :crash, WATCHER)

  def setup
    super
    WATCHER.clear
  end

  test "outside the screen's loop a frame's poll sees no screen" do
    PokeAccess::Frame.run_pollers
    assert_equal [nil], WATCHER.polled.uniq
  end

  test "holds the screen while its loop runs, each frame's poll seeing it" do
    scene = SwWireLoopScene_pa.new
    scene.main
    assert_equal [scene], WATCHER.polled.uniq
  end

  test "the loop's own value reaches the game" do
    assert_equal :loop_done, SwWireLoopScene_pa.new.main
  end

  test "lets the screen go when its loop returns, after one watch and one unwatch" do
    SwWireLoopScene_pa.new.main
    assert_equal [:watch, :unwatch], WATCHER.calls
    assert_nil WATCHER.scene
  end

  test "holds each screen in its turn" do
    SwWireLoopScene_pa.new.main
    WATCHER.clear
    other = SwWireLoopScene_pa.new
    other.main
    assert_equal [other], WATCHER.polled.uniq
  end

  test "the loop's exception reaches the game" do
    error = assert_raises(RuntimeError) { SwWireLoopScene_pa.new.crash }
    assert_equal "fangame screen blew up", error.message
  end

  test "lets the screen go when its loop raises, having held it while the loop ran" do
    scene = SwWireLoopScene_pa.new
    crash(scene)
    assert_equal [scene], WATCHER.polled.uniq, "held while the loop ran"
    assert_equal [:watch, :unwatch], WATCHER.calls
    assert_nil WATCHER.scene
  end

  test "after a loop that raised, the next loop holds and lets go as before" do
    scene = SwWireLoopScene_pa.new
    crash(scene)
    WATCHER.clear
    scene.main
    assert_equal [scene], WATCHER.polled.uniq, "held while the loop ran"
    assert_equal [:watch, :unwatch], WATCHER.calls
    assert_nil WATCHER.scene
  end

  private

  # Runs the screen's raising loop, the game's exception swallowed here.
  def crash(scene)
    scene.crash
  rescue RuntimeError
    nil
  end
end

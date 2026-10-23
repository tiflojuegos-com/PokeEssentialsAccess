# Soulstones' quick save (games/soulstones1/quicksave.rb): Q on the map saves with pbSave and starts a disk animation
# with no message, so the save's result is said as the animation starts.

# Only the profile's module is evaluated: its hooks on Scene_Map#update and pbSave belong to the Soulstones process.
quicksave_path = File.join(Harness::ROOT, "games", "soulstones1", "quicksave.rb")
eval(Harness.source(quicksave_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, quicksave_path)

class Soulstones1QuicksaveTest < PokeAccessTest
  QuickSave = PokeAccess::Soulstones1QuickSave

  test "says the save as the update that made it starts the animation, interrupting" do
    map_update(nil, 0) { QuickSave.saved(true) }
    assert_equal [[PokeAccess::I18n.t(:ss1_quicksaved), true]], SpeakCapture.log
  end

  test "says a save pbSave reports failed as failed" do
    map_update(nil, 0) { QuickSave.saved(false) }
    assert_equal [[PokeAccess::I18n.t(:ss1_quicksave_failed), true]], SpeakCapture.log
  end

  test "says nothing for a map update that saves nothing" do
    map_update(nil, nil) {}
    assert_nothing_spoken
  end

  test "says nothing on the animation's later frames" do
    map_update(0, 1) {}
    assert_nothing_spoken
  end

  test "says nothing for a save that starts no animation, as the pause menu's" do
    map_update(nil, nil) { QuickSave.saved(true) }
    assert_nothing_spoken
  end

  test "starts each update without the answer of the one before" do
    map_update(nil, 0) { QuickSave.saved(false) }
    SpeakCapture.clear
    map_update(nil, 0) {}
    assert_equal [[PokeAccess::I18n.t(:ss1_quicksaved), true]], SpeakCapture.log
  end

  private

  # One watched map update, the block running inside it: the disk animation's @mode as the update begins and as it
  # returns (nil while idle).
  def map_update(before, after)
    scene = World.stub_scene(:@mode => before)
    QuickSave.arm(scene)
    yield
    scene.instance_variable_set(:@mode, after)
    QuickSave.check(scene)
  end
end

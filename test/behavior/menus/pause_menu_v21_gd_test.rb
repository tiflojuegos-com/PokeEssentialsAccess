# The stock pause menu's command window (core/menus/v21/pausemenu_v21.rb), gamedata pass, its loop in the game's order
# (the window updates, then the frame pulses): one read per thing that happened, and nothing left unsaid.
class PauseMenuV21GdTest < PokeAccessTest
  ROWS = ["Bag", "Save", "Options"].freeze

  def teardown
    PokeAccess::PauseMenuV21.unwatch
    super
  end

  test "the row the menu opens on is said once, queued" do
    show(scene, [0, 0, 0])
    assert_equal [["Bag", false]], SpeakCapture.log
  end

  test "the menu opens on the row it was left on" do
    show(scene, [2, 2])
    assert_equal [["Options", false]], SpeakCapture.log
  end

  test "each move is said once, cutting in, and a frame with no move says nothing" do
    show(scene, [0, 0, 1, 1, 1, 0, 2])
    assert_equal [["Bag", false], ["Save", true], ["Bag", true], ["Options", true]], SpeakCapture.log
  end

  test "back from a submenu the loop runs again on the same window, and its row is said again, queued" do
    s = scene
    show(s, [1])
    SpeakCapture.clear
    show(s, [1, 1])
    assert_equal [["Save", false]], SpeakCapture.log
  end

  test "a new menu on a new window says its row again" do
    show(scene, [0])
    SpeakCapture.clear
    show(scene, [0])
    assert_equal [["Bag", false]], SpeakCapture.log
  end

  test "a row whose text lands late is said when it does, the frames before it silent" do
    win = Window_DrawableCommand.new([])
    s = scene(win)
    show(s, [0, 0])
    assert_nothing_spoken
    win.commands = ROWS.dup
    show(s, [0])
    assert_equal [["Bag", false]], SpeakCapture.log
  end

  test "the info box comes first and the row behind it, each once" do
    s = scene
    s.pbShowInfo("Balls: 12")
    show(s, [0, 0])
    assert_equal [["Balls: 12", false], ["Bag", false]], SpeakCapture.log
  end

  test "a menu with no such window says nothing and keeps running" do
    assert_equal 0, show(PokemonPauseMenu_Scene.new, [0, 0])
    assert_nothing_spoken
    assert_equal 0, show(scene(nil), [0, 0])
    assert_nothing_spoken
  end

  test "any other window stays the generic reader's, while the menu is open or after" do
    s = scene
    show(s, [0])
    SpeakCapture.clear
    Window_DrawableCommand.new(["Yes", "No"]).update
    assert_equal [["Yes", false]], SpeakCapture.log
    SpeakCapture.clear
    other = Window_DrawableCommand.new(["Yes", "No"])
    other.update
    other.index = 1
    other.update
    assert_equal [["Yes", false], ["No", true]], SpeakCapture.log
  end

  test "the claim holds only on the window the menu shows" do
    win = Window_DrawableCommand.new(ROWS.dup)
    assert_equal false, PokeAccess.dedicated?(win)
    show(scene(win), [])
    assert_equal true, PokeAccess.dedicated?(win)
  end

  private

  # A pause scene showing a window over ROWS, or the one given (nil for none).
  def scene(win = :rows)
    s = PokemonPauseMenu_Scene.new
    s.pbStartScene
    s.instance_variable_set(:@sprites, { "cmdwindow" => win == :rows ? Window_DrawableCommand.new(ROWS.dup) : win })
    s
  end

  # Runs the scene's command loop for a frame on each row.
  def show(s, frames)
    s.instance_variable_set(:@frames, frames)
    s.pbShowCommands(ROWS)
  end
end

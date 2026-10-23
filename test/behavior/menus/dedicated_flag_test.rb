# Which windows the two generic readers, the command-window hook and the auto-detect net, leave alone: one a dedicated
# reader claims (the mod's @access_dedicated, never the engine's @ignore_input), one the engine froze, an inactive one
# and one with no row focused; any other is read, its first row queued and each move after it interrupting.
class DedicatedFlagTest < PokeAccessTest
  # A selectable window that is not a command window, its options in @items, as the auto-detect net finds them.
  class ItemsWindow < SpriteWindow_Selectable
    def initialize(items); super(); @items = items; end
  end

  # How each case leaves a window the generic readers would otherwise read, and the rows its cursor then visits.
  SILENCED = {
    "claimed by a dedicated reader" => [lambda { |w| PokeAccess.dedicate(w) }, [0, 1]],
    "frozen by the engine" => [lambda { |w| w.instance_variable_set(:@ignore_input, true) }, [0, 1]],
    "inactive" => [lambda { |w| w.active = false }, [0, 1]],
    "with no row focused" => [lambda { |_w| }, [-1, -1]]
  }

  test "the command reader says a window's first row queued, then each move interrupting" do
    visit(Window_DrawableCommand.new(["Placaje", "Ataque Rapido"]), [0, 1])
    assert_equal [["Placaje", false], ["Ataque Rapido", true]], SpeakCapture.log
  end

  test "the command reader leaves a claimed, frozen, inactive or unfocused window silent as its cursor moves" do
    SILENCED.each do |why, (silence, rows)|
      win = Window_DrawableCommand.new(["Placaje", "Ataque Rapido"])
      silence.call(win)
      visit(win, rows)
      assert_equal [], SpeakCapture.log, why
    end
  end

  test "the auto-detect net says a selectable's first row queued, then each move interrupting" do
    PokeAccess::Config.auto_detect = true
    visit(ItemsWindow.new(["Uno", "Dos"]), [0, 1])
    assert_equal [["Uno", false], ["Dos", true]], SpeakCapture.log
  end

  test "the auto-detect net leaves a claimed, frozen, inactive or unfocused selectable silent" do
    PokeAccess::Config.auto_detect = true
    SILENCED.each do |why, (silence, rows)|
      win = ItemsWindow.new(["Uno", "Dos"])
      silence.call(win)
      visit(win, rows)
      assert_equal [], SpeakCapture.log, why
    end
  end

  test "claiming a window marks it dedicated and leaves the engine's freeze flag unset" do
    win = Window_DrawableCommand.new(["Placaje"])
    assert_same win, PokeAccess.dedicate(win)
    assert_equal true, PokeAccess.dedicated?(win)
    assert_nil win.instance_variable_get(:@ignore_input), "the engine would freeze the cursor of a window it set"
  end

  test "claiming a missing window is harmless, and a window nobody claimed is not dedicated" do
    assert_nil PokeAccess.dedicate(nil)
    assert_equal false, PokeAccess.dedicated?(nil)
    assert_equal false, PokeAccess.dedicated?(Window_DrawableCommand.new(["Placaje"]))
  end

  private

  # Moves win's cursor to each row in turn, updating it as the game does every frame.
  def visit(win, rows)
    rows.each do |i|
      win.index = i
      win.update
    end
  end
end

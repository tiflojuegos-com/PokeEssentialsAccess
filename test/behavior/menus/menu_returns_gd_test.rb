# The options screen's rows (core/menus/options.rb), each row past the options as painted, and the change of the
# focused row's value; back on it from a submenu, on the load screen from the options, or on the Pokegear from an app,
# the focused row is said again.

# An RMXP-style Pokegear (Uranium's kind): every frame of its loop reselects its buttons, and its apps open in place,
# inside that loop.
class Scene_Pokegear
  def initialize(names); @buttons = names.map { |n| PokegearButton.new(n) }; @index = 0; end
  def update; @buttons.each_with_index { |b, i| b.selected = (i == @index) }; end
end

# Sevii's options list: two rows past the options, Set Controls and then the exit row.
class SeviiOptionsWindow < Window_PokemonOption
  def drawItem(index, count, rect)
    @exit_word = index == @options.length ? "Set Controls" : "Cancel"
    super
  end
  def refresh; (@options.length + 2).times { |i| drawItem(i, @options.length + 2, nil) }; end
end

class MenuReturnsGdTest < PokeAccessTest
  test "the last row says the word the screen paints there" do
    win = options([ButtonOption.new("System & Audio")], "Confirm")
    win.refresh
    assert_equal "Confirm", focused(win, 1)
  end

  test "a submenu row says its name alone" do
    assert_equal "System & Audio", focused(options([ButtonOption.new("System & Audio")]), 0)
  end

  test "a valued row keeps its value" do
    win = options([ButtonOption.new("System & Audio"), EnumOption.new("Text Speed", ["Slow", "Fast"])])
    win[1] = 1
    assert_equal "Text Speed: Fast", focused(win, 1)
  end

  test "each row past the options says the word painted there, as Sevii paints Set Controls before Cancel" do
    win = SeviiOptionsWindow.new([EnumOption.new("Text Speed", ["Slow", "Fast"])])
    win.refresh
    assert_equal ["Set Controls", "Cancel"], [focused(win, 1), focused(win, 2)]
  end

  test "back on the load screen from the options, its focused command is said again, queued" do
    win = Window_CommandPokemon.new(["Continue", "New Game", "Options"])
    win.index = 2
    win.update
    SpeakCapture.clear
    PokemonOption_Scene.new.pbEndScene
    win.update
    win.update
    assert_equal [["Options", false]], SpeakCapture.log
  end

  test "an unpainted last row answers nothing twice, so the reader asks again, then the mod's own word" do
    win = options([])
    assert_equal [nil, nil, PokeAccess::I18n.t(:sm_exit), PokeAccess::I18n.t(:sm_exit)], Array.new(4) { focused(win, 0) }
  end

  test "a change of the focused row's value says the new value alone, interrupting" do
    win = valued_options
    win.update
    SpeakCapture.clear
    win[0] = 1
    win.update
    assert_equal [["Fast", true]], SpeakCapture.log
  end

  test "a valued row updated without a change says nothing more" do
    win = valued_options
    win.update
    SpeakCapture.clear
    win.update
    assert_nothing_spoken
  end

  test "a move to another valued row says that row, not a change of value" do
    win = valued_options
    win.update
    SpeakCapture.clear
    win.index = 1
    win.update
    assert_equal [["Frame: Uno", true]], SpeakCapture.log
  end

  test "a value changed while the window is not active is not said" do
    win = valued_options
    win.update
    SpeakCapture.clear
    win.active = false
    win[0] = 1
    win.update
    assert_nothing_spoken
  end

  test "back from a submenu the focused row is said again, once, queued as on opening" do
    win = options([ButtonOption.new("System & Audio"), ButtonOption.new("Gameplay")])
    win.update
    assert_equal [["System & Audio", false]], SpeakCapture.log, "the opening row"
    SpeakCapture.clear
    win.update
    assert_nothing_spoken "silent while nothing moves"
    PokemonOption_Scene.new.pbEndScene
    win.update
    win.update
    assert_equal [["System & Audio", false]], SpeakCapture.log, "the submenu closed: the row once more"
    SpeakCapture.clear
    win.update
    assert_nothing_spoken "and not on the frames after"
  end

  test "back from an app the Pokegear says the focused option again" do
    gear = PokemonPokegear_Scene.new(["Map", "Phone"])
    gear.pbStartScene
    gear.pbScene
    assert_equal [["Map", true]], SpeakCapture.log, "the opening and its first loop say the option once"
    SpeakCapture.clear
    gear.pbScene
    assert_equal [["Map", true]], SpeakCapture.log, "the loop entered again after an app says it again"
  end

  test "back on an RMXP-style Pokegear from an app opened in place, the focused option is said again" do
    gear = Scene_Pokegear.new(["Map", "Phone"])
    with_scene(gear) do
      gear.update
      SpeakCapture.clear
      app_returns
      gear.update
    end
    assert_equal [["Map", true]], SpeakCapture.log
  end

  test "a return while the running scene is not the Pokegear leaves its option unsaid" do
    gear = Scene_Pokegear.new(["Map", "Phone"])
    gear.update
    SpeakCapture.clear
    with_scene(Object.new) { app_returns }
    gear.update
    assert_nothing_spoken
  end

  private

  # Runs the block with scene as the running $scene, the one before it put back after.
  def with_scene(scene)
    was = $scene
    $scene = scene
    yield
  ensure
    $scene = was
  end

  # An app's screen closing back to its caller, no other subscreen open: the outermost return seam fires its
  # listeners. The return nesting is put at rest before and after.
  def app_returns
    PokeAccess::MenuReturn.reset_nesting
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  ensure
    PokeAccess::MenuReturn.reset_nesting
  end

  # An options window over rows, its last row painting exit_word.
  def options(rows, exit_word = "Close")
    Window_PokemonOption.new(rows, exit_word)
  end

  # An options window over two valued rows, Text Speed (Slow or Fast) and Frame (Uno or Dos), on the first.
  def valued_options
    options([EnumOption.new("Text Speed", ["Slow", "Fast"]), EnumOption.new("Frame", ["Uno", "Dos"])])
  end

  # What the reader says for the row at index.
  def focused(win, index)
    win.index = index
    PokeAccess::Menus.focused_text(win)
  end
end

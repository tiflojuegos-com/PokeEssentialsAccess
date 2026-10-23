# FL's Set the Controls (plugins/fl_set_controls.rb) over the gen-6 stand-ins of its window and scene: each row as
# painted, a key just bound and the rows it was taken from, the Default row's reset, and the text box in pbMain.
class FlSetControlsTest < PokeAccessTest
  Control = Struct.new(:controlAction, :keyName)

  # A text box with the text reader the poll reads, as the game's message window has.
  TextBox = Struct.new(:text)

  # A row of Insurgence's copy: its key as a code, painted "None" at 0; binding a key takes it from any other row of
  # its list, as that copy's setNewInput does.
  class CodedControl
    attr_accessor :controlAction, :keyCode

    def initialize(action, code, list)
      @controlAction = action
      @keyCode = code
      @list = list
    end

    def keyName
      keyCode == 0 ? "None" : keyCode.chr
    end

    def keyName=(key)
      code = key.ord
      @list.each { |c| c.keyCode = 0 if !c.equal?(self) && c.keyCode == code }
      @keyCode = code
    end
  end

  test "reads an action's row as the action and its key" do
    win = Window_PokemonControls.new([Control.new("Action", "C"), Control.new("Registered #4", "T")])
    assert_equal row_text("Registered #4", "T"), PokeAccess::FlSetControls.row(win, 1)
  end

  test "reads the two rows past the actions as the Default and Exit captions the game translates" do
    win = Window_PokemonControls.new([Control.new("Action", "C")])
    rows = with_intl("Default" => "Por defecto", "Exit" => "Salir") do
      [PokeAccess::FlSetControls.row(win, 1), PokeAccess::FlSetControls.row(win, 2)]
    end
    assert_equal ["Por defecto", "Salir"], rows
  end

  test "gives the menu reader the focused row" do
    win = Window_PokemonControls.new([Control.new("Action", "C")])
    { 0 => row_text("Action", "C"), 1 => "Default", 2 => "Exit" }.each do |index, text|
      win.index = index
      assert_equal text, PokeAccess::Menus.focused_text(win), "with the cursor on row #{index}"
    end
  end

  test "says a key just bound on its row, interrupting the prompt" do
    win = Window_PokemonControls.new([Control.new("Action", "C")])
    win.setNewInput("V")
    assert_equal [[row_text("Action", "V"), true]], SpeakCapture.log
  end

  test "says the rows a new key was taken from after the row that got it" do
    win = coded_window(["Up", 87], ["Action", 67], ["Menu", 88])
    win.index = 1
    win.setNewInput("W")
    assert_equal [[PokeAccess.sentences([row_text("Action", "W"), row_text("Up", "None")]), true]], SpeakCapture.log
  end

  test "leaves out a row that had no key before the new one was bound" do
    win = coded_window(["Up", 0], ["Action", 67], ["Menu", 88])
    win.index = 1
    win.setNewInput("X")
    assert_equal [PokeAccess.sentences([row_text("Action", "X"), row_text("Menu", "None")])], SpeakCapture.lines
  end

  test "says only the row that got the key when given no codes from before" do
    win = coded_window(["Up", 0], ["Action", 67])
    win.index = 1
    PokeAccess::FlSetControls.rebound(win)
    assert_equal [[row_text("Action", "C"), true]], SpeakCapture.log
  end

  test "says nothing on a frame that changes no key" do
    win = Window_PokemonControls.new([Control.new("Action", "V")])
    win.update
    assert_nothing_spoken
  end

  test "says every key reset, once, when the Default row swaps the whole list" do
    win = Window_PokemonControls.new([Control.new("Action", "V")])
    win.index = 1
    win.defaults = [Control.new("Action", "C")]
    win.update
    win.update
    assert_equal [[PokeAccess::I18n.t(:rmp_all_reset), true]], SpeakCapture.log
  end

  test "takes a key bound on its row for that row, not for a reset" do
    win = Window_PokemonControls.new([Control.new("Action", "V")])
    win.setNewInput("B")
    win.update
    assert_equal [row_text("Action", "B")], SpeakCapture.lines
  end

  test "takes a list the window gets for the first time for no reset" do
    win = Window_PokemonControls.new(nil)
    win.defaults = [Control.new("Action", "C")]
    win.update
    assert_nothing_spoken
  end

  test "says each new line of the text box while pbMain runs, the opening one queued and blanks quiet" do
    box = TextBox.new("View/Change your controls")
    win = Window_PokemonControls.new([Control.new("Action", "C")])
    steps = ["View/Change your controls", "Press a new key.", lambda { win.setNewInput("V") }, "", "",
             "Fill all fields!", "Press a new key."]
    PokemonControlsScene.new(win, box, steps).pbMain
    assert_equal [["View/Change your controls", false], ["Press a new key.", true], [row_text("Action", "V"), true],
                  ["Fill all fields!", true], ["Press a new key.", true]], SpeakCapture.log
  end

  test "says Fill all fields! again on a second refused save, its box emptied and written within one frame" do
    box = TextBox.new("")
    win = Window_PokemonControls.new([Control.new("Action", "C")])
    refuse = lambda do
      Kernel.pbConfirmMessage("Save changes?")
      box.text = ""
      box.text = "Fill all fields!"
    end
    PokemonControlsScene.new(win, box, ["Fill all fields!", refuse]).pbMain
    assert_equal ["Fill all fields!", "Fill all fields!"], SpeakCapture.lines
  end

  test "names each sign of a key painted as signs alone, as the remap names them, and keeps lettered names" do
    keys = [";:", "/?", "'\"", "Num Lock"]
    win = Window_PokemonControls.new(keys.each_with_index.map { |k, i| Control.new("Action #{i}", k) })
    n = lambda { |*syms| syms.map { |s| PokeAccess::I18n.t(s) }.join(", ") }
    want = [n.call(:key_semicolon, :key_colon), n.call(:key_slash, :key_question),
            n.call(:key_apostrophe, :key_quote), "Num Lock"]
    assert_equal want.each_with_index.map { |w, i| row_text("Action #{i}", w) },
                 (0...keys.length).map { |i| PokeAccess::FlSetControls.row(win, i) }
  end

  test "stops reading the text box once pbMain has returned" do
    box = TextBox.new("View/Change your controls")
    PokemonControlsScene.new(Window_PokemonControls.new([]), box, ["View/Change your controls"]).pbMain
    SpeakCapture.clear
    box.text = "Press a new key!"
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  private

  # What a row says: the action and its key.
  def row_text(action, key)
    PokeAccess::I18n.t(:chr_value, :name => action, :value => key)
  end

  # The controls window over Insurgence's coded rows, each given as [action, key code].
  def coded_window(*rows)
    list = []
    rows.each { |action, code| list.push(CodedControl.new(action, code, list)) }
    Window_PokemonControls.new(list)
  end
end

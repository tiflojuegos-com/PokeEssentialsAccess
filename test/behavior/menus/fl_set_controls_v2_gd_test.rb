# FL's Set the Controls as a module (plugins/fl_set_controls_v2.rb) over a stand-in of its window and scene as Decades and
# Hero Legacy ship them: each row as painted, a key just bound and the rows it was taken from, the Default row's reset,
# and the text box in the loop that waits for the keys.
module SetControls
  # A row: an action and the keys it paints.
  class ActionData
    attr_accessor :name, :keys

    def initialize(name, keys)
      @name = name
      @keys = keys
    end

    def keys_text; @keys.join(", "); end
  end

  # The rows, as the window holds them.
  class ActionHandler
    def initialize(rows); @rows = rows; end
    def [](i); @rows[i]; end
    def size; @rows.size; end
  end

  # set_new_input binds the key to the focused row and takes it from any other, which is left with "None";
  # open_action_menu takes the row's last key off when told to, and answers whether it did; choose_control_key runs
  # what the test gives it in place of the game's list.
  class Window_Controls
    attr_accessor :index, :next_handler, :reading, :description, :removing, :listing

    def reading_input?; @reading; end
    def item_description; @description; end
    def controls; @action_handler; end
    def choose_control_key(_index, _message); @listing.call; end

    def open_action_menu
      return false unless @removing
      @action_handler[@index].keys.pop
      true
    end

    def initialize(handler)
      @action_handler = handler
      @index = 0
    end

    def set_new_input(key)
      (0...@action_handler.size).each do |j|
        @action_handler[j].keys = ["None"] if j != @index && @action_handler[j].keys.include?(key)
      end
      @action_handler[@index].keys = [key]
      :bound
    end

    def update
      @action_handler = @next_handler if @next_handler
      :updated
    end
  end

  # main is the loop that waits for the keys, one frame per line its text box shows; a lambda among them is what happens
  # between two frames.
  class Scene
    TextBox = Struct.new(:text)

    def initialize(lines, window = nil)
      @lines = lines
      @sprites = { "textbox" => TextBox.new(""), "controlwindow" => window }
    end

    def main
      @lines.each do |line|
        next line.call if line.respond_to?(:call)
        @sprites["textbox"].text = line
        PokeAccess::Frame.run_pollers
      end
    end
  end
end

begin
  path = File.join(Harness::ROOT, "plugins", "fl_set_controls_v2.rb")
  src = Harness.source(path)
  hooks = src.index('PokeAccess::Hooks.around_hook("SetControls::Window_Controls"')
  eval(src[hooks..-1], TOPLEVEL_BINDING, path, src[0, hooks].count("\n") + 1)
end

class FlSetControlsV2GdTest < PokeAccessTest
  Reader = PokeAccess::FlSetControlsV2

  test "reads an action's row as the action and its keys" do
    assert_equal row_text("Action", "C, Enter"), Reader.row(window, 0)
  end

  test "reads the two rows past the actions as the Default and Exit captions the game translates" do
    rows = with_intl("Default" => "Por defecto", "Exit" => "Salir") { [Reader.row(window, 2), Reader.row(window, 3)] }
    assert_equal ["Por defecto", "Salir"], rows
  end

  test "the window is read through its extractor" do
    win = window
    win.index = 1
    assert_equal row_text("Cancel", "X"), PokeAccess::Menus.focused_text(win)
  end

  test "says a key named by signs sign by sign, and any other name as painted" do
    semicolon = PokeAccess::ConfigMenu.char_name(0x3B)
    colon = PokeAccess::ConfigMenu.char_name(0x3A)
    assert_equal "#{semicolon}, #{colon}, F1", Reader.key_words(";:, F1")
    assert_equal "キャンセル", Reader.key_words("キャンセル"), "a word in another alphabet"
  end

  test "reads a row's key named by signs sign by sign" do
    rows = SetControls::ActionHandler.new([SetControls::ActionData.new("Action", ["."])])
    dot = PokeAccess::ConfigMenu.char_name(0x2E)
    assert_equal row_text("Action", dot), Reader.row(SetControls::Window_Controls.new(rows), 0)
  end

  test "a key just bound says the row, cutting in, and each row it was taken from, and the game gets its value" do
    win = window
    assert_equal :bound, win.set_new_input("X")
    assert_equal [["#{row_text('Action', 'X')}. #{row_text('Cancel', 'None')}", true]], SpeakCapture.log
  end

  test "a key taken from the first row says that row too" do
    win = window
    win.index = 1
    win.set_new_input("C")
    assert_equal [["#{row_text('Cancel', 'C')}. #{row_text('Action', 'None')}", true]], SpeakCapture.log
  end

  test "a key no other row had says only the row" do
    win = window
    win.set_new_input("Q")
    assert_equal [[row_text("Action", "Q"), true]], SpeakCapture.log
  end

  test "Default says every key went back, once, and an update with the same list says nothing" do
    win = window
    assert_equal :updated, win.update
    assert_nothing_spoken
    win.next_handler = handler
    win.update
    assert_equal [[PokeAccess::I18n.t(:rmp_all_reset), true]], SpeakCapture.log
  end

  test "Remove key says the row, and the menu's other answers say nothing; the game gets its value" do
    win = window
    assert_equal false, win.open_action_menu
    assert_nothing_spoken
    win.removing = true
    assert_equal true, win.open_action_menu
    assert_equal [[row_text("Action", "C"), true]], SpeakCapture.log
  end

  test "the text box says each new line once, and a blank one nothing" do
    SetControls::Scene.new(["Moves the character.", "Moves the character.", "", "Press a new key."]).main
    assert_equal ["Moves the character.", "Press a new key."], SpeakCapture.lines
  end

  test "the box's line after a key waits behind the row that key has just said" do
    win = window
    win.description = "Confirms."
    SetControls::Scene.new(["Press a new key.", lambda { win.set_new_input("Q") }, "Confirms."], win).main
    assert_equal [["Press a new key.", false], [row_text("Action", "Q"), true], ["Confirms.", false]], SpeakCapture.log
  end

  test "a second try at saving says the refusal again, as it writes its line over itself" do
    win = window
    win.description = "Confirms."
    SetControls::Scene.new(["Fill all fields!", lambda { win.controls }, "Fill all fields!"], win).main
    assert_equal ["Fill all fields!", "Fill all fields!"], SpeakCapture.lines
  end

  test "a try at saving does not say the description again, and a refusal the game leaves there is said once" do
    win = window
    win.description = "Confirms."
    SetControls::Scene.new(["Confirms.", lambda { win.controls }, "Confirms."], win).main
    assert_equal ["Confirms."], SpeakCapture.lines
    SpeakCapture.clear
    SetControls::Scene.new(["Fill all fields!", "Fill all fields!"], win).main
    assert_equal ["Fill all fields!"], SpeakCapture.lines
  end

  test "the list of a row's keys says a key named by signs as the row does, and only that list" do
    win = window
    dot = PokeAccess::ConfigMenu.char_name(0x2E)
    said = nil
    win.listing = lambda { said = [".", "C", "Cancel"].map { |t| PokeAccess::Menus.unknown_row(t) }; 1 }
    assert_equal 1, win.choose_control_key(0, "Choose an assigned key.")
    assert_equal [dot, "C", "Cancel"], said
    assert_equal ".", PokeAccess::Menus.unknown_row("."), "past the list, a row is as any other"
  end

  test "the mod's keys give way while the game waits for a key, and only then" do
    win = window
    SetControls::Scene.new(["Confirms."], win).main
    refute PokeAccess::Keys.typing?
    win.reading = true
    SetControls::Scene.new(["Press a new key."], win).main
    assert PokeAccess::Keys.typing?
  end

  private

  def row_text(name, value)
    PokeAccess::I18n.t(:chr_value, :name => name, :value => value)
  end

  def handler
    SetControls::ActionHandler.new([SetControls::ActionData.new("Action", ["C", "Enter"]),
                                    SetControls::ActionData.new("Cancel", ["X"])])
  end

  def window
    SetControls::Window_Controls.new(handler)
  end
end

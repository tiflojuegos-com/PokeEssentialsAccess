# Focus primitives: UIV21.speak_changed keyed by slot as well as text, NumberEntry's amounts deduped per window and its
# digit columns, the info key letting a closed screen's text go, and a sprite-button menu's focus and nested fades.
class FocusKeyTest < PokeAccessTest
  # A digit-column number window (Window_InputNumberPokemon): the cursor's column, the digit count, the sign slot
  # and the number it shows.
  class DigitWindow
    attr_accessor :number, :sign

    def initialize(number, digits, sign = false)
      @number = number
      @digits_max = digits
      @sign = sign
      @index = 0
      @negative = false
    end

    def index=(i); @index = i; end
    def negative=(v); @negative = v; end
  end

  test "says two entries with the same text when their slots differ" do
    PokeAccess::UIV21.speak_changed(:focus_spec, "Huevo", 1)
    PokeAccess::UIV21.speak_changed(:focus_spec, "Huevo", 2)
    assert_equal [["Huevo", true], ["Huevo", true]], SpeakCapture.log
  end

  test "does not repeat an entry on the same slot" do
    2.times { PokeAccess::UIV21.speak_changed(:focus_spec, "Huevo", 2) }
    assert_equal [["Huevo", true]], SpeakCapture.log
  end

  test "says an entry again once its tag was reset" do
    PokeAccess::UIV21.speak_changed(:focus_spec, "Huevo", 2)
    PokeAccess::UIV21.reset(:focus_spec)
    PokeAccess::UIV21.speak_changed(:focus_spec, "Huevo", 2)
    assert_equal [["Huevo", true]] * 2, SpeakCapture.log
  end

  test "without a slot, dedups an entry on its text" do
    2.times { PokeAccess::UIV21.speak_changed(:focus_spec, "Pocion") }
    assert_equal [["Pocion", true]], SpeakCapture.log
  end

  test "queues an entry when asked not to interrupt" do
    PokeAccess::UIV21.speak_changed(:focus_spec, "Pocion", nil, false)
    assert_equal [["Pocion", false]], SpeakCapture.log
  end

  test "says nothing for a blank entry" do
    [nil, ""].each { |text| PokeAccess::UIV21.speak_changed(:focus_spec, text, 1) }
    assert_nothing_spoken
  end

  test "says a quantity once per window" do
    fresh_amounts do
      win = Object.new
      2.times { PokeAccess::NumberEntry.on_text(win, "x5") }
      assert_equal [["5", false]], SpeakCapture.log
    end
  end

  test "says the same quantity again in a window opened anew" do
    fresh_amounts do
      PokeAccess::NumberEntry.on_text(Object.new, "x5")
      PokeAccess::NumberEntry.on_text(Object.new, "x5")
      assert_equal [["5", false], ["5", false]], SpeakCapture.log
    end
  end

  test "says the same quantity again in the same window once the last amount is forgotten" do
    fresh_amounts do
      win = Object.new
      PokeAccess::NumberEntry.on_text(win, "x5")
      PokeAccess::NumberEntry.forget
      PokeAccess::NumberEntry.on_text(win, "x5")
      assert_equal [["5", false], ["5", false]], SpeakCapture.log
    end
  end

  test "reads a quantity line's amount and a price with its unit, and no other text" do
    { "x5" => ["5"], "×12" => ["12"], "x1<r>100 PB" => ["1, 100 PB"], "Hola" => [] }.each do |raw, said|
      fresh_amounts do
        SpeakCapture.clear
        PokeAccess::NumberEntry.on_text(Object.new, raw)
        assert_equal said, SpeakCapture.lines, "for #{raw.inspect}"
      end
    end
  end

  test "queues the number a digit selector opens on behind its question" do
    PokeAccess::NumberEntry.on_digit_window(DigitWindow.new(10, 3))
    assert_equal [["10", false]], SpeakCapture.log
  end

  test "says each column the cursor moves to with its digit, interrupting" do
    win = opened(DigitWindow.new(205, 3))
    [1, 2].each do |i|
      win.index = i
      PokeAccess::NumberEntry.on_digit_window(win)
    end
    t = PokeAccess::I18n
    assert_equal [["#{t.t(:ne_tens)}: 0", true], ["#{t.t(:ne_units)}: 5", true]], SpeakCapture.log
  end

  test "says the new number, interrupting, when a digit changes" do
    win = opened(DigitWindow.new(10, 3))
    win.number = 20
    PokeAccess::NumberEntry.on_digit_window(win)
    assert_equal [["20", true]], SpeakCapture.log
  end

  test "says nothing on a frame where neither the cursor nor the number moves" do
    win = opened(DigitWindow.new(10, 3))
    PokeAccess::NumberEntry.on_digit_window(win)
    assert_nothing_spoken
  end

  test "says a signed entry's sign slot as plus or minus" do
    t = PokeAccess::I18n
    { false => :ne_plus, true => :ne_minus }.each do |negative, key|
      win = DigitWindow.new(-7, 2, true)
      win.index = 1
      win = opened(win)
      win.negative = negative
      win.index = 0
      PokeAccess::NumberEntry.on_digit_window(win)
      assert_equal [["#{t.t(:ne_sign)}: #{t.t(key)}", true]], SpeakCapture.log, "negative #{negative}"
    end
  end

  test "names a column past the millions by its power of ten" do
    win = DigitWindow.new(12_345_678, 8)
    win.index = 1
    win = opened(win)
    win.index = 0
    PokeAccess::NumberEntry.on_digit_window(win)
    assert_equal ["#{PokeAccess::I18n.t(:ne_place, :n => 10_000_000)}: 1"], SpeakCapture.lines
  end

  test "lets a closed screen's text go from the info key" do
    PokeAccess::Info.set_info(:text, "lore de la carta")
    PokeAccess::Info.clear_text
    assert_nil PokeAccess::Info.info_text
  end

  test "keeps a Pokemon on the info key when a screen's text is let go" do
    PokeAccess::Info.set_info(:pokemon, Poke.build(:name => "Chispa"))
    shown = PokeAccess::Info.info_text
    PokeAccess::Info.clear_text
    refute_nil shown, "the Pokemon was on the info key"
    assert_equal shown, PokeAccess::Info.info_text
  end

  test "says the button the cursor lands on, interrupting" do
    with_menu_on("Mochila") do
      PokeAccess::SpriteButtonMenu.focus(World.stub_scene(:@buttons => [[:bag, "Mochila"], [:party, "Equipo"]]), 1)
      assert_equal [["Equipo", true]], SpeakCapture.log
    end
  end

  test "says nothing when the cursor is on no button, or on one with a blank label" do
    one = World.stub_scene(:@buttons => [[:bag, "Mochila"]])
    blank = World.stub_scene(:@buttons => [[:bag, ""]])
    { "no buttons" => [World.stub_scene, 0], "past the last button" => [one, 1], "before the first" => [one, -1],
      "no cursor" => [one, nil], "a blank label" => [blank, 0] }.each do |what, (scene, idx)|
      PokeAccess::SpriteButtonMenu.focus(scene, idx)
      assert_nothing_spoken "for #{what}"
    end
  end

  test "brings the focused option back only at the end of the outermost of two nested fades" do
    with_menu_on("Mochila") do
      PokeAccess::MenuReturn.enter!
      fade
      assert_nothing_spoken "at the end of the inner fade"
      PokeAccess::MenuReturn.leave!
      assert_equal [["Mochila", true]], SpeakCapture.log, "at the end of the outer fade"
    end
  end

  test "brings the focused option back after a message shown over the menu" do
    with_menu_on("Mochila") do
      Kernel.pbMessage("Has guardado la partida.")
      assert_equal [["Mochila", true]], SpeakCapture.log
    end
  end

  test "brings back no option once the menu has ended its scene" do
    with_menu_on("Mochila") do
      PokeAccess::SpriteButtonMenu.gone!
      fade
      assert_nothing_spoken
    end
  end

  test "brings back no option with the menu closed" do
    with_menu_on("Mochila") do
      PokeAccess::SpriteButtonMenu.close!
      fade
      assert_nothing_spoken
    end
  end

  test "brings the option back once the menu reopens, however many closes came first" do
    with_menu_on("Mochila") do
      2.times { PokeAccess::SpriteButtonMenu.close! }
      PokeAccess::SpriteButtonMenu.open!
      fade
      assert_equal [["Mochila", true]], SpeakCapture.log
    end
  end

  test "brings the option back once the nesting is reset, though a fade before it never ended" do
    with_menu_on("Mochila") do
      PokeAccess::MenuReturn.enter!
      PokeAccess::MenuReturn.reset_nesting
      fade
      assert_equal [["Mochila", true]], SpeakCapture.log
    end
  end

  private

  # Runs the block with NumberEntry's last amount forgotten before and after.
  def fresh_amounts
    PokeAccess::NumberEntry.forget
    yield
  ensure
    PokeAccess::NumberEntry.forget
  end

  # The digit window once its opening frame was read, with the speech cleared.
  def opened(win)
    PokeAccess::NumberEntry.on_digit_window(win)
    SpeakCapture.clear
    win
  end

  # One fade over the menu, in and out.
  def fade
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  end

  # Runs the block with a sprite-button menu open, its focused button labelled label and the speech cleared; the
  # menu's depth and last label and the fades' nesting are put back afterwards.
  def with_menu_on(label)
    menu = PokeAccess::SpriteButtonMenu
    was = [menu.instance_variable_get(:@depth), menu.instance_variable_get(:@last)]
    PokeAccess::MenuReturn.reset_nesting
    menu.instance_variable_set(:@depth, 0)
    menu.open!
    menu.focus(World.stub_scene(:@buttons => [[:bag, label]]), 0)
    SpeakCapture.clear
    yield
  ensure
    menu.instance_variable_set(:@depth, was[0])
    menu.instance_variable_set(:@last, was[1])
    PokeAccess::MenuReturn.reset_nesting
  end
end

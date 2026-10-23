# The options screen's value of an option on the modern shapes (lowest_value, highest_value), a number row's as it
# painted it, word included; and the dex list's number for a hash row, a regional dex's offset taken off.

class OptionsValueGdTest < PokeAccessTest
  Options = PokeAccess::Options

  # The modern slider's next() steps the offset from lowest_value, as v20 and v21 do.
  class ModernOffsetSlider < SliderOption
    def next(current)
      index = current + lowest_value + 1
      index = highest_value if index > highest_value
      index - lowest_value
    end
  end

  # A labelled option whose row paints a number after its name, as v21's enum rows paint their labels there: the
  # stub's painter writes a number after any NumberOption's name.
  class PaintedLabelOption < NumberOption
    attr_reader :values
    def initialize(name, lo, hi, values); super(name, lo, hi); @values = values; end
  end

  # A numeric option with a floor and no ceiling.
  class LowestOnlyOption
    attr_reader :name, :lowest_value
    def initialize(name, lowest_value); @name = name; @lowest_value = lowest_value; end
  end

  test "a slider says the number its bar shows" do
    volume = SliderOption.new("Music Volume", 0, 100)
    { 50 => "50", 0 => "0" }.each { |value, want| assert_equal want, Options.value_of(volume, value), "at #{value}" }
  end

  test "a numeric option says its place out of its count" do
    frame = NumberOption.new("Speech Frame", 1, 20)
    { 0 => "1/20", 4 => "5/20" }.each do |value, want|
      assert_equal want, Options.value_of(frame, value), "stored #{value}"
    end
  end

  test "a modern slider above a floor of zero says its floor plus the stored offset" do
    speed = ModernOffsetSlider.new("Text Speed", 1, 5)
    { 2 => "3", 0 => "1" }.each { |value, want| assert_equal want, Options.value_of(speed, value), "stored #{value}" }
  end

  test "an option with a floor and no ceiling says its floor plus the stored value" do
    assert_equal "3", Options.value_of(LowestOnlyOption.new("Speed", 1), 2)
  end

  test "a number row is said as it painted its value, its word included" do
    win = painted_window
    win.index = 0
    assert_equal "Marco de Texto: Tipo 3/40", PokeAccess::Menus.focused_text(win), "the focused row"
    assert_equal "Tipo 3/40", Options.value_label(win, 0), "its value for left and right"
    assert_equal "Cambio", Options.value_label(win, 1), "and the label row beside it keeps its label"
  end

  test "a labelled row is said by its label, whatever its row paints after its name" do
    win = Window_PokemonOption.new([PaintedLabelOption.new("Estilo", 1, 2, ["Cambio", "Fijo"])], "Salir")
    win[0] = 0
    win.index = 0
    assert_equal "Estilo: Cambio", PokeAccess::Menus.focused_text(win), "the focused row"
    assert_equal "Cambio", Options.value_label(win, 0), "its value for left and right"
  end

  test "a change of a number row's value under the cursor is said as the row repaints it" do
    win = painted_window
    win.index = 0
    win.update
    SpeakCapture.clear
    win[0] = 3
    win.update
    assert_equal [["Tipo 4/40", true]], SpeakCapture.log
  end

  test "a value the row has not painted yet is composed, and said as painted once it is" do
    win = painted_window
    win.instance_variable_get(:@values)[0] = 9
    assert_equal "10/40", Options.value_label(win, 0), "before the row repaints"
    win.refresh
    assert_equal "Tipo 10/40", Options.value_label(win, 0), "after"
  end

  test "a number row that paints a blank value is said as composed" do
    win = Window_PokemonOption.new([NumberOption.new("Marco de Texto", 1, 40)], "Salir")
    win.number_format = "%.0s%.0s"
    win[0] = 2
    assert_equal "3/40", Options.value_label(win, 0)
  end

  test "a button row has no value for left or right to say" do
    assert_nil Options.value_label(Window_PokemonOption.new([ButtonOption.new("System & Audio")]), 0)
  end

  test "a dex row says the number painted, a regional dex's offset taken off" do
    caught = t(:dex_caught)
    { true => "25, Pikachu, #{caught}", false => "26, Pikachu, #{caught}" }.each do |shift, want|
      assert_equal want, dex_row(:species => 25, :name => "Pikachu", :number => 26, :shift => shift), "shift #{shift}"
    end
  end

  test "a dex row without a name says its species' name from the game's data" do
    want = "26, #{GameData::Species.get(25).name}, #{t(:dex_caught)}"
    [nil, ""].each do |name|
      assert_equal want, dex_row(:species => 25, :name => name, :number => 26, :shift => false), "name #{name.inspect}"
    end
  end

  private

  # An options window, v21's or Anil's own copy, over a number row "Marco de Texto" (1 to 40) painting "Tipo {1}/{2}"
  # and a label row "Estilo", the number row at its third value and painted.
  def painted_window
    rows = [NumberOption.new("Marco de Texto", 1, 40), EnumOption.new("Estilo", ["Cambio", "Fijo"])]
    win = Window_PokemonOption.new(rows, "Salir")
    win.number_format = "Tipo %d/%d"
    win[0] = 2
    win
  end

  # The dex list's spoken row for one hash row {:species, :name, :number, :shift}.
  def dex_row(row)
    win = Window_Pokedex.new
    win.instance_variable_set(:@commands, [row])
    win.index = 0
    PokeAccess::Menus.focused_text(win)
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end

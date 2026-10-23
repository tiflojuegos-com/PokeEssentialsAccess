# The options screen's value of an option on the gen-6 and v19 shapes (optstart, optend), each kind as it paints it,
# and the dex list's row number, a regional dex's offset taken off as drawItem takes it off.

class OptionsValueTest < PokeAccessTest
  Options = PokeAccess::Options

  # The rv engine's Turbo Speed: a numeric option stepping by a tenth, painted with one decimal ("1.3x").
  class TenthStepOption < NumberOption
    def optinc; 0.1; end
  end

  # An rv numeric option stepping by one, painted as a whole number.
  class WholeStepOption < NumberOption
    def optinc; 1; end
  end

  # A stock slider: next() steps the value's offset from the floor, as every Essentials copy does.
  class OffsetFpsSlider < SliderOption
    def next(current)
      index = current + optstart + 2
      index = optend if index > optend
      index - optstart
    end
  end

  # Uranium's slider: next() steps the value itself, the number its bar paints.
  class ValueFpsSlider < SliderOption
    def next(current)
      index = current + 2
      index > optend ? optend : index
    end
  end

  # A numeric option with a floor and no ceiling.
  class FloorOnlyOption
    attr_reader :name, :optstart
    def initialize(name, optstart); @name = name; @optstart = optstart; end
  end

  test "a slider says the number its bar shows, with no total" do
    volume = SliderOption.new("Music Volume", 0, 100)
    buff = SliderOption.new("Attack Buff", 0, 6)
    [[volume, 50, "50"], [volume, 0, "0"], [volume, 100, "100"], [buff, 3, "3"]].each do |slider, value, want|
      assert_equal want, Options.value_of(slider, value), "#{slider.name} at #{value}"
    end
  end

  test "a numeric option says its place out of its count" do
    frame = NumberOption.new("Speech Frame", 1, 20)
    volume = NumberOption.new("Volume", 0, 9)
    [[frame, 0, "1/20"], [frame, 4, "5/20"], [frame, 19, "20/20"], [volume, 0, "0/10"]].each do |option, value, want|
      assert_equal want, Options.value_of(option, value), "#{option.name} at #{value}"
    end
  end

  test "a numeric option stepping by a tenth says its value with one decimal, free of float noise" do
    turbo = TenthStepOption.new("Turbo Speed", 1, 10)
    { 0.1 + 0.2 => "1.3", 0 => "1.0" }.each do |value, want|
      assert_equal want, Options.value_of(turbo, value), "stored #{value}"
    end
  end

  test "a numeric option stepping by one keeps its place out of its count" do
    assert_equal "3/10", Options.value_of(WholeStepOption.new("Frame", 1, 10), 2)
  end

  test "an enum says the label of its value" do
    style = EnumOption.new("Battle Style", ["Switch", "Set"])
    { 0 => "Switch", 1 => "Set" }.each do |value, want|
      assert_equal want, Options.value_of(style, value), "at #{value}"
    end
  end

  test "an option with no bounds says the stored value as it is" do
    assert_equal "7", Options.value_of(Object.new, 7)
  end

  test "an option with a floor and no ceiling says its floor plus the stored value" do
    assert_equal "3", Options.value_of(FloorOnlyOption.new("Speed", 1), 2), "a numeric option"
    assert_equal "3", Options.value_of(SliderOption.new("Speed", 1, nil), 2), "a slider"
  end

  test "a stock slider above a floor of zero keeps its value as an offset from the floor" do
    fps = OffsetFpsSlider.new("FPS", 40, 60)
    { 0 => "40", 10 => "50", 20 => "60" }.each do |value, want|
      assert_equal want, Options.value_of(fps, value), "stored #{value}"
    end
  end

  test "a slider whose next() steps the painted number says that number unshifted" do
    fps = ValueFpsSlider.new("FPS", 40, 60)
    speed = ValueFpsSlider.new("Text Speed", 1, 5)
    [[fps, 40, "40"], [fps, 50, "50"], [fps, 60, "60"], [speed, 3, "3"]].each do |slider, value, want|
      assert_equal want, Options.value_of(slider, value), "#{slider.name} at #{value}"
    end
  end

  test "from a floor of zero both kinds of slider say the same number" do
    sliders = [OffsetFpsSlider.new("Autosave", 0, 60), ValueFpsSlider.new("Autosave", 0, 60)]
    assert_equal ["30", "30"], sliders.map { |s| Options.value_of(s, 30) }
  end

  test "a slider without a next() of its own is taken as stock" do
    assert_equal "3", Options.value_of(SliderOption.new("Speed", 1, 5), 2)
  end

  test "the focused option's value is said as value_of says it" do
    assert_equal "80", Options.value_label(option_window([SliderOption.new("SE Volume", 0, 100)], [80]), 0)
  end

  test "the exit row, a row past it, no row and a window without options have no value" do
    win = option_window([SliderOption.new("SE Volume", 0, 100)], [80])
    assert_nil Options.value_label(win, 1), "the exit row, just past the options"
    assert_nil Options.value_label(win, 5), "a row further on"
    assert_nil Options.value_label(win, nil), "no row focused"
    assert_nil Options.value_label(Window_DrawableCommand.new([]), 0), "a window that keeps no options"
  end

  test "a bare string row, Rejuvenation's headings and closing Back, is said as painted and has no value" do
    win = option_window([EnumOption.new("Text Speed", ["Slow", "Fast"]), "Back"], [0, nil])
    assert_equal "Back", Options.row("Back", nil), "the row says the word it paints"
    assert_nil Options.value_label(win, 1), "nothing for left or right to announce"
    assert_equal "Slow", Options.value_label(win, 0), "while the option beside it keeps its own"
  end

  test "a dex row says the number painted, a regional dex's offset taken off" do
    with_dex([25], [25]) do
      assert_equal "25, Pikachu, #{t(:dex_caught)}", dex_row([25, "Pikachu", 4, 60, 26, true]), "with the offset"
      assert_equal "26, Pikachu, #{t(:dex_caught)}", dex_row([25, "Pikachu", 4, 60, 26, false]), "without it"
    end
  end

  test "a dex row says its species' name and state as the Pokedex has it, an unseen one only as unknown" do
    pikachu = [25, "Pikachu", 4, 60, 25, false]
    [[[], [], "25, #{t(:dex_unknown)}"],
     [[25], [], "25, Pikachu, #{t(:dex_seen)}"],
     [[25], [25], "25, Pikachu, #{t(:dex_caught)}"]].each do |seen, owned, want|
      assert_equal want, with_dex(seen, owned) { dex_row(pikachu) }, "seen #{seen.inspect}, caught #{owned.inspect}"
    end
  end

  private

  # A gen-6 options window listing options, each stored value read by its index as the screen reads it.
  def option_window(options, values)
    win = Window_DrawableCommand.new([])
    win.instance_variable_set(:@options, options)
    win.define_singleton_method(:[]) { |i| values[i] }
    win
  end

  # The dex list's spoken row for one array row [species, name, height, weight, number, shift].
  def dex_row(row)
    win = Window_Pokedex.new
    win.instance_variable_set(:@commands, [row])
    win.index = 0
    PokeAccess::Menus.focused_text(win)
  end

  # The block's value with the player's Pokedex having seen the species in seen and caught those in owned.
  def with_dex(seen, owned)
    who = PokeAccess::Engine.player
    who.define_singleton_method(:seen?) { |sp| seen.include?(sp) }
    who.define_singleton_method(:owned?) { |sp| owned.include?(sp) }
    yield
  ensure
    [:seen?, :owned?].each { |m| who.singleton_class.send(:remove_method, m) if who.singleton_methods.include?(m) }
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end

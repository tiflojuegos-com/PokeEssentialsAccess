# The options screen's numeric kinds and the dex list's regional offset, on the gen-6 and v19 shapes (the modern
# ones are options_value_gd_spec.rb), each said as the screen paints it:
#   NumberOption -> "value/total".
#   SliderOption -> the value alone over a bar, no total.
#   Window_Pokedex -> a dex in Settings::DEXES_WITH_OFFSETS starts at 000: drawItem subtracts the offset.

Suite.define("options: a slider reads the value it paints, a numeric option keeps its fraction") do
  vo = PokeAccess::Options

  slider = SliderOption.new("Music Volume", 0, 100)
  eq "a volume slider reads the number on screen, with no invented total", vo.value_of(slider, 50), "50"
  eq "at its floor", vo.value_of(slider, 0), "0"
  eq "and at its ceiling", vo.value_of(slider, 100), "100"

  buff = SliderOption.new("Attack Buff", 0, 6)
  eq "Fire Ash's enemy buffs go up to the six the bar shows", vo.value_of(buff, 3), "3"

  number = NumberOption.new("Speech Frame", 1, 20)
  eq "a numeric option keeps the fraction its screen paints", vo.value_of(number, 0), "1/20"
  eq "and moves within it", vo.value_of(number, 4), "5/20"

  enum = EnumOption.new("Battle Style", ["Switch", "Set"])
  eq "an enum still reads its label", vo.value_of(enum, 1), "Set"

  eq "an option with no bounds at all reads the raw value", vo.value_of(Object.new, 7), "7"
end

# The rv engine's Turbo Speed: a numeric option stepping by a tenth, painted with one decimal ("1.3x").
class TenthStepOption < NumberOption
  def optinc; 0.1; end
end

Suite.define("options: a numeric option stepping by a tenth reads one decimal, free of float noise") do
  turbo = TenthStepOption.new("Turbo Speed", 1, 10)
  eq "three tenths up from its floor, not 1.3000000000000003/10", PokeAccess::Options.value_of(turbo, 0.1 + 0.2), "1.3"
  eq "and at its floor, as the screen paints it", PokeAccess::Options.value_of(turbo, 0), "1.0"
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

Suite.define("options: a slider over a floor above zero reads the number painted, offset or not") do
  vo = PokeAccess::Options
  stock = OffsetFpsSlider.new("FPS", 40, 60)
  eq "a stock slider keeps the offset from its floor", vo.value_of(stock, 10), "50"
  eq "its floor is the stored zero", vo.value_of(stock, 0), "40"
  own = ValueFpsSlider.new("FPS", 40, 60)
  eq "a slider that keeps the painted value reads it unshifted", vo.value_of(own, 50), "50"
  eq "at its floor", vo.value_of(own, 40), "40"
  eq "and at its ceiling", vo.value_of(own, 60), "60"
  eq "from a floor of zero both keep the same number", vo.value_of(ValueFpsSlider.new("Autosave", 0, 60), 30), "30"
  eq "a slider without next() is taken as stock", vo.value_of(SliderOption.new("Speed", 1, 5), 2), "3"
end

Suite.define("options: the live left/right announcement says the same as the focused row") do
  vo = PokeAccess::Options
  win = Window_DrawableCommand.new([])
  win.instance_variable_set(:@options, [SliderOption.new("SE Volume", 0, 100)])
  def win.[](i); 80; end
  eq "the focused row's value goes through the same formatter", vo.value_label(win, 0), "80"
  falsy "and an index past the list has no value", vo.value_label(win, 5)
end

# The dex list through the real focused_text dispatch. Array rows: [species, name, height, weight, number, shift].
Suite.define("dex list: the number spoken is the number painted, offset dex included") do
  win = Window_Pokedex.new
  win.instance_variable_set(:@commands,
                            [[25, "Pikachu", 4, 60, 26, true], [25, "Pikachu", 4, 60, 26, false]])

  win.index = 0
  t = PokeAccess::Menus.focused_text(win).to_s
  eq "a dex with a regional offset drops the number by one, as drawItem does", t.index("25, "), 0
  falsy "and never says the raw stored number", t.index("26")

  win.index = 1
  eq "a dex without the offset speaks the stored number unchanged",
     PokeAccess::Menus.focused_text(win).to_s.index("26, "), 0
end

# Rejuvenation's options keep their section headings and the closing "Back" as bare strings among the options.
Suite.define("options: a bare string row (Rejuvenation's headings and Back) is said as painted, with no value") do
  vo = PokeAccess::Options
  eq "the closing row says the word it paints", vo.row("Back", nil), "Back"
  win = Object.new
  win.instance_variable_set(:@options, [EnumOption.new("Text Speed", ["Slow", "Fast"]), "Back"])
  def win.[](_i); 0; end
  eq "and has no value for left or right to announce", vo.value_label(win, 1), nil
  eq "while an option beside it keeps its own", vo.value_label(win, 0), "Slow"
end

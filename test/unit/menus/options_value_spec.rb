# The two numeric option kinds of the options screen, and the Pokedex list's regional offset, on the gen-6
# and v19 shapes (optstart/optend, array rows). Its twin options_value_gd_spec.rb holds the modern shapes:
# the two eras name their accessors differently and each engine pass sees only its own file, so a fix that
# reads one shape and not the other has to be pinned twice or it goes unnoticed in half the games.
#
# Both are places where the mod SAID A NUMBER the screen never painted, which no exception and no nil ever
# betrays: only reading the engine's own drawItem next to the mod's line shows it.
#
#   NumberOption -> the screen paints "Type value/total", so the fraction is right.
#   SliderOption -> the screen paints ONLY the value over a bar; a fraction invents a total nobody can see.
#   Window_Pokedex -> a dex in Settings::DEXES_WITH_OFFSETS starts at 000, and drawItem subtracts the
#   offset before painting.

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

Suite.define("options: the live left/right announcement says the same as the focused row") do
  vo = PokeAccess::Options
  win = Window_DrawableCommand.new([])
  win.instance_variable_set(:@options, [SliderOption.new("SE Volume", 0, 100)])
  def win.[](i); 80; end
  eq "the focused row's value goes through the same formatter", vo.value_label(win, 0), "80"
  falsy "and an index past the list has no value", vo.value_label(win, 5)
end

# The dex list extractor, driven through the real focused_text dispatch so the row shape resolves the way
# it does in a game. Array rows: [species, name, height, weight, number, shift].
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

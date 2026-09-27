# The modern half of options_value_spec.rb: the same rules over lowest_value/highest_value and the dex's hash rows.

Suite.define("options: the modern slider reads its painted value and the numeric option its fraction") do
  vo = PokeAccess::Options

  slider = SliderOption.new("Music Volume", 0, 100)
  eq "a volume slider reads the number on screen", vo.value_of(slider, 50), "50"
  eq "at its floor", vo.value_of(slider, 0), "0"

  number = NumberOption.new("Speech Frame", 1, 20)
  eq "a numeric option paints and reads a fraction", vo.value_of(number, 0), "1/20"
  eq "and moves within it", vo.value_of(number, 4), "5/20"

  enum = EnumOption.new("Battle Style", ["Switch", "Set"])
  eq "an enum still reads its label", vo.value_of(enum, 1), "Set"
end

# The modern slider's next() steps the offset from lowest_value, as v20 and v21 do.
class ModernOffsetSlider < SliderOption
  def next(current)
    index = current + lowest_value + 1
    index = highest_value if index > highest_value
    index - lowest_value
  end
end

Suite.define("options: a modern slider over a floor above zero still reads floor plus its offset") do
  vo = PokeAccess::Options
  s = ModernOffsetSlider.new("Text Speed", 1, 5)
  eq "the stored offset is shifted back to the number painted", vo.value_of(s, 2), "3"
  eq "and its floor", vo.value_of(s, 0), "1"
end

# Hash rows: {:species, :name, :number, :shift}.
Suite.define("dex list: the modern row honours its regional offset too") do
  win = Window_Pokedex.new
  win.instance_variable_set(:@commands,
                            [{ :species => 25, :name => "Pikachu", :number => 26, :shift => true },
                             { :species => 25, :name => "Pikachu", :number => 26, :shift => false }])

  win.index = 0
  t = PokeAccess::Menus.focused_text(win).to_s
  eq "an offset dex drops the number by one", t.index("25, "), 0
  falsy "and never says the raw stored number", t.index("26")

  win.index = 1
  eq "without the offset the stored number stands",
     PokeAccess::Menus.focused_text(win).to_s.index("26, "), 0
end

# A number row paints a word with its value, "Type {1}/{2}" in v21 and "Tipo {1}/{2}" in Anil's own copy: the row and
# the left/right announcement say what the row painted, composing only a value it has not painted yet.
Suite.define("options: a number row says the value it painted, its word included") do
  vo = PokeAccess::Options
  win = Window_PokemonOption.new([NumberOption.new("Marco de Texto", 1, 40), EnumOption.new("Estilo", ["Cambio", "Fijo"])],
                                 "Salir")
  win.number_format = "Tipo %d/%d"
  win[0] = 2
  win.index = 0
  eq "the focused row as painted", PokeAccess::Menus.focused_text(win), "Marco de Texto: Tipo 3/40"
  eq "its value as painted", vo.value_label(win, 0), "Tipo 3/40"
  eq "a label row keeps its label", vo.value_label(win, 1), "Cambio"

  win.update
  SpeakCapture.clear
  win[0] = 3
  win.update
  eq "a change under the cursor is said as the row repaints it", SpeakCapture.log, [["Tipo 4/40", true]]

  win.instance_variable_get(:@values)[0] = 9
  eq "a value the row has not painted yet is composed", vo.value_label(win, 0), "10/40"
  win.refresh
  eq "and said as painted once it is", vo.value_label(win, 0), "Tipo 10/40"
end

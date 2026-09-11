# The modern half of options_value_spec.rb: the same two rules over the accessors modern Essentials gives
# these classes (lowest_value / highest_value) and over the hash rows of its Pokedex list. Only the gamedata
# pass loads this file, and only the gen-6 pass loads its twin, so a fix written against one shape is caught
# here the moment it forgets the other.

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

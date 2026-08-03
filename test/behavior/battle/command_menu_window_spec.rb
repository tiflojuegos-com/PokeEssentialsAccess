# The battle command menu (fight/bag/pokemon/run). Its labels exist ONLY inside its window, so unlike the
# move reader -- which goes to the battler's own data and never noticed any of this -- it has to find the
# widget. And Essentials renamed the widget: @window up to v17, @cmdWindow from v19 on, checked against the
# upstream tags v19 through v21.1.
#
# The reader only knew @window, so on a v19 game it found nil, said nothing and raised nothing: no error,
# no marker, and nothing in the hooks' missing list either, because the class and the method both exist and
# the hook installs perfectly. It just reads an empty box forever. That is why this reached players and
# only surfaced when somebody played Infinite Fusion and reported a battle menu that never spoke.
Suite.define("battle: the command menu is read whichever name the engine gives its window") do
  win = Object.new
  win.instance_variable_set(:@commands, ["Luchar", "Mochila", "Pokemon", "Huir"])

  old = Object.new
  old.instance_variable_set(:@window, win)
  SpeakCapture.clear
  PokeAccess::Battle.read_command(old, 1, true)
  spoke "the pre-v19 window is still read, exactly as before", /Mochila/

  # Same display, same data: from v19 the engine simply calls the ivar something else.
  modern = Object.new
  modern.instance_variable_set(:@cmdWindow, win)
  SpeakCapture.clear
  PokeAccess::Battle.read_command(modern, 0, true)
  spoke "and so is the v19 one, which was the silent case", /Luchar/

  SpeakCapture.clear
  PokeAccess::Battle.read_command(modern, 3, true)
  spoke "moving through the menu reads the new option", /Huir/

  # Degrading quietly matters here: this is the exact state the v19 games sat in, so it has to stay a
  # no-op and never become an exception thrown out of a battle.
  SpeakCapture.clear
  PokeAccess::Battle.read_command(Object.new, 0, true)
  silent "a display with no window at all is silent, not an error"

  empty = Object.new
  empty.instance_variable_set(:@cmdWindow, Object.new)
  SpeakCapture.clear
  PokeAccess::Battle.read_command(empty, 0, true)
  silent "nor does a window without commands"

  SpeakCapture.clear
  PokeAccess::Battle.read_command(modern, 99, true)
  silent "and an index past the end says nothing rather than guessing"
end

# The shape that actually ships. From v19 the command menu has NO window: USE_GRAPHICS is true, so setTexts
# stores the labels in @texts and returns before building one, and the four options are drawn as button
# sprites. Looking for a widget there finds nothing at all -- which is why the first fix, teaching the
# reader the v19 NAME of the window (@cmdWindow), changed nothing: the rename was real but the widget it
# renamed is not created. Still true in v21.1, so this is the modern shape and not a v19 detour.
Suite.define("battle: the command menu is read when the engine draws it with no window at all") do
  gfx = Object.new
  gfx.instance_variable_set(:@texts, ["Luchar", "Mochila", "Pokemon", "Huir"])

  SpeakCapture.clear
  PokeAccess::Battle.read_command(gfx, 0, true)
  spoke "the labels are found on the display itself", /Luchar/

  SpeakCapture.clear
  PokeAccess::Battle.read_command(gfx, 2, true)
  spoke "and moving reads the new one", /Pokemon/

  # A window, when there is one, still wins: the seven gen-6 games must keep their original path even if
  # some fork ever grew a @texts alongside it.
  both = Object.new
  win = Object.new
  win.instance_variable_set(:@commands, ["DesdeVentana"])
  both.instance_variable_set(:@window, win)
  both.instance_variable_set(:@texts, ["DesdeTexts"])
  SpeakCapture.clear
  PokeAccess::Battle.read_command(both, 0, true)
  spoke "the window is preferred over the texts when both exist", /DesdeVentana/
end

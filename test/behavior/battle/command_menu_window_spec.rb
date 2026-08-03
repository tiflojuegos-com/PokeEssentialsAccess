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

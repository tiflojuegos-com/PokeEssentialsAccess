# Battle.read_command: the labels come from the command window, @window up to v17 and @cmdWindow from v19; a
# missing window, list or index says nothing.
Suite.define("battle: the command menu is read whichever name the engine gives its window") do
  win = Object.new
  win.instance_variable_set(:@commands, ["Luchar", "Mochila", "Pokemon", "Huir"])

  old = Object.new
  old.instance_variable_set(:@window, win)
  SpeakCapture.clear
  PokeAccess::Battle.read_command(old, 1, true)
  spoke "the pre-v19 window is still read, exactly as before", /Mochila/

  modern = Object.new
  modern.instance_variable_set(:@cmdWindow, win)
  SpeakCapture.clear
  PokeAccess::Battle.read_command(modern, 0, true)
  spoke "and so is the v19 one, which was the silent case", /Luchar/

  SpeakCapture.clear
  PokeAccess::Battle.read_command(modern, 3, true)
  spoke "moving through the menu reads the new option", /Huir/

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

# With USE_GRAPHICS (both Infinite Fusion) setTexts touches no window, so stash_command_texts keeps the labels it is
# handed as [message, l0, l1, l2, l3] (slot 0 is position 1); a window, when there is one, wins.
Suite.define("battle: the command menu is read when the engine draws it with no window at all") do
  gfx = Object.new
  PokeAccess::Battle.stash_command_texts(gfx, ["Que hara Pikachu?", "Luchar", "Mochila", "Pokemon", "Huir"])

  SpeakCapture.clear
  PokeAccess::Battle.read_command(gfx, 0, true)
  spoke "the first slot is the first LABEL, not the message the call carries with it", /Luchar/
  not_spoke "and the message itself is never spoken as an option", /hara/

  SpeakCapture.clear
  PokeAccess::Battle.read_command(gfx, 2, true)
  spoke "moving reads the option at that slot", /Pokemon/

  SpeakCapture.clear
  PokeAccess::Battle.read_command(gfx, 3, true)
  spoke "including the last one, the one the mode decides (run/cancel/call)", /Huir/

  both = Object.new
  win = Object.new
  win.instance_variable_set(:@commands, ["DesdeVentana"])
  both.instance_variable_set(:@window, win)
  PokeAccess::Battle.stash_command_texts(both, ["msg", "DesdeStash"])
  SpeakCapture.clear
  PokeAccess::Battle.read_command(both, 0, true)
  spoke "the window is preferred over the kept labels when both exist", /DesdeVentana/

  odd = Object.new
  PokeAccess::Battle.stash_command_texts(odd, "no soy un array")
  SpeakCapture.clear
  PokeAccess::Battle.read_command(odd, 0, true)
  silent "a non-array argument is ignored instead of raising in a battle"
end

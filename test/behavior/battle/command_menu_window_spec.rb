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

# The shape that actually ships on both Infinite Fusion. CommandMenuDisplay sets USE_GRAPHICS = true, so
# setTexts writes the message box and RETURNS before touching any window: the four options are button
# sprites and the labels it was handed are dropped on the floor. There is no widget to find and nothing
# left on the display either, which is why teaching the reader the v19 NAME of the window changed nothing,
# and why a later guess at a @texts ivar changed nothing twice -- setTexts never writes one. The only
# moment the labels exist is the call itself, so the reader keeps them as they go past.
#
# The offset is the part that goes wrong quietly: setTexts is handed [message, l0, l1, l2, l3], so slot 0
# sits at position 1. Storing the array whole makes every option read one place early and the first one
# say "What will X do?" -- believable enough in a recording to be missed.
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

  # A window, when there is one, still wins: the seven gen-6 games fill a real command list and must keep
  # taking that path, stash or no stash.
  both = Object.new
  win = Object.new
  win.instance_variable_set(:@commands, ["DesdeVentana"])
  both.instance_variable_set(:@window, win)
  PokeAccess::Battle.stash_command_texts(both, ["msg", "DesdeStash"])
  SpeakCapture.clear
  PokeAccess::Battle.read_command(both, 0, true)
  spoke "the window is preferred over the kept labels when both exist", /DesdeVentana/

  # setTexts is engine-facing and a fork could hand it anything. Degrading quietly matters more here than
  # almost anywhere, because this runs inside a battle.
  odd = Object.new
  PokeAccess::Battle.stash_command_texts(odd, "no soy un array")
  SpeakCapture.clear
  PokeAccess::Battle.read_command(odd, 0, true)
  silent "a non-array argument is ignored instead of raising in a battle"
end

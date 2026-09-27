# A command window whose list is replaced, or changes size, under a still cursor speaks its focused row again.
Suite.define("menus: replacing a window's list under a still cursor is a change, and it speaks") do
  win = Window_DrawableCommand.new(["Charmander", "Squirtle", "Bulbasaur"])
  win.index = 0
  win.active = true

  SpeakCapture.clear
  win.update
  eq "the focused row reads on arrival", SpeakCapture.lines, ["Charmander"]

  SpeakCapture.clear
  win.update
  silent "and an idle frame says nothing"

  SpeakCapture.clear
  win.instance_variable_set(:@commands, ["Pidgey", "Rattata", "Caterpie"])
  win.update
  eq "the list swapped under the same index speaks the new row", SpeakCapture.lines, ["Pidgey"]

  SpeakCapture.clear
  win.instance_variable_set(:@commands, ["Pidgey", "Rattata"])
  win.update
  eq "a list that lost a row re-reads where the cursor is", SpeakCapture.lines, ["Pidgey"]

  SpeakCapture.clear
  win.index = 1
  win.update
  eq "moving still reads", SpeakCapture.lines, ["Rattata"]
end

Suite.define("menus: the witness is one row, never the whole list, and never raises") do
  m = PokeAccess::Menus
  win = Window_DrawableCommand.new(["a", "b"])
  eq "it is the row count and the focused row, kept as the row is", m.list_witness(win, 1), [2, "b"]
  eq "an index past the end still answers", m.list_witness(win, 9), [2, nil]
  bare = Object.new
  falsy "a window with no list of its own has no witness", m.list_witness(bare, 0)
end

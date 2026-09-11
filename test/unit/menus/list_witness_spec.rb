# A command window whose LIST is replaced while the cursor stays put. The reader keyed on the index alone,
# so that frame looked exactly like a frame in which nothing happened, and it said nothing -- while the row
# under the cursor now meant something completely different. Fire Ash's battle-swap screen does it on
# purpose: it puts the rival's team where yours was, index still on the first row, and the player went on
# believing they were looking at their own team.
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

  # A list that changed SIZE is a different list, even when the focused row still reads the same, and the
  # reader says it again. Deliberate: the row may now be a different thing under the same words (a filtered
  # dex, a bag an item just left), and for a blind player a redundant line costs a second while a silent
  # frame costs the whole meaning of the screen.
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

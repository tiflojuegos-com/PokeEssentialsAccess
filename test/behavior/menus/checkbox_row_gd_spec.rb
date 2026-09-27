# A toggle row ("[X] Option" or "[  ] Option": Soulstones 2's Randomizer X rules, mystery gift, debug lists) reads as
# the option, then its state as a word; every other row reads as it is.
Suite.define("command reader: a toggle row says its option, then whether it is on") do
  m = PokeAccess::Menus
  on = PokeAccess::I18n.t(:val_on)
  off = PokeAccess::I18n.t(:val_off)
  eq "a checked rule", m.checkbox_row("[X] Randomize Trainer parties"), "Randomize Trainer parties, #{on}"
  eq "an unchecked one, whose box is two spaces", m.checkbox_row("[  ] Randomize Wild encounters"),
     "Randomize Wild encounters, #{off}"
  eq "the debug lists' Y is a check too", m.checkbox_row("[Y] Medalla 1"), "Medalla 1, #{on}"
  eq "a row with no box is left alone", m.checkbox_row("Done"), "Done"
  eq "and so is a bracketed word that is not a box", m.checkbox_row("[Nuevo] Ruta 1"), "[Nuevo] Ruta 1"
  eq "a bare box with no option says nothing new", m.checkbox_row("[X]"), "[X]"

  win = Window_CommandPokemon.new(["[  ] Randomize Trainer parties", "Done"])
  win.update
  eq "the moved-to row, as the reader speaks it", SpeakCapture.lines, ["Randomize Trainer parties, #{off}"]
end

# A list row made of nothing but dashes, dots or underscores is a placeholder -- Awakening's autosave
# selector fills every empty slot with ten hyphens -- and a screen reader spelling them says nothing a
# player can use. The command reader says "Empty" for such a row and leaves every real row alone.
Suite.define("command reader: a row of dashes is a placeholder and is said as empty") do
  m = PokeAccess::Menus
  truthy "ten hyphens are a placeholder", m.placeholder?("----------")
  truthy "so are dots and underscores, spaced or not", m.placeholder?(" . . . ") && m.placeholder?("____")
  falsy "a real label is not", m.placeholder?("Ruta 1 - 12:00")
  falsy "and neither is an empty string, which is silence already", m.placeholder?("")
  falsy "nor a dash inside a name", m.placeholder?("Poké-Ball")

  win = Window_CommandPokemon.new(["----------", "Ruta 1 - 12:00"])
  win.index = 0
  truthy "the focused row text of an empty slot is the placeholder", m.placeholder?(m.focused_text(win))
  win.index = 1
  eq "and a filled slot reads as it is", m.focused_text(win), "Ruta 1 - 12:00"
end

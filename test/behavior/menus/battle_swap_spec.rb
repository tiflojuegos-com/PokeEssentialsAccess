# The frontier rental list (BattleSwapScene): a rented row, painted red, says it is chosen; the mark comes from the
# scene's @choices while its list loop runs, never from the same red on another window.
Suite.define("battle swap: a rented row says it is chosen, and renting one says the row again") do
  red = "<c3=E82010,F8A8B8>"
  rows = ["Pikachu - Raton Pokemon", "Bulbasaur - Semilla Pokemon", "Eevee - Evolucion Pokemon"]
  chosen = PokeAccess::I18n.t(:swap_chosen)
  scene = BattleSwapScene.new(rows.dup, [])
  list = scene.list

  scene.on_choose = lambda { list.update }
  scene.pbChoosePokemon(false)
  eq "the focused row, as the game names it", SpeakCapture.lines, [rows[0]]

  SpeakCapture.clear
  scene.pbUpdateChoices([0], [red + rows[0], rows[1], rows[2]])
  scene.pbChoosePokemon(false)
  eq "back on the list after renting it, the row is said again with its mark", SpeakCapture.lines,
     ["#{rows[0]}, #{chosen}"]

  SpeakCapture.clear
  scene.on_choose = lambda { list.index = 1; list.update }
  scene.pbChoosePokemon(false)
  eq "a row not rented carries no mark", SpeakCapture.lines, [rows[1]]

  SpeakCapture.clear
  scene.pbUpdateChoices([], rows.dup)
  scene.on_choose = lambda { list.index = 0; list.update }
  scene.pbChoosePokemon(false)
  eq "dropped again, the row loses the mark", SpeakCapture.lines, [rows[0]]
end

Suite.define("battle swap: the same red anywhere else is not a mark") do
  red = "<c3=E82010,F8A8B8>"
  chosen = PokeAccess::I18n.t(:swap_chosen)
  scene = BattleSwapScene.new([red + "Charmander - Lagartija Pokemon"], [0])
  other = Window_AdvancedCommandPokemonEx.new([red + "Rojo"])

  scene.on_choose = lambda { other.update }
  scene.pbChoosePokemon(false)
  eq "another window of the class, while the list loop runs, reads plain", SpeakCapture.lines, ["Rojo"]

  eq "and the rented list itself, once its loop has returned, is not watched",
     PokeAccess::Menus.focused_text(scene.list), red + "Charmander - Lagartija Pokemon"
  truthy "so nothing outside the loop is marked", !PokeAccess::Menus.focused_text(scene.list).include?(chosen)
end

# The screen's title and its help line are windows of text beside the list: the title once, as the list first opens,
# and each new help line after the row read that follows it, as the prompt changes from choice to choice.
Suite.define("battle swap: the title once, and each new help line after the row that follows it") do
  rows = ["Pikachu - Raton Pokemon", "Bulbasaur - Semilla Pokemon"]
  chosen = PokeAccess::I18n.t(:swap_chosen)
  box = Struct.new(:text)
  scene = BattleSwapScene.new(rows.dup, [])
  sprites = scene.instance_variable_get(:@sprites)
  sprites["title"] = box.new("RENTAL POKéMON")
  sprites["help"] = box.new("Choose the first Pokémon.")
  list = scene.list

  scene.on_choose = lambda { list.update }
  scene.pbChoosePokemon(false)
  eq "the title, then the focused row and the prompt, queued", SpeakCapture.log,
     [["RENTAL POKéMON", false], ["#{rows[0]}. Choose the first Pokémon.", false]]

  SpeakCapture.clear
  scene.on_choose = lambda { list.index = 1; list.update }
  scene.pbChoosePokemon(false)
  eq "a move on the same prompt says the row alone", SpeakCapture.lines, [rows[1]]

  SpeakCapture.clear
  sprites["help"].text = "Choose the second Pokémon."
  scene.pbUpdateChoices([1], [rows[0], "<c3=E82010,F8A8B8>" + rows[1]])
  scene.pbChoosePokemon(false)
  eq "after renting, the row with its mark and the new prompt", SpeakCapture.lines,
     ["#{rows[1]}, #{chosen}. Choose the second Pokémon."]
end

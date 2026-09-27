# pbShowCommands' message, written into its own text window, is read before the answers (a before-hook, since the
# method blocks until the player answers); a plain message reads as before.
Suite.define("screen messages: the question that comes with a Yes/No is read before the answers") do
  scene = PokemonStorageScene.new

  SpeakCapture.clear
  scene.pbShowCommands("¿Quieres soltar a Chispa?", ["Si", "No"])
  eq "the question is spoken", SpeakCapture.lines, ["¿Quieres soltar a Chispa?"]

  falsy"and the reader is not registered on the after side of a blocking method",
        PokeAccess::Hooks.suppressed.any? { |p| p =~ /pbShowCommands/ }

  SpeakCapture.clear
  scene.pbDisplay("Se ha depositado a Chispa.")
  eq "and a plain message still reads as before", SpeakCapture.lines, ["Se ha depositado a Chispa."]
end

# pbShowCommands handed the command list first and no message (the summary's action menu, the frontier swap screen)
# recites nothing, and the repeat key keeps the last real line.
Suite.define("screen messages: a command list handed first is not read as if it were the question") do
  scene = PokemonSummaryScene.new
  PokeAccess.say_dialogue("Se ha depositado a Chispa.")

  SpeakCapture.clear
  scene.pbShowCommands(["Dar objeto", "Quitar objeto", "Ver Pokedex", "Marcar", "Cancelar"])
  silent "the list is the command window's to name, not a message"
  eq "and the repeat key still holds the last real line", PokeAccess.last_dialogue, "Se ha depositado a Chispa."
end

# The PC's cursor mode, shown only by the arrow's colour, is said as it changes: normal, quick swap, or a plugin's
# multi-select, which wins over quick swap.
Suite.define("pc storage: the cursor mode is spoken, because nothing else says which one is on") do
  sm = PokeAccess::StorageModes
  scene = Object.new

  SpeakCapture.clear
  sm.say(scene)
  eq "with nothing set it is the normal mode", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_mode_normal)]

  scene.instance_variable_set(:@quickswap, true)
  SpeakCapture.clear
  sm.say(scene)
  eq "quick swap says so", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_mode_quick)]
  truthy "and it interrupts, because it answers the key just pressed", SpeakCapture.log.last[1]

  SpeakCapture.clear
  sm.say(scene)
  silent "the same mode announced again says nothing"

  scene.instance_variable_set(:@multi, true)
  SpeakCapture.clear
  sm.say(scene)
  eq "multi-select is named even with quick swap still set", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_mode_multi)]

  scene.instance_variable_set(:@multi, false)
  scene.instance_variable_set(:@quickswap, false)
  SpeakCapture.clear
  sm.say(scene)
  eq "and coming back round says normal again", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_mode_normal)]
end

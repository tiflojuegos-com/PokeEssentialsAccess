# The QUESTION half of a question. pbShowCommands writes its message into a standing text window of its own
# and then puts up a command window with the answers: the answers were read by the generic command reader
# and the message by nobody, so "Yes / No" reached the player with nothing in front of it.
#
# It is on the PC screen and the bag in all fifteen surveyed games, and on the party and the summary in ten
# -- "Release this Pokémon?", "Throw away this item?" -- every one of them a question the player was
# answering blind.
Suite.define("screen messages: the question that comes with a Yes/No is read before the answers") do
  scene = PokemonStorageScene.new

  SpeakCapture.clear
  scene.pbShowCommands("¿Quieres soltar a Chispa?", ["Si", "No"])
  eq "the question is spoken", SpeakCapture.lines, ["¿Quieres soltar a Chispa?"]

  # It has to be a BEFORE hook: the real method runs its own loop and does not return until the player has
  # answered, so an after-hook would say the question once the choice was already made.
  falsy "and the reader is not registered on the after side of a blocking method",
        PokeAccess::Hooks.suppressed.any? { |p| p =~ /pbShowCommands/ }

  SpeakCapture.clear
  scene.pbDisplay("Se ha depositado a Chispa.")
  eq "and a plain message still reads as before", SpeakCapture.lines, ["Se ha depositado a Chispa."]
end

# The other shape of pbShowCommands: the summary's action menu (Awakening among the gen-6 games, and all
# eight modern ones) and the frontier swap screen take the command LIST first and no message at all. args[0]
# is an Array there, and 1.8.7's Array#to_s joins it into one word -- "Dar objetoQuitar objetoVer Pokedex" --
# spoken before the command reader named the focused row, and parked as the last dialogue for the repeat key.
Suite.define("screen messages: a command list handed first is not read as if it were the question") do
  scene = PokemonSummaryScene.new
  PokeAccess.say_dialogue("Se ha depositado a Chispa.")

  SpeakCapture.clear
  scene.pbShowCommands(["Dar objeto", "Quitar objeto", "Ver Pokedex", "Marcar", "Cancelar"])
  silent "the list is the command window's to name, not a message"
  eq "and the repeat key still holds the last real line", PokeAccess.last_dialogue, "Se ha depositado a Chispa."
end

# The PC's cursor MODE, which changes what every button press does next and is shown by nothing but the
# colour of the arrow. Nine of the fifteen games have the key: eight toggle quick swap, and the plugin one
# game installs cycles a third, multi-select, where confirm marks pokemon for a mass release instead of
# moving them. Pressing the key told the player nothing at all.
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

  # The three-mode cycle of the plugin: multi wins over quick swap, which is the order the arrow paints.
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

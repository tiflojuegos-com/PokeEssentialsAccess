# The modern half of screen_question_spec.rb's command-list case: PokemonSummary_Scene#pbShowCommands takes the list
# first and no message, so nothing is recited and the last dialogue stays.
Suite.define("screen messages: the summary's action menu is not recited as a message") do
  scene = PokemonSummary_Scene.new
  PokeAccess.say_dialogue("Chispa was deposited.")

  SpeakCapture.clear
  scene.pbShowCommands(["Give item", "Take item", "View Pokedex", "Mark", "Cancel"])
  silent "the list is the command window's to name"
  eq "and the last dialogue is untouched", PokeAccess.last_dialogue, "Chispa was deposited."
end

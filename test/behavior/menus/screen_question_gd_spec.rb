# The modern half of the command-list case in screen_question_spec.rb: PokemonSummary_Scene#pbShowCommands
# takes the command list first and no message in every game with that class, the eight modern ones and
# Awakening (anil/303_UI_Summary.rb:268). There args[0].to_s is the inspected Array, recited whole before
# the focused row, and parked as the last dialogue for the repeat key.
Suite.define("screen messages: the summary's action menu is not recited as a message") do
  scene = PokemonSummary_Scene.new
  PokeAccess.say_dialogue("Chispa was deposited.")

  SpeakCapture.clear
  scene.pbShowCommands(["Give item", "Take item", "View Pokedex", "Mark", "Cancel"])
  silent "the list is the command window's to name"
  eq "and the last dialogue is untouched", PokeAccess.last_dialogue, "Chispa was deposited."
end

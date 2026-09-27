# The hatch scene under its modern name (the GameData engine) queues the shiny word after the next line of dialogue,
# once, and only for a shiny hatchling.
Suite.define("hatch (gamedata): a shiny hatchling is said after the hatch line, once") do
  t = PokeAccess::I18n
  SpeakCapture.clear
  eq "the scene keeps its own return", PokemonEggHatch_Scene.new(Poke.build(:name => "Pichu", :shiny => true)).pbMain, :hatched
  PokeAccess.say_dialogue("Pichu salio del Huevo!")
  PokeAccess.say_dialogue("Quieres ponerle un mote?")
  eq "the word right after the hatch line, and not after the next", SpeakCapture.lines,
     ["Pichu salio del Huevo!", t.t(:pk_shiny_hatch), "Quieres ponerle un mote?"]

  SpeakCapture.clear
  PokemonEggHatch_Scene.new(Poke.build(:name => "Togepi")).pbMain
  PokeAccess.say_dialogue("Togepi salio del Huevo!")
  eq "a hatchling of the usual colours adds nothing", SpeakCapture.lines, ["Togepi salio del Huevo!"]
end

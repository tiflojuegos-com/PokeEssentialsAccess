# The hatch scene queues the shiny word after the next line of dialogue, once, and only for a shiny hatchling.
Suite.define("hatch: a shiny hatchling is said after the hatch line, once") do
  t = PokeAccess::I18n
  SpeakCapture.clear
  eq "the scene keeps its own return", PokemonEggHatchScene.new(Poke.build(:name => "Pichu", :shiny => true)).pbMain, :hatched
  PokeAccess.say_dialogue("Pichu salio del Huevo!")
  PokeAccess.say_dialogue("Quieres ponerle un mote?")
  eq "the word right after the hatch line, and not after the next", SpeakCapture.lines,
     ["Pichu salio del Huevo!", t.t(:pk_shiny_hatch), "Quieres ponerle un mote?"]

  SpeakCapture.clear
  PokemonEggHatchScene.new(Poke.build(:name => "Pichu")).pbMain
  PokeAccess.say_dialogue("Pichu salio del Huevo!")
  eq "a hatchling of the usual colours adds nothing", SpeakCapture.lines, ["Pichu salio del Huevo!"]
end

# The same gen-6 engine with the scene named the v17 way (Soulstones, Awakening).
Suite.define("hatch: the scene named the v17 way on the gen-6 engine says it too") do
  SpeakCapture.clear
  eq "the v17 scene keeps its own return",
     PokemonEggHatch_Scene.new(Poke.build(:name => "Togepi", :shiny => true)).pbMain, :hatched_v17
  PokeAccess.say_dialogue("Togepi salio del Huevo!")
  eq "the word right after its hatch line", SpeakCapture.lines,
     ["Togepi salio del Huevo!", PokeAccess::I18n.t(:pk_shiny_hatch)]
end

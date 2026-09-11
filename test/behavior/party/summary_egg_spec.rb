# The summary of an EGG, on the gen-6 spelling. Its twin summary_egg_gd_spec.rb covers the modern one.
#
# The mod used to read that page as if it were a hatched pokemon: species, types and ability -- none of
# which the page paints, and the species is precisely what the screen keeps from the player until it
# hatches. It is the mod asserting what the screen denies, and spoiling the game while doing it.
#
# What the page really paints is the trainer memo, the item, where the egg came from and how close it is to
# hatching. The last two are the only thing anyone opens that page for, and both are drawn as a formatted
# paragraph, which the capture had no ear for until now.
#
# Driven through drawPageOne, the way five of the seven gen-6 games reach the egg page (Reminiscencia redraws
# page one without an egg branch and reads it through its own profile). The dispatcher's after-hook runs
# its original under the reentrancy guard, so the egg page's own hook is skipped there and the take lives
# with the dispatcher -- a spec that called the egg page directly kept passing while the reader was dead in
# those five. Awakening goes to the egg page directly, and is the suite below.
Suite.define("summary: an egg reads what its own page paints, and never its species") do
  scene = PokemonSummaryScene.new
  egg = Poke.build(:name => "Huevo")
  def egg.egg?; true; end

  SpeakCapture.clear
  scene.drawPageOne(egg)
  eq "the memo, where it came from and the hatch state, as painted", SpeakCapture.lines,
     ["TRAINER MEMO, Item, Ninguno, Un Huevo misterioso recibido en Ciudad Verde. Parece que tardara mucho en eclosionar."]
  falsy "and not one word about what is inside", SpeakCapture.lines.first =~ /Bulbasaur|Planta|Especie/

  truthy "the egg page's own hook is dropped as nested under the dispatcher, which keeps the page to once",
         PokeAccess::Hooks.suppressed.any? { |p| p =~ /drawPageOne>.*drawPageOneEgg/ }

  SpeakCapture.clear
  scene.drawPageOne(egg)
  silent "the same page drawn again says nothing"

  SpeakCapture.clear
  scene.drawPageOne(Poke.build(:name => "Chispa"))
  truthy "and a hatched one goes back to the full sheet", SpeakCapture.lines.join(" ") =~ /Chispa/
end

Suite.define("summary: the egg page is spoken once, not once by each reader") do
  egg = Poke.build(:name => "Huevo")
  def egg.egg?; true; end

  eq "the page-one composer stands down for an egg",
     PokeAccess::SummaryGameData.legacy_page_text(egg, 1), nil
  truthy "but still answers for a hatched one",
         PokeAccess::SummaryGameData.legacy_page_text(Poke.build(:name => "Chispa"), 1)
  truthy "and Summary.egg? knows both spellings of the question", PokeAccess::Summary.egg?(egg)
  falsy "a pokemon that is not an egg is not one", PokeAccess::Summary.egg?(Poke.build)
  falsy "and neither is nothing at all", PokeAccess::Summary.egg?(nil)
end

# Awakening's drawPage draws an egg through drawPageOneEgg and returns, never calling
# drawPageOne (awakening/0152 PScreen_Summary.rb:284-287), so the take on drawPageOne never ran there and the
# page said nothing. The dispatcher's before-hook still arms the capture, and the egg page's own hook, not
# nested this time, takes it. Its egg page takes no argument: the Pokemon is the scene's.
Suite.define("summary: an egg page reached without drawPageOne is still read") do
  scene = PokemonSummaryScene.new
  egg = Poke.build(:name => "Huevo")
  def egg.egg?; true; end
  scene.pokemon = egg

  SpeakCapture.clear
  PokeAccess::PaintCapture.arm(:summary_egg)
  scene.drawPageOneEgg
  eq "the page is read from its own hook", SpeakCapture.lines,
     ["TRAINER MEMO, Item, Ninguno, Un Huevo misterioso recibido en Ciudad Verde. Parece que tardara mucho en eclosionar."]

  SpeakCapture.clear
  PokeAccess::PaintCapture.arm(:summary_egg)
  scene.drawPageOneEgg
  silent "and a redraw of the same page says nothing"
end

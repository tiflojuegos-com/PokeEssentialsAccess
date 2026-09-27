# The gen-6 egg page (the modern one is summary_egg_gd_spec.rb): what it paints, never the species inside. Reached
# through drawPageOne, whose hook reads it; the egg page's own hook is suppressed there as nested.
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

# A drawPage that reaches drawPageOneEgg without drawPageOne (Awakening): the dispatcher's before-hook arms the
# capture and the egg page's own hook, not nested this time, takes it; the Pokemon is the scene's.
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

# Pages four and five take no capture (Awakening arms it on every drawPage), so what they left armed must not reach
# the next egg page.
Suite.define("summary: a page drawn before leaves nothing in the next egg page") do
  scene = PokemonSummaryScene.new
  egg = Poke.build(:name => "Huevo")
  def egg.egg?; true; end
  scene.pokemon = Poke.build(:name => "Chispa")
  scene.drawPage(4)
  pbDrawTextPositions(nil, [["MOVIMIENTOS", 0, 0]])
  scene.pokemon = egg
  SpeakCapture.clear
  scene.drawPage(1)
  truthy "the egg page is read", SpeakCapture.lines.join(" ").include?("Huevo misterioso")
  falsy "without the moves page drawn before it", SpeakCapture.lines.join(" ").include?("MOVIMIENTOS")
end

# A game whose summary is one redrawn page (Reminiscencia) reads it through its own profile, the egg included:
# the shared egg reader stands down for the egg too, and still takes its capture so it does not stay armed.
Suite.define("summary: a single-page summary leaves the egg to its own reader too") do
  scene = PokemonSummaryScene.new
  egg = Poke.build(:name => "Huevo")
  def egg.egg?; true; end
  had = PokeAccess::Summary.single_page
  begin
    PokeAccess::Summary.single_page = true
    SpeakCapture.clear
    scene.drawPageOne(egg)
    silent "nothing of the shared readers is said"
    falsy "and the egg page's capture is not left armed", PokeAccess::PaintCapture.pending?(:summary_egg)
  ensure
    PokeAccess::Summary.single_page = had
  end
end

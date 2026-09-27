# The modern egg page: drawPage takes the egg branch first and is after-hooked by the page reader, so a hook on
# drawPageOneEgg would be suppressed as nested.
Suite.define("summary: the modern egg page reads what it paints, and the page reader still reads the rest") do
  scene = PokemonSummary_Scene.new
  egg = Poke.build(:name => "Egg")
  def egg.egg?; true; end

  SpeakCapture.clear
  scene.pbStartScene([egg], 0)
  eq "opening on an egg reads the memo, the item and the hatch paragraph", SpeakCapture.lines,
     ["TRAINER MEMO, Item, None, A mysterious Egg obtained in Viridian City. It looks like it will take a long time to hatch."]
  falsy "and never the species", SpeakCapture.lines.first =~ /Bulbasaur|Grass|Especie/
  falsy "the reader is not suppressed as a nested hook",
        PokeAccess::Hooks.suppressed.any? { |p| p =~ /drawPageOneEgg/ }

  SpeakCapture.clear
  scene.drawPage(1)
  silent "a redraw of the same egg page says nothing"

  SpeakCapture.clear
  scene.pbStartScene([Poke.build(:name => "Chispa")], 0)
  truthy "and a hatched pokemon gets the ordinary page reader", !SpeakCapture.lines.empty?
end

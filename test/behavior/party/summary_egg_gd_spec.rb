# The modern half of summary_egg_spec.rb, and the half that had no spec at all: PokemonSummary_Scene is the
# summary of NINE of the fifteen surveyed games, and there was no stand-in for it in this pass, so every
# hook in core/party/v21/summary_v21.rb bound to nothing and the whole reader went unexercised.
#
# Here the dispatcher is drawPage, which takes the egg branch before anything else
# (emerald/298_UI_Summary.rb:303-307), and drawPage is the method the page reader after-hooks -- so a hook
# on drawPageOneEgg was swallowed by the reentrancy guard and the page said nothing.
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

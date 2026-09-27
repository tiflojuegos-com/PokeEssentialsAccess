# The modern summary's ribbon cursor: drawSelectedRibbon gets the ribbon id in vanilla, and (filter, index, page,
# maxpage) under the Improved Mementos plugin.
Suite.define("summary: the focused ribbon is read, in either shape of the redraw") do
  scene = PokemonSummary_Scene.new

  SpeakCapture.clear
  scene.drawSelectedRibbon(3)
  eq "vanilla passes the id: name and description", SpeakCapture.lines, ["Ribbon3. rdesc3"]

  SpeakCapture.clear
  scene.drawSelectedRibbon([:ALERT, :SHOCK, :DOWNCAST], 1, 0, 1)
  eq "the paged grid resolves the focused entry of its filter", SpeakCapture.lines, ["RibbonSHOCK. rdescSHOCK"]

  SpeakCapture.clear
  scene.drawSelectedRibbon(nil)
  eq "an empty cell says it is empty", SpeakCapture.lines, [PokeAccess::I18n.t(:rb_empty)]
end

# The ribbon cursor of the modern summary: drawSelectedRibbon runs once per cursor move over the focused
# ribbon, with the id itself in vanilla and (filter, index, page, maxpage) under the Improved Mementos plugin,
# whose whole filter Array handed to GameData::Ribbon.get raised into a rescue and left the page silent.
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
  silent "an empty slot says nothing"
end

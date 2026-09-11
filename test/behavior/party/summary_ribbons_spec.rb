# The ribbon cursor of the gen-6 summary. Six of the seven gen-6 games paint the ribbons page static, and
# the reader said so of all seven; Awakening keeps a cursor over it and redraws the focused ribbon through
# drawSelectedRibbon over PBRibbons (awakening/0152 PScreen_Summary.rb:932), the way the modern page does
# over GameData::Ribbon. The modern half is summary_ribbons_gd_spec.rb.
Suite.define("summary: the focused ribbon is read on the gen-6 game that keeps a ribbon cursor") do
  scene = PokemonSummaryScene.new

  SpeakCapture.clear
  scene.drawSelectedRibbon(2)
  eq "name and description, from PBRibbons", SpeakCapture.lines, ["Cinta2. Descripcion2"]

  SpeakCapture.clear
  scene.drawSelectedRibbon(nil)
  silent "an empty slot says nothing"

  eq "the modern lookup is tried first and the gen-6 one answers where it is absent",
     PokeAccess::Summary.ribbon_text(7), "Cinta7. Descripcion7"
end

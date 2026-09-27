# The SV Summary Screen's item and ability panels, stubbed as the game paints them (Close, title and name, then
# the description) with their loop's first frame; the reader is loaded again over them, since hooks bind at load.
class PokemonSummary_Scene
  def pbItemPrompt
    pbDrawTextPositions(nil, [["Cerrar", 272, 280]])
    pbDrawTextPositions(nil, [["Objeto Equipado", 232, 86], ["Baya Zidra", 232, 118]])
    drawTextEx(nil, 50, 152, 416, 4, "Restaura PS cuando quedan pocos.")
    Input.update
    :closed
  end

  def pbAbilityPrompt
    pbDrawTextPositions(nil, [["Cerrar", 272, 280]])
    pbDrawTextPositions(nil, [["Habilidad", 256, 86], ["Electricidad Estatica", 256, 118]])
    drawTextEx(nil, 50, 152, 416, 4, "Puede paralizar al contacto.")
    Input.update
    :closed
  end
end
eval(File.read(File.join(Harness::ROOT, "plugins", "sv_summary_prompts.rb")),
     TOPLEVEL_BINDING, File.join(Harness::ROOT, "plugins", "sv_summary_prompts.rb"))

Suite.define("sv summary: the item and ability panels say what they paint on the way in") do
  scene = PokemonSummary_Scene.new(Poke.build(:name => "Chispa"))
  SpeakCapture.clear
  eq "the item panel keeps its own return", scene.pbItemPrompt, :closed
  eq "its title, the item and its description, then the Close hint, interrupting", SpeakCapture.log,
     [["Objeto Equipado. Baya Zidra. Restaura PS cuando quedan pocos. Cerrar", true]]

  SpeakCapture.clear
  scene.pbAbilityPrompt
  eq "the ability panel the same way", SpeakCapture.lines,
     ["Habilidad. Electricidad Estatica. Puede paralizar al contacto. Cerrar"]

  SpeakCapture.clear
  Input.update
  silent "and the frames after it say nothing"
end

Suite.define("sv summary: the panels' Close hint is left out with the hints") do
  scene = PokemonSummary_Scene.new(Poke.build(:name => "Chispa"))
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    scene.pbItemPrompt
    eq "brief: the panel without its key", SpeakCapture.lines, ["Objeto Equipado. Baya Zidra. Restaura PS cuando quedan pocos."]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

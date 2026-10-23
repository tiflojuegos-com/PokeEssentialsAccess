# The SV Summary Screen's item and ability panels say what they paint on their loop's first frame: title, name and
# description, then the Close button; the reader is loaded again over the panels stubbed here, as hooks bind at load.
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
sv_prompts = File.join(Harness::ROOT, "plugins", "sv_summary_prompts.rb")
eval(Harness.source(sv_prompts), TOPLEVEL_BINDING, sv_prompts)

class SvSummaryPromptsGdTest < PokeAccessTest
  test "the item panel says its title, the item and its description, then the Close button, interrupting" do
    scene.pbItemPrompt
    assert_equal [["Objeto Equipado. Baya Zidra. Restaura PS cuando quedan pocos. Cerrar", true]], SpeakCapture.log
  end

  test "the ability panel says its title, the ability and its description, then the Close button" do
    scene.pbAbilityPrompt
    assert_equal [["Habilidad. Electricidad Estatica. Puede paralizar al contacto. Cerrar", true]], SpeakCapture.log
  end

  test "with the hints left out, the Close button is left out" do
    PokeAccess::Config.verbosity = :brief
    scene.pbItemPrompt
    assert_equal [["Objeto Equipado. Baya Zidra. Restaura PS cuando quedan pocos.", true]], SpeakCapture.log
  end

  test "the frames after the panel's first say nothing" do
    scene.pbItemPrompt
    SpeakCapture.clear
    Input.update
    assert_nothing_spoken
  end

  test "a panel that paints nothing says nothing" do
    PokeAccess::SVSummaryPrompts.arm
    Input.update
    assert_nothing_spoken
  end

  test "the panels return what the game's do" do
    assert_equal [:closed, :closed], [scene.pbItemPrompt, scene.pbAbilityPrompt]
  end

  private

  def scene
    PokemonSummary_Scene.new(Poke.build(:name => "Chispa"))
  end
end

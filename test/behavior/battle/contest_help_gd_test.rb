# The Bug-Catching Contest's comparison on the GameData engine (core/battle/contest_help.rb), the help window of
# Battle::Scene#pbShowHelp: the file is evaluated again over the stand-in below so its hook binds.

# The help window as far as the reader goes: the text it is given.
class Battle::Scene
  attr_reader :help

  def pbShowHelp(text)
    @help = text
  end
end

contest = File.join(Harness::ROOT, "core", "battle", "contest_help.rb")
eval(Harness.source(contest), TOPLEVEL_BINDING, contest)

class ContestHelpGdTest < PokeAccessTest
  COMPARISON = "Pokémon guardado:\nVenonat Nv.12 PS Máx.: 34\nEste Pokémon:\nCaterpie Nv.10 PS Máx.: 30".freeze

  test "the comparison is said between the catch's line and the question, each heading joined to its Pokemon" do
    PokeAccess.say_dialogue("Ya has capturado un Venonat.")
    Battle::Scene.new.pbShowHelp(COMPARISON)
    PokeAccess.say_dialogue("¿Cambiar de Pokémon?")
    assert_equal [["Ya has capturado un Venonat.", false],
                  ["Pokémon guardado: Venonat Nv.12 PS Máx.: 34, Este Pokémon: Caterpie Nv.10 PS Máx.: 30", false],
                  ["¿Cambiar de Pokémon?", false]], SpeakCapture.log
  end

  test "the window still gets its text from the game" do
    scene = Battle::Scene.new
    scene.pbShowHelp(COMPARISON)
    assert_equal COMPARISON, scene.help
  end
end

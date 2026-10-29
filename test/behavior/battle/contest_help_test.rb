# The Bug-Catching Contest's comparison on the gen-6 engine (core/battle/contest_help.rb), the help window of
# PokeBattle_Scene#pbShowHelp: the stand-in below holds that name only while the file is evaluated again, so the hook
# binds to it and no other test sees a battle scene.

# The help window as far as the reader goes: the text it is given.
class ContestHelpG6Scene
  attr_reader :help

  def pbShowHelp(text)
    @help = text
  end
end

contest_made = !Object.const_defined?(:PokeBattle_Scene)
Object.const_set(:PokeBattle_Scene, ContestHelpG6Scene) if contest_made
begin
  contest = File.join(Harness::ROOT, "core", "battle", "contest_help.rb")
  eval(Harness.source(contest), TOPLEVEL_BINDING, contest)
ensure
  Object.send(:remove_const, :PokeBattle_Scene) if contest_made
end

class ContestHelpTest < PokeAccessTest
  COMPARISON = "POKéMON ANTERIOR:\n Venonat Nv12 MáxPS: 34\nESTE POKÉMON:\n Caterpie Nv10 MáxPS: 30".freeze

  test "the comparison is said between the catch's line and the question, each heading joined to its Pokemon" do
    PokeAccess.say_dialogue("Ya has capturado un Venonat.")
    ContestHelpG6Scene.new.pbShowHelp(COMPARISON)
    PokeAccess.say_dialogue("¿Cambiar de Pokémon?")
    assert_equal [["Ya has capturado un Venonat.", false],
                  ["POKéMON ANTERIOR: Venonat Nv12 MáxPS: 34, ESTE POKÉMON: Caterpie Nv10 MáxPS: 30", false],
                  ["¿Cambiar de Pokémon?", false]], SpeakCapture.log
  end

  test "the window still gets its text from the game" do
    scene = ContestHelpG6Scene.new
    scene.pbShowHelp(COMPARISON)
    assert_equal COMPARISON, scene.help
  end

  test "an empty help window says nothing" do
    ["", "\n", nil].each { |text| ContestHelpG6Scene.new.pbShowHelp(text) }
    assert_nothing_spoken
  end
end

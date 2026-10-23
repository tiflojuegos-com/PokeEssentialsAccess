# The hatch scene's shiny word on the GameData engine: a shiny hatchling is said right after the next dialogue line,
# once; a hatchling of the usual colours adds nothing.
class HatchShinyGdTest < PokeAccessTest
  test "a shiny hatchling's word follows the hatch line, and only that one" do
    hatching(Poke.build(:name => "Pichu", :shiny => true)) do
      PokeAccess.say_dialogue("¡Pichu salió del Huevo!")
      PokeAccess.say_dialogue("¿Quieres ponerle un mote a Pichu?")
    end
    assert_equal [["¡Pichu salió del Huevo!", false], [PokeAccess::I18n.t(:pk_shiny_hatch), false],
                  ["¿Quieres ponerle un mote a Pichu?", false]],
                 SpeakCapture.log,
                 "the word queued right after the hatch line, and not after the next"
  end

  test "a hatchling of the usual colours adds nothing" do
    hatching(Poke.build(:name => "Togepi")) { PokeAccess.say_dialogue("¡Togepi salió del Huevo!") }
    assert_equal [["¡Togepi salió del Huevo!", false]], SpeakCapture.log
  end

  test "the scene keeps its own result" do
    assert_equal :hatched, hatching(Poke.build(:name => "Eevee", :shiny => true)) { nil }
  end

  private

  # The result of the hatch scene's pbMain for pokemon, the block then run as the lines the game says after it; a word
  # still promised when the block ends is dropped.
  def hatching(pokemon)
    result = PokemonEggHatch_Scene.new(pokemon).pbMain
    yield
    result
  ensure
    PokeAccess.after_next_line(nil)
  end
end

# The hatch scene's shiny word on the gen-6 engine, under both of its spellings: a shiny hatchling is said right after
# the next dialogue line, once; a hatchling of the usual colours adds nothing.
class HatchShinyTest < PokeAccessTest
  test "a shiny hatchling's word follows the hatch line, and only that one" do
    hatching(PokemonEggHatchScene, Poke.build(:name => "Pichu", :shiny => true)) do
      PokeAccess.say_dialogue("¡Pichu salió del Huevo!")
      PokeAccess.say_dialogue("¿Quieres ponerle un mote a Pichu?")
    end
    assert_equal [["¡Pichu salió del Huevo!", false], [PokeAccess::I18n.t(:pk_shiny_hatch), false],
                  ["¿Quieres ponerle un mote a Pichu?", false]],
                 SpeakCapture.log,
                 "the word queued right after the hatch line, and not after the next"
  end

  test "a hatchling of the usual colours adds nothing" do
    hatching(PokemonEggHatchScene, Poke.build(:name => "Togepi")) do
      PokeAccess.say_dialogue("¡Togepi salió del Huevo!")
    end
    assert_equal [["¡Togepi salió del Huevo!", false]], SpeakCapture.log
  end

  test "the scene named the v17 way says it too" do
    hatching(PokemonEggHatch_Scene, Poke.build(:name => "Riolu", :shiny => true)) do
      PokeAccess.say_dialogue("¡Riolu salió del Huevo!")
    end
    assert_equal [["¡Riolu salió del Huevo!", false], [PokeAccess::I18n.t(:pk_shiny_hatch), false]], SpeakCapture.log
  end

  test "each spelling of the scene keeps its own result" do
    { PokemonEggHatchScene => :hatched, PokemonEggHatch_Scene => :hatched_v17 }.each do |scene, want|
      assert_equal want, hatching(scene, Poke.build(:name => "Eevee", :shiny => true)) { nil }, "for #{scene}"
    end
  end

  private

  # The result of the scene's pbMain for pokemon, the block then run as the lines the game says after it; a word still
  # promised when the block ends is dropped.
  def hatching(scene, pokemon)
    result = scene.new(pokemon).pbMain
    yield
    result
  ensure
    PokeAccess.after_next_line(nil)
  end
end

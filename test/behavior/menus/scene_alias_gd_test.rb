# Engine.era_scene on the GameData engine: a reader of either era takes its own lone name (PokeBattle_Scene in a v18
# game), a gen-6 reader never the other era's, and with both names present the GameData reader takes the ancestor.

# A screen under its ancestral name and a fork's alias of it (an empty subclass).
class PaSpecGdBase; end
class PaSpecGdAlias < PaSpecGdBase; end

class SceneAliasGdTest < PokeAccessTest
  Engine = PokeAccess::Engine

  test "the GameData stubs read as the GameData era" do
    assert_equal [:gamedata, false, true], [Engine.kind, Engine.gen6?, Engine.gamedata?]
  end

  test "a reader of either era takes its own lone name" do
    [:gamedata, :gen6].each do |era|
      assert_equal "PaSpecGdBase", Engine.era_scene(era, "PaSpecGdBase", "PaSpecGdNope"), "the #{era} reader"
    end
  end

  test "no reader takes the other era's lone name here" do
    [:gamedata, :gen6].each do |era|
      assert_equal "", Engine.era_scene(era, "PaSpecGdNope", "PaSpecGdBase"), "the #{era} reader"
    end
  end

  test "with both names in the game, the GameData reader takes the ancestor and the gen-6 one nothing" do
    { :gamedata => "PaSpecGdBase", :gen6 => "" }.each do |era, want|
      assert_equal want, Engine.era_scene(era, "PaSpecGdAlias", "PaSpecGdBase"), "the #{era} reader"
    end
  end

  test "with neither name in the game, no reader binds" do
    [:gamedata, :gen6].each do |era|
      assert_equal "", Engine.era_scene(era, "PaSpecGdNope", "PaSpecGdNeither"), "the #{era} reader"
    end
  end

  test "the GameData readers bind the GameData scenes the game has, the gen-6 readers nothing" do
    modern = [PokeAccess::SummaryV21::SCENE, PokeAccess::MoveRelearnerV21::SCENE, PokeAccess::TrainerCardV21::SCENE]
    legacy = [PokeAccess::SummaryGen6::SCENE, PokeAccess::MoveRelearnerGen6::SCENE, PokeAccess::TrainerCard::SCENE]
    assert_equal ["PokemonSummary_Scene", "", "PokemonTrainerCard_Scene"], modern,
                 "summary, relearner and trainer card of the GameData era (no relearner here)"
    assert_equal ["", "", ""], legacy, "the same of the gen-6 era"
  end
end

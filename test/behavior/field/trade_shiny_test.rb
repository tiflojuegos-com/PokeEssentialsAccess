# The trade scene's shiny word on the gen-6 engine, under both of its spellings: a shiny Pokemon arriving is said right
# after the line that names it, the first after its arrival, once; one of the usual colours, or the one sent, adds
# nothing.
class TradeShinyTest < PokeAccessTest
  test "a shiny arrival's word follows the line naming it, and only that one" do
    trading(PokemonTradeScene, Poke.build(:name => "Pinsir", :shiny => true)) do
      PokeAccess.say_dialogue("SirNoWings ID: 01234 OT: Hunter")
      PokeAccess.say_dialogue("Cuida bien de Pinsir.")
    end
    assert_equal [["SirNoWings ID: 01234 OT: Hunter", false], [PokeAccess::I18n.t(:pk_shiny_hatch), false],
                  ["Cuida bien de Pinsir.", false]],
                 SpeakCapture.log
  end

  test "an arrival of the usual colours adds nothing, though the one sent is shiny" do
    scene = PokemonTradeScene.new(Poke.build(:name => "Brillo", :shiny => true), Poke.build(:name => "Pinsir"))
    scene.pbScene2
    PokeAccess.say_dialogue("SirNoWings ID: 01234 OT: Hunter")
    assert_equal [["SirNoWings ID: 01234 OT: Hunter", false]], SpeakCapture.log
  ensure
    PokeAccess.after_next_line(nil)
  end

  test "the scene under its later name says it too, and each spelling keeps its own result" do
    result = trading(PokemonTrade_Scene, Poke.build(:name => "Pinsir", :shiny => true)) do
      PokeAccess.say_dialogue("SirNoWings ID: 01234 OT: Hunter")
    end
    assert_equal [["SirNoWings ID: 01234 OT: Hunter", false], [PokeAccess::I18n.t(:pk_shiny_hatch), false]],
                 SpeakCapture.log
    assert_equal :arrived_v19, result
  end

  private

  # The result of the scene's pbScene2 for the Pokemon received, the block then run as the lines the game says after
  # it; a word still promised when the block ends is dropped.
  def trading(scene, received)
    result = scene.new(Poke.build(:name => "Nube"), received).pbScene2
    yield
    result
  ensure
    PokeAccess.after_next_line(nil)
  end
end

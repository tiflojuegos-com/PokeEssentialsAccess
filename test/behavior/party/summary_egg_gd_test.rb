# The modern egg page (the gen-6 one is summary_egg_test.rb): drawPage takes the egg branch first, and the page reader
# says what that branch paints, once, never the species inside; a hatched Pokemon gets its data sheet.
class SummaryEggGdTest < PokeAccessTest
  # What the stub's egg page paints, joined as the reader says it.
  PAINTED = "TRAINER MEMO, Item, None, A mysterious Egg obtained in Viridian City. " \
            "It looks like it will take a long time to hatch."

  test "opening on an egg reads what its page paints: the memo, the item and the hatch paragraph" do
    PokemonSummary_Scene.new.pbStartScene([egg], 0)
    assert_equal [[PAINTED, false]], SpeakCapture.log
  end

  test "a redraw of the same egg page says nothing" do
    scene = PokemonSummary_Scene.new
    scene.pbStartScene([egg], 0)
    SpeakCapture.clear
    scene.drawPage(1)
    assert_nothing_spoken
  end

  test "an egg page that paints nothing says the egg's heading" do
    scene = PokemonSummary_Scene.new
    def scene.drawPageOneEgg; :egg_page; end
    scene.pbStartScene([egg], 0)
    assert_equal [[PokeAccess::I18n.t(:sm_egg), false]], SpeakCapture.log
  end

  test "an egg shown after another member is not named first, its page being about it" do
    scene = PokemonSummary_Scene.new
    hatched = Poke.build(:name => "Chispa")
    scene.pbStartScene([hatched, egg], 0)
    SpeakCapture.clear
    scene.pokemon = scene.party[1]
    scene.drawPage(1)
    assert_equal [[PAINTED, true]], SpeakCapture.log
  end

  test "a hatched Pokemon shown after the egg gets its data sheet" do
    scene = PokemonSummary_Scene.new
    scene.pbStartScene([egg], 0)
    SpeakCapture.clear
    hatched = Poke.build(:name => "Chispa")
    scene.pbStartScene([hatched], 0)
    assert_equal [[PokeAccess::SummaryGameData.info_text(hatched), true]], SpeakCapture.log
  end

  private

  # A Pokemon that is an egg, as the modern engine asks it.
  def egg
    pk = Poke.build(:name => "Egg")
    def pk.egg?; true; end
    pk
  end
end

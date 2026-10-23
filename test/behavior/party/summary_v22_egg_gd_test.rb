# The v22 summary's egg page (:egg_memo): where the egg came from and how close it is to hatching, as draw_egg_memo
# paints them, never the nature or the species.
class SummaryV22EggGdTest < PokeAccessTest
  test "says where the egg came from and how close it is to hatching, and no more" do
    egg_page(egg(500, :text => "Viridian City"))
    assert_equal [["#{t(:sm_met_egg)}: Viridian City. #{t(:hatch_soon)}", true]], SpeakCapture.log
  end

  test "with no place written, names the map the egg came from" do
    GameFunctions.with(:pbGetMapNameFromId => lambda { |id| "Ruta #{id}" }) do
      egg_page(egg(2000, :text => "", :map => 7))
    end
    assert_equal [["#{t(:sm_met_egg)}: Ruta 7. #{t(:hatch_close)}", true]], SpeakCapture.log
  end

  test "with no place on record, says the egg was received and how close it is" do
    egg_page(egg(20000))
    assert_equal [["#{t(:sm_met_egg)}. #{t(:hatch_far)}", true]], SpeakCapture.log
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # An egg steps from hatching, with the place the summary writes for it (:text) and the map it came from (:map) when
  # given.
  def egg(steps, where = {})
    pk = Poke.build(:name => "Huevo")
    pk.define_singleton_method(:egg?) { true }
    pk.define_singleton_method(:steps_to_hatch) { steps }
    pk.define_singleton_method(:obtain_text) { where[:text] } if where.key?(:text)
    pk.define_singleton_method(:obtain_map) { where[:map] } if where.key?(:map)
    pk
  end

  # The summary of the egg alone, turned to its egg page.
  def egg_page(pk)
    UI::PokemonSummaryVisuals.new([pk], 0).go_to_next_page(:egg_memo)
  end
end

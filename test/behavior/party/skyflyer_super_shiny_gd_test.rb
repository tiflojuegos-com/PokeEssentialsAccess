# Skyflyer's super shiny (games/skyflyer_common/super_shiny.rb, loaded by the anil profile): the shiny word of lists
# and summary and the battle box's mark say which star is painted, a super shiny's purple one or any other's red one.
class SkyflyerSuperShinyGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "the shiny word says the purple star for a super shiny and the red one for any other" do
    { "a super shiny" => [shiny(true), T.t(:pk_super_shiny)], "a plain shiny" => [shiny(false), T.t(:pk_shiny)],
      "one that knows no such tier" => [Object.new, T.t(:pk_shiny)] }.each do |what, (pk, word)|
      assert_equal word, PokeAccess::Party.shiny_word(pk), what
    end
  end

  test "the lists' icon marks say the purple star" do
    assert_equal [T.t(:pk_super_shiny)], PokeAccess::Party.icon_mark_list(shiny(true))
  end

  test "a foe whose battle box draws the purple star enters with it said, and keeps it as its mark" do
    foe = Struct.new(:index, :name, :pokemon).new(1, "Pikachu", Object.new)
    box = Battle::Scene::PokemonDataBox.new(foe)
    box.extra = %w[shiny_ur]
    box.refresh
    assert_equal [[T.t(:bt_marks_entry, :name => "Pikachu", :marks => T.t(:pk_super_shiny)), false]], SpeakCapture.log
    assert_equal [T.t(:pk_super_shiny)], PokeAccess::Battle.shown_marks(foe)
  end

  private

  # A shiny Pikachu, super shiny or not.
  def shiny(super_shiny)
    pk = Object.new
    pk.define_singleton_method(:name) { "Pikachu" }
    pk.define_singleton_method(:shiny?) { true }
    pk.define_singleton_method(:super_shiny?) { super_shiny }
    pk
  end
end

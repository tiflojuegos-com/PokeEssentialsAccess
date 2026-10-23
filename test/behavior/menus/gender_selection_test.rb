# The new-game look/gender picker (PokemonGenderSelection plugin): @select 2 is the boy, 4 the girl, 1 the neutral
# start, 3/5 the confirm step. Its FocusReader wiring is driven in plugins_smoke_test, where the class exists.

class GenderSelectionTest < PokeAccessTest
  test "names the boy and the girl, and nothing for the neutral start or the confirm step" do
    expected = { 1 => nil, 2 => PokeAccess::I18n.t(:gsel_boy), 3 => nil, 4 => PokeAccess::I18n.t(:gsel_girl),
                 5 => nil, 99 => nil }
    actual = expected.keys.inject({}) { |h, sel| h[sel] = PokeAccess::GenderSelection.label(sel); h }

    assert_equal expected, actual
  end
end

# PokedexInfoV21.entry_number: the number shown for the entry list's focused row (a Hash row or an older array row),
# one lower where the row is shifted; none for an unnumbered row or a list the scene does not have.
class PokedexEntryNumberTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21

  test "a list row's number, one lower where the row is shifted" do
    { [4, false] => 4, [4, true] => 3, [1, false] => 1, [1, true] => 0 }.each do |(number, shift), shown|
      row = { :species => :BULBASAUR, :number => number, :shift => shift }
      assert_equal shown, PDX.entry_number(scene_on([row], 0)), "number #{number}, shift #{shift}"
    end
  end

  test "an unnumbered row shows no number, shifted or not" do
    [{ :number => 0, :shift => false }, { :number => 0, :shift => true }, { :species => :MEW }].each do |row|
      assert_nil PDX.entry_number(scene_on([row], 0)), row.inspect
    end
  end

  test "an older array row gives its number, one lower where it is shifted" do
    { false => 12, true => 11, nil => 12 }.each do |shift, shown|
      assert_equal shown, PDX.entry_number(scene_on([[25, "Pikachu", 0, 0, 12, shift]], 0)), "shift #{shift.inspect}"
    end
  end

  test "the focused row is the one numbered" do
    rows = [{ :number => 4, :shift => false }, { :number => 9, :shift => false }]
    assert_equal 9, PDX.entry_number(scene_on(rows, 1))
  end

  test "no list, no focused row or a row of another shape shows no number" do
    scenes = { "no list" => Object.new, "a cursor past the list" => scene_on([{ :number => 4 }], 1),
               "no cursor" => scene_on([{ :number => 4 }], nil), "a bare species" => scene_on([:BULBASAUR], 0) }
    scenes.each { |what, scene| assert_nil PDX.entry_number(scene), what }
  end

  private

  # An entry scene on row index of its dex list.
  def scene_on(dexlist, index)
    scene = Object.new
    scene.instance_variable_set(:@dexlist, dexlist)
    scene.instance_variable_set(:@index, index)
    scene
  end
end

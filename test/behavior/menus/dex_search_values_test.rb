# The Pokedex search grid's values as the screen paints them, over the gen-6 lists whose types and shapes are bare
# numbers: each filter's current value, and each option of a filter's sub-screen with the cells below its options
# (the blank that clears the filter or lets a slider go, OK, Cancel).
class DexSearchValuesTest < PokeAccessTest
  TYPES = [0, 1, 2, 10]
  HEIGHTS = [1, 2, 3, 4, 12]
  WEIGHTS = [5, 10, 15]
  SHAPES = (0...14).to_a
  # The grid's params with no filter set: the order, then the name, two types, two heights, two weights, colour, shape.
  NONE = [0, -1, -1, -1, -1, -1, -1, -1, -1, -1]

  test "the order, the name and the colour are said as their lists show them" do
    s = search_scene
    assert_equal "Numerical", value(s, 0, 0 => 0)
    assert_equal "C", value(s, 1, 1 => 2)
    assert_equal "Blue", value(s, 5, 8 => 1)
  end

  test "a type the list keeps as a number is said by its name, and two types together" do
    s = search_scene
    assert_equal PBTypes.getName(10), value(s, 2, 2 => 3)
    assert_equal "#{PBTypes.getName(1)} - #{PBTypes.getName(10)}", value(s, 2, 2 => 1, 3 => 3)
  end

  test "a shape the list keeps as a number is said by its place among the shapes" do
    assert_equal PokeAccess::I18n.t(:list_pos, :i => 5, :n => 14), value(search_scene, 6, 9 => 4)
  end

  test "a filter with nothing set is no filter" do
    s = search_scene
    [1, 2, 3, 4, 5, 6].each { |idx| assert_equal t(:dxs_unset), value(s, idx, {}), "filter #{idx}" }
  end

  test "a height range is said as the two limits the screen paints, in metres" do
    s = search_scene
    { [3, 4] => "0.4 - 1.2",
      [-1, 4] => "0.0 - 1.2",
      [0, -1] => "0.1 - 99.9",
      [2, 0] => "0.3 - 0.1",
      [-1, 0] => "0.0 - 0.1",
      [5, -1] => "99.9 - 99.9",
      [-1, 5] => "0.0 - 0.0" }.each do |(lo, hi), want|
      assert_equal want, value(s, 3, 4 => lo, 5 => hi), "min #{lo}, max #{hi}"
    end
  end

  test "a weight range is said from its own two slots, in kilograms up to 999.9" do
    s = search_scene
    assert_equal "0.5 - 1.5", value(s, 4, 6 => 0, 7 => 2)
    assert_equal "1.0 - 999.9", value(s, 4, 6 => 1)
  end

  test "a filter set over a list the scene does not keep is said as set" do
    s = World.stub_scene(:@orderCommands => ["Numerical"])
    assert_equal t(:dxs_set), PokeAccess::DexSearch.field_value(s, 5, with(8 => 1))
    assert_equal t(:dxs_set), PokeAccess::DexSearch.field_value(s, 3, with(4 => 1))
  end

  test "a range whose slots the params lack is no filter" do
    assert_equal t(:dxs_unset), PokeAccess::DexSearch.field_value(search_scene, 3, [0])
  end

  test "a row past the filters, or params that are no list, have no value" do
    s = search_scene
    [-1, 7].each { |idx| assert_nil PokeAccess::DexSearch.field_value(s, idx, NONE), "row #{idx}" }
    assert_nil PokeAccess::DexSearch.field_value(s, 1, nil)
  end

  test "a sub-screen says its option after the filter's name, interrupting" do
    searching do
      PokeAccess::DexSearch.param(search_scene, 2, TYPES, 3)
      assert_equal [["#{t(:dxs_type)}, #{PBTypes.getName(10)}", true]], SpeakCapture.log
    end
  end

  test "a height option is said as the metres it paints, and a shape by its place" do
    searching do
      s = search_scene
      PokeAccess::DexSearch.param(s, 3, HEIGHTS, 4)
      PokeAccess::DexSearch.param(s, 6, SHAPES, 0)
      assert_equal ["#{t(:dxs_height)}, 1.2", "#{t(:dxs_shape)}, #{PokeAccess::I18n.t(:list_pos, :i => 1, :n => 14)}"],
                   SpeakCapture.lines
    end
  end

  test "below a filter's options come the blank that clears the filter, OK, then Cancel" do
    searching do
      s = search_scene
      [-1, -2, -3, -4].each { |i| PokeAccess::DexSearch.param(s, 2, TYPES, i) }
      assert_equal [:dxs_unset, :dxs_ok, :dxs_cancel, :dxs_cancel].map { |k| "#{t(:dxs_type)}, #{t(k)}" },
                   SpeakCapture.lines
    end
  end

  test "on a height or weight slider the blank lets that limit go, while OK stays OK" do
    searching do
      s = search_scene
      PokeAccess::DexSearch.param(s, 3, HEIGHTS, -1)
      PokeAccess::DexSearch.param(s, 3, HEIGHTS, -2)
      PokeAccess::DexSearch.param(s, 4, WEIGHTS, -1)
      assert_equal ["#{t(:dxs_height)}, #{t(:dxs_no_limit)}", "#{t(:dxs_height)}, #{t(:dxs_ok)}",
                    "#{t(:dxs_weight)}, #{t(:dxs_no_limit)}"],
                   SpeakCapture.lines
    end
  end

  test "a sub-screen of a filter the grid does not name says its option alone" do
    searching do
      PokeAccess::DexSearch.param(search_scene, 7, ["Kanto", "Johto"], 1)
      assert_equal [["Johto", true]], SpeakCapture.log
    end
  end

  test "an option said again is not repeated, and an option with no text or past the list is silent" do
    searching do
      s = search_scene
      2.times { PokeAccess::DexSearch.param(s, 1, ["A", "", "C"], 0) }
      PokeAccess::DexSearch.param(s, 1, ["A", "", "C"], 1)
      PokeAccess::DexSearch.param(s, 1, ["A", "", "C"], 5)
      assert_equal ["#{t(:dxs_name)}, A"], SpeakCapture.lines
    end
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end

  # A search scene with the lists pbDexSearch builds on the gen-6 era, shortened.
  def search_scene
    World.stub_scene(:@orderCommands => ["Numerical"], :@nameCommands => %w[A B C], :@typeCommands => TYPES,
                     :@heightCommands => HEIGHTS, :@weightCommands => WEIGHTS, :@colorCommands => %w[Red Blue],
                     :@shapeCommands => SHAPES)
  end

  # NONE with the given slots set.
  def with(slots)
    params = NONE.dup
    slots.each { |i, v| params[i] = v }
    params
  end

  # Filter idx's value with the given slots of the params set.
  def value(scene, idx, slots)
    PokeAccess::DexSearch.field_value(scene, idx, with(slots))
  end

  # Runs the block with the search forgotten afterwards, as its closing does.
  def searching
    yield
  ensure
    PokeAccess::DexSearch.close
  end
end

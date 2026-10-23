# The Pokedex search grid, read through its own redraws and the cursor sprite's moves: each filter with its value and
# each button, a filter's sub-screen option by option, nothing once the search closes. Gamedata pass.
class DexSearchGdTest < PokeAccessTest
  test "opening the search says the first row with its value, then each row the cursor moves to" do
    scene = PokemonPokedex_Scene.new
    assert_equal :searched, scene.pbDexSearch([1]), "the search keeps its own return"
    assert_equal [["#{t(:dxs_order)}, Numerical", true], ["#{t(:dxs_name)}, B", true]], SpeakCapture.log
  end

  test "the buttons below the filters are said by their names" do
    PokemonPokedex_Scene.new.pbDexSearch([7, 8, 9])
    assert_equal ["#{t(:dxs_order)}, Numerical", t(:dxs_clear), t(:dxs_search), t(:dxs_cancel)], SpeakCapture.lines
  end

  test "a cursor on no row of the grid says nothing" do
    scene = PokemonPokedex_Scene.new
    scene.pbDexSearch([10])
    assert_equal ["#{t(:dxs_order)}, Numerical"], SpeakCapture.lines
  end

  test "opening the search again on the same row says it again" do
    scene = PokemonPokedex_Scene.new
    2.times { scene.pbDexSearch }
    assert_equal ["#{t(:dxs_order)}, Numerical"] * 2, SpeakCapture.lines
  end

  test "once the search closes, neither the grid's cursor nor a filter's says anything" do
    scene = PokemonPokedex_Scene.new
    scene.pbRefreshDexSearchParam(1, ["A", "B"], [0], 0)
    scene.pbDexSearch
    SpeakCapture.clear
    cursor = PokedexSearchSelectionSprite.new
    cursor.index = 3
    cursor.mode = 1
    cursor.index = 1
    assert_nothing_spoken
  end

  test "a repaint under the same cursor says the row again only when its value changed" do
    scene = searching_scene
    searching do
      scene.pbRefreshDexSearch([0, 0, -1, -1, -1, -1, -1, -1, -1, -1], 1)
      scene.pbRefreshDexSearch([0, 0, -1, -1, -1, -1, -1, -1, -1, -1], 1)
      scene.pbRefreshDexSearch([0, 1, -1, -1, -1, -1, -1, -1, -1, -1], 1)
      assert_equal ["#{t(:dxs_name)}, A", "#{t(:dxs_name)}, B"], SpeakCapture.lines
    end
  end

  test "a filter's sub-screen says its option on the repaint, then each cell its cursor moves to" do
    scene = PokemonPokedex_Scene.new
    cursor = PokedexSearchSelectionSprite.new
    searching do
      assert_equal [1, 0], scene.pbRefreshDexSearchParam(1, ["A", "B", "C"], [0], 0), "the repaint keeps its return"
      cursor.mode = 1
      [2, -2, -1].each { |i| cursor.index = i }
      assert_equal ["A", "C", t(:dxs_ok), t(:dxs_unset)].map { |v| "#{t(:dxs_name)}, #{v}" }, SpeakCapture.lines
    end
  end

  test "a cursor in another filter's sub-screen than the one painted says nothing" do
    scene = PokemonPokedex_Scene.new
    cursor = PokedexSearchSelectionSprite.new
    searching do
      scene.pbRefreshDexSearchParam(1, ["A", "B", "C"], [0], 0)
      SpeakCapture.clear
      cursor.mode = 2
      cursor.index = 1
      assert_nothing_spoken
    end
  end

  test "a filter whose list keeps the engine's data objects says each by its name" do
    scene = searching_scene
    types = [GameData::Type.get(:NORMAL), GameData::Type.get(:FIRE)]
    scene.instance_variable_set(:@typeCommands, types)
    searching do
      assert_equal "TypeFIRE", PokeAccess::DexSearch.field_value(scene, 2, [0, -1, 1, -1, -1, -1, -1, -1, -1, -1])
      scene.pbRefreshDexSearchParam(2, types, [1], 1)
      assert_equal ["#{t(:dxs_type)}, TypeFIRE"], SpeakCapture.lines
    end
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end

  # A search screen with the lists its opening builds, as the repaints find them.
  def searching_scene
    scene = PokemonPokedex_Scene.new
    scene.instance_variable_set(:@orderCommands, ["Numerical", "A to Z"])
    scene.instance_variable_set(:@nameCommands, ["A", "B"])
    scene
  end

  # Runs the block with the search forgotten afterwards, as its closing does.
  def searching
    yield
  ensure
    PokeAccess::DexSearch.close
  end
end

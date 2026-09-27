# The Pokedex search grid, read as its cursor sprite moves: each filter with its value, each button. Gamedata pass.
Suite.define("pokedex search: walking the grid reads each filter and button") do
  t = PokeAccess::I18n
  scene = PokemonPokedex_Scene.new
  eq "the search keeps its own return", scene.pbDexSearch([1, 8]), :searched
  lines = SpeakCapture.lines
  eq "opening reads the first row with its value", lines[0], "#{t.t(:dxs_order)}, Numerical"
  eq "moving reads the next filter with its value", lines[1], "#{t.t(:dxs_name)}, B"
  eq "and a button by its name", lines[2], t.t(:dxs_search)

  SpeakCapture.clear
  PokedexSearchSelectionSprite.new.index = 3
  silent "once the search is closed its cursor says nothing"
end

# A filter's sub-screen repaints only on opening and on confirm (height and weight on every move too); between,
# only its cursor's index changes.
Suite.define("pokedex search: a filter's sub-screen reads each option its cursor moves to") do
  t = PokeAccess::I18n
  scene = PokemonPokedex_Scene.new
  cursor = PokedexSearchSelectionSprite.new
  begin
    eq "the sub-screen's repaint keeps its own return", scene.pbRefreshDexSearchParam(1, ["A", "B", "C"], [0], 0),
       [1, 0]
    cursor.mode = 1
    SpeakCapture.clear
    cursor.index = 2
    eq "the name filter's cursor says the letter it lands on", SpeakCapture.lines, ["#{t.t(:dxs_name)}, C"]
    cursor.index = -2
    eq "and the OK button", SpeakCapture.lines.last, "#{t.t(:dxs_name)}, #{t.t(:dxs_ok)}"
    cursor.index = -1
    eq "the blank cell before it clears the filter, and is not OK", SpeakCapture.lines.last,
       "#{t.t(:dxs_name)}, #{t.t(:dxs_unset)}"
  ensure
    PokeAccess::DexSearch.close
  end
end

# Heights and weights are kept in tenths on this era too, and painted in metres and kilograms.
Suite.define("pokedex search: heights and weights are said as the metres and kilograms the grid paints") do
  ds = PokeAccess::DexSearch
  scene = World.stub_scene(:@heightCommands => [1, 2, 3, 4, 12], :@weightCommands => [5, 10, 15])
  params = [0, -1, -1, -1, 3, 4, 1, -1, -1, -1]
  eq "a height range as painted", ds.field_value(scene, 3, params), "0.4 - 1.2"
  eq "a weight with no maximum, up to the top the screen paints", ds.field_value(scene, 4, params), "1.0 - 999.9"
  t = PokeAccess::I18n
  SpeakCapture.clear
  begin
    ds.param(scene, 3, [1, 2, 3, 4, 12], 4)
    eq "a height slider's stop as the metres it paints", SpeakCapture.last, "#{t.t(:dxs_height)}, 1.2"
    ds.param(scene, 3, [1, 2, 3, 4, 12], -1)
    eq "and let go to its end, no limit", SpeakCapture.last, "#{t.t(:dxs_height)}, #{t.t(:dxs_no_limit)}"
  ensure
    ds.close
  end
end

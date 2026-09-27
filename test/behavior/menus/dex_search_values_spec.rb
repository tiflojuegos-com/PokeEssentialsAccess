# The Pokedex search's values as the screen paints them (core/menus/pokedex_search/), over the v17 lists, whose
# types and shapes are bare numbers: a type by its name, a shape by its place, heights and weights in the metres and
# kilograms their tenths paint, and the blank cell below a filter's options, which clears the filter, not OK.
module DexSearchValuesSpec
  # A search scene with the lists pbDexSearch builds on the gen-6 era, shortened.
  def self.scene
    World.stub_scene(:@orderCommands => ["Numerical"], :@nameCommands => %w[A B C], :@typeCommands => [0, 1, 2, 10],
                     :@heightCommands => [1, 2, 3, 4, 12], :@weightCommands => [5, 10, 15],
                     :@colorCommands => %w[Red Blue], :@shapeCommands => (0...14).to_a)
  end
end

Suite.define("dex search: the grid says types by name, shapes by place, and heights and weights as painted") do
  ds = PokeAccess::DexSearch
  t = PokeAccess::I18n
  s = DexSearchValuesSpec.scene
  params = [0, -1, 3, -1, 3, 4, 1, -1, -1, 4]
  eq "a type the list keeps as a number, by its name", ds.field_value(s, 2, params), PBTypes.getName(10)
  eq "a height range as its two painted limits, in metres", ds.field_value(s, 3, params), "0.4 - 1.2"
  eq "an unset maximum weight as the top the screen paints", ds.field_value(s, 4, params), "1.0 - 999.9"
  eq "a shape by its place among the shapes", ds.field_value(s, 6, params), t.t(:list_pos, :i => 5, :n => 14)
  eq "a range with neither limit set is no filter",
     ds.field_value(s, 3, [0, -1, -1, -1, -1, -1, -1, -1, -1, -1]), t.t(:dxs_unset)
  eq "an unset minimum as the 0.0 the screen paints",
     ds.field_value(s, 3, [0, -1, -1, -1, -1, 4, -1, -1, -1, -1]), "0.0 - 1.2"
end

Suite.define("dex search: a filter's sub-screen says its blank cell as clearing the filter, and OK and Cancel apart") do
  ds = PokeAccess::DexSearch
  t = PokeAccess::I18n
  s = DexSearchValuesSpec.scene
  types = [0, 1, 2, 10]
  heights = [1, 2, 3, 4, 12]
  SpeakCapture.clear
  begin
    ds.param(s, 2, types, 3)
    eq "a type option by its name", SpeakCapture.last, "#{t.t(:dxs_type)}, #{PBTypes.getName(10)}"
    ds.param(s, 2, types, -1)
    eq "the blank cell, painted ----, clears the filter", SpeakCapture.last, "#{t.t(:dxs_type)}, #{t.t(:dxs_unset)}"
    ds.param(s, 2, types, -2)
    eq "OK is the cell after it", SpeakCapture.last, "#{t.t(:dxs_type)}, #{t.t(:dxs_ok)}"
    ds.param(s, 2, types, -3)
    eq "and Cancel the last", SpeakCapture.last, "#{t.t(:dxs_type)}, #{t.t(:dxs_cancel)}"
    ds.param(s, 3, heights, 4)
    eq "a height option as painted", SpeakCapture.last, "#{t.t(:dxs_height)}, 1.2"
    ds.param(s, 3, heights, -1)
    eq "and a slider let go to its end is no limit, not the whole filter cleared", SpeakCapture.last,
       "#{t.t(:dxs_height)}, #{t.t(:dxs_no_limit)}"
    ds.param(s, 4, [5, 10, 15], -1)
    eq "on the weight too", SpeakCapture.last, "#{t.t(:dxs_weight)}, #{t.t(:dxs_no_limit)}"
    ds.param(s, 3, heights, -2)
    eq "while OK stays OK", SpeakCapture.last, "#{t.t(:dxs_height)}, #{t.t(:dxs_ok)}"
    ds.param(s, 6, s.instance_variable_get(:@shapeCommands), 0)
    eq "a shape by its place", SpeakCapture.last, "#{t.t(:dxs_shape)}, #{t.t(:list_pos, :i => 1, :n => 14)}"
  ensure
    ds.close
  end
end

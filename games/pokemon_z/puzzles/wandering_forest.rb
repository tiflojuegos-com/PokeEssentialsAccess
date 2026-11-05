# Bosque Errante (maps 355 from Collage to 372): the fifteen totems that call Shaymin stand on the map's tiles, and
# each event that wakes one has no graphic, name or text: it adds to var 220 with only a sound, so the count is said
# here. With the assist, each map part's way to Villa Pokémon (355 east, once switch 622 lets the player past the old
# man; 353 south, 32 east, 365 north, 368 south-east, 367 south, 371 south-east) and, once var 220 is at 15 and until
# self switch A of its event on 366, to Shaymin (368 east).
PokeAccess::Game.define("pokemon_z") do
  shaymin = lambda { $game_variables[220] >= 15 && !$game_self_switches[[366, 15, "A"]] }
  [[355, [], [[lambda { !$game_switches[622] }, nil], [nil, :z_forest_e]]],
   [353, [11, 12, 13], [[at(0, 12, 17, 24), :z_forest_w], [at(0, 7, 25, 26), :z_forest_w], [nil, :z_forest_s]]],
   [32, [9, 10, 11], [[nil, :z_forest_e]]],
   [365, [9], [[nil, :z_forest_n]]],
   [366, [12, 13, 14], [[at(27, 39, 23, 27), :z_forest_se], [nil, :z_forest_w, :z_forest_shaymin_here]]],
   [367, [], [[at(30, 53, 0, 26), :z_forest_n], [nil, :z_forest_s, :z_forest_shaymin_367]]],
   [368, [16, 17, 18], [[at(31, 42, 0, 14), :z_forest_n], [at(0, 9, 22, 27), :z_forest_w],
                        [nil, :z_forest_se, :z_forest_shaymin_way]]],
   [369, [], [[nil, :z_forest_e]]],
   [370, [], [[at(26, 39, 0, 28), :z_forest_e], [nil, :z_forest_w]]],
   [371, [14, 15], [[at(28, 34, 11, 14), :z_forest_e], [nil, :z_forest_se, :z_forest_shaymin_371]]],
   [372, [], [[at(0, 13, 0, 26), :z_forest_n], [nil, :z_forest_e]]]].each do |map, totems, ways|
    way = lambda do
      row = ways.find { |zone, _key, _shaymin| zone.nil? || zone.call }
      row[2] && shaymin.call ? row[2] : row[1]
    end
    mechanic(:state, map) do
      phase lambda { $game_variables[220] < 15 }, :quiet => true, :hint => way,
            :progress => { :var => 220, :of => 15, :label => :z_forest_totems, :hide_zero => true, :announce => true },
            :hidden => { :events => totems, :label => :z_forest_totem }
      phase lambda { true }, :quiet => true, :hint => way
    end
  end
end

# Tsukinami Village's gym (map 175): tiles that change colour when stepped on (events named tile1, the first ones and those
# createPuzzle spawns). Tile 1622 is white, 1630 black; the door opens with half of them of each colour. Variable 121 is the
# gym's progress and holds 4 or more once the three puzzles are done. The info key says the black count against the whole, so
# the grid's line covers what the game's counter paints (games/uranium/field.rb says that counter as it changes).
PokeAccess::Game.define("uranium") do
  mechanic(:grid, 175) do
    auto
    solved(nil) { $game_variables[121].to_i >= 4 }
    tiles(/\Atile1\z/, :label => :ura_pz_tile, :done => false, :count => :ura_pz_tiles_black,
          :words => { true => :ura_pz_tile_white, false => :ura_pz_tile_black }) { |ev| ev.tile_id.to_i == 1622 }
  end
end

# The Regi tombs (maps 680 to 691), optional. A braille inscription on each tomb's wall, read by field_screens.rb, says
# where to stand and what to use; the game opens the way only on that tile (PokemonFollow's canUseMove check and
# pbPerseumN), each with a switch of its own (1419 to 1423). Two of them also ask for a Pokemon in the party, as their
# inscription hints: Bandeon for Cut (686) and Scaleon for Fly (688). With the assist, the tile is listed with the move to
# use there and the Pokemon it asks for.
module PokeAccess
  module XenoRegiTombs
    # Each tomb's map, tile, move, switch and the species the game asks for in the party, if any.
    TOMBS = [[680, [20, 21], :ROCKSMASH, 1419, nil], [682, [15, 15], :SURF, 1420, nil],
             [684, [20, 15], :STRENGTH, 1421, nil], [686, [18, 26], :CUT, 1422, :BANDEON],
             [688, [25, 26], :FLY, 1423, :SCALEON]]

    # The spot's line: the move, and the Pokemon the game asks for with it.
    def self.spot_line(move, species)
      move_name = PokeAccess::FieldMoves.name(move)
      return [:xv_regi_spot, { :move => move_name }] unless species
      [:xv_regi_spot_with, { :move => move_name, :pokemon => PokeAccess::Data.species_name(species) }]
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  tombs = PokeAccess::XenoRegiTombs
  tombs::TOMBS.each do |map, tile, move, switch, species|
    mechanic(:state, map) do
      auto
      spot :at => tile, :onto => true, :assist => true, :when => lambda { !$game_switches[switch] },
           :label => lambda { tombs.spot_line(move, species) }
    end
  end
end

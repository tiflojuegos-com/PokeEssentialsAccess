# The Wind shrine's wind symbols (maps 275 and 287), drawn on the floor (a tile of their own, on those six tiles alone):
# with the wind magic (switch 168), the action button on one, facing the gap it marks, carries the player across. The
# routes already take them (an action on the player's own tile under a branch on the facing); on map 287 they are the
# way from the west entry to the slabs. Without the magic their events' pages are empty, so the symbols are named by
# their tiles, for all; with the puzzle assist, the way to face.
PokeAccess::Game.define("awakening") do
  symbols = { 287 => { [17, 6] => 2, [17, 11] => 8, [8, 24] => 2, [8, 31] => 8 },
              275 => { [51, 4] => 4, [45, 4] => 6 } }
  symbols.each do |map, ways|
    mechanic(:state, map, :part => :wind) do
      auto
      ways.each do |(x, y), dir|
        spot :at => [x, y], :onto => true, :label => lambda {
          next :awk_wind_symbol unless PokeAccess::Puzzles.assist?
          [:awk_wind_symbol_way, { :dir => PokeAccess::Puzzles.face_name(dir) }]
        }
      end
    end
  end
end

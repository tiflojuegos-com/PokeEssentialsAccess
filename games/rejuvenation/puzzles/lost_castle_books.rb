# Lost Castle (map 219): Dusclops (event 25) asks for five book codes, each entry nested in the right answer to the one
# before, and lets the player through with variable 195 at 9. The books: 0044 (events 41, 42), 6677 (43, 44), 3645 (45),
# 9043 (53, 54), 7171 (46, 47); the core says each code as its entry opens.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 219, :part => :books) do
    auto
    name [41, 42, 43, 44, 45, 46, 47, 53, 54], :rjg_lc_book, :grouped => true
    solved { $game_variables[195].to_i >= 9 }
  end
end

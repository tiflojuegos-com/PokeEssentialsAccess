# The Edelweiss Oratory (maps 256 to 261): a button hidden behind a sign at (24, 3) of map 257 and the key in the chest
# at (54, 39) of map 260 each add 1 to variable 179, which the locked door of map 259 wants at 14 (the story brings it
# to 12). The sign, with no event graphic, is named; with the puzzle assist, the right answer to pressing the button.
PokeAccess::Game.define("awakening") do
  mechanic(:state, 257, :part => :sign) do
    auto
    name 3, :awk_sign, :when => lambda { |_ev| !$game_self_switches[[257, 3, "A"]] }
    right_choice 3, :takes => { :var => 179 }
  end
end

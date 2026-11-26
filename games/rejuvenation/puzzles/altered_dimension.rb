# Nim's Altered Dimension (map 96), second game: one of three trees is Nim in disguise (event 11), and owning up to it
# sets variable 36 to 5; the other two only buzz.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 96, :part => :trees) do
    auto
    name [3, 10, 11], :rjd_ad_tree, :numbered => true, :when => lambda { |_ev| $game_variables[36].to_i < 5 }
    right_choice 11, :takes => { :var => 36 }
    solved { $game_variables[36].to_i >= 5 }
  end
end

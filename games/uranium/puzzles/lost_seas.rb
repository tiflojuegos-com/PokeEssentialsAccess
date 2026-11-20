# The koan of the Lost Seas (map 259): event 1 asks the fox, goat and cabbage riddle with the three leviathans in chained
# menus, and only the way that ends it sets the event's self switch B; a wrong pick jumps to the end of the page and moves
# the player a step back. The assist tells the pick of each menu; where either is right (both reach the end), it says
# none; where an empty pick runs on past its menu into the ending (Give Up), it says the one whose own branch sets B.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 259) do
    auto
    right_choice 1, :takes => { :self => "B" }
  end
end

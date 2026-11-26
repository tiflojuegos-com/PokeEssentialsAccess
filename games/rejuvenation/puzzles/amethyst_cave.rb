# Amethyst Cave's stone with an amulet (map 4, event 56), drawn with a tile and named by no one: once Keta has spoken of
# it (variable 359 at 23) its Yes opens the passage to the Grotto (variable 49 to 2, 359 to 24).
PokeAccess::Game.define("rejuvenation") do
  open = lambda { $game_variables[49].to_i >= 2 }
  mechanic(:state, 4, :part => :keta_stone) do
    auto
    name 56, :rj_amethyst_stone, :when => lambda { |_ev| !open.call }
    right_choice 56, :takes => { :var => 359 }
    solved { open.call }
  end
end

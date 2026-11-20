# Violet Gym (map 205): a block (event 2) shuts the one way from the entrance up to Falkner until both floor buttons are
# pressed, the west one (event 3, switch 71) and the east one (event 5, switch 102), each at the end of a side corridor.
PokeAccess::Game.define("gruelinggold") do
  mechanic(:state, 205) do
    auto
    watch :switch => 71, :label => :gg_button_west, :on => :gg_pressed, :off => :gg_not_pressed
    watch :switch => 102, :label => :gg_button_east, :on => :gg_pressed, :off => :gg_not_pressed
    controls
    obstacle({ :events => 2 }, :label => :gg_violet_block)
    name 2, :gg_violet_block
    name 3, :gg_button_west
    name 5, :gg_button_east
    solved { $game_switches[71] && $game_switches[102] }
    arrival_hint :gg_violet_rule
    hint :gg_violet_hint
  end
end

# The ice floors: Mahogany Gym (map 284), entered from its hall through the door at (5,21), with Pryce at (44,3) and his
# badge on switch 10; and the Ice Path (map 286) between Route 44 and Blackthorn City. The player slides on as v20's
# pbSlideOnIce does, until the next tile stops them or the floor is no longer ice; the routes plan the slides.
PokeAccess::Game.define("gruelinggold") do
  mechanic(:state, 284) do
    auto
    solved { $game_switches[10] }
    arrival_hint :gg_ice_rule
    phase lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => :gg_mahogany_hint
  end

  mechanic(:state, 286) do
    auto
    arrival_hint :gg_ice_rule, :once => true
    active { false }
  end
end

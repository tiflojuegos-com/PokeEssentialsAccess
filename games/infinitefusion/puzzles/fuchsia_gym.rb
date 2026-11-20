# Fuchsia City Gym (map 479): the maze is invisible walls in the map itself, which the routes already go round. The map
# only says so on arriving, until Koga is beaten (switch 8).
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 479) do
    auto
    arrival_hint :ifk_fg_rule
    solved { $game_switches[8] }
  end
end

# Victory Isle (map 227): its currents (games/solarlight/currents.rb) carry a surfer from Waytide back east, so the way on
# goes through Victory Cave (81,20), and from its west exits by the bridge of the south island and the west channel to
# League Gateway (14,7). A route chains the crossings either way takes; with the assist, the hint names the end of the way
# for the side of the isle the player is on.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, 227) do
    auto
    west = at(0, 79, 0, 101)
    south_west = at(80, 92, 28, 101)
    phase lambda { west.call || south_west.call }, :quiet => true, :hint => :solar_isle_h_west
    phase lambda { true }, :quiet => true, :hint => :solar_isle_h_east
    solved { $game_switches[683] }
  end
end

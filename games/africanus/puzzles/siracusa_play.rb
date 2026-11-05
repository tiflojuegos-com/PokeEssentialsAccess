# Siracusa's play (map 185): once the cup is back, four actors who left the stage (events 81 to 84, each counted in
# variable 91 when spoken to) must be found. The game never says how many there are, so the count is for the assist.
PokeAccess::Game.define("africanus") do
  mechanic(:state, 185) do
    auto
    name 81..84, :af_actor
    count :af_actors, :var => 91, :of => 4, :assist => true
    active { $game_switches[288] && $game_variables[55].to_i < 4 }
  end
end

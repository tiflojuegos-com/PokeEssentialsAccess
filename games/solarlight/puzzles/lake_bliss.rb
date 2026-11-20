# Lake Bliss (map 177): the statue (event 21) brings Parafox the first time; after that, Felove only with Pupetal, Pupyro and
# Puplash first, second and third in the party (self switch B once it came).
PokeAccess::Game.define("solarlight") do
  self_on = lambda { |letter| $game_self_switches && $game_self_switches[[177, 21, letter]] ? true : false }
  mechanic(:state, 177) do
    auto
    name 21, :solar_bliss_statue
    phase lambda { self_on.call("A") }, :quiet => true, :hint => :solar_bliss_hint
    solved { self_on.call("B") }
  end
end

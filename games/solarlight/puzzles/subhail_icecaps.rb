# Subhail Icecaps (map 226): eighteen sprite-less "Jump3" events, each on a crack in the ice, hop the player two tiles over
# it, down when facing down and up otherwise (games/solarlight/jumps.rb). Switch 536 ends the rescue of the boy.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, 226) do
    auto
    name(/\AJump3\z/, :solar_icecaps_crack)
    solved { $game_switches[536] }
    arrival_hint :solar_icecaps_rule
  end
end

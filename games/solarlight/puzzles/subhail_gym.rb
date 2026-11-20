# Subhail's gym (map 260): two ski lifts (events 13 and 16), used facing up from below, carry the player to the top
# (games/solarlight/jumps.rb), and the slopes down are touch events that slide the player one to four tiles down, which the
# routes follow; not every slope ends at Alice (event 1). Switch 10 is the badge.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, 260) do
    auto
    name [13, 16], :solar_subhail_lift
    phase lambda { true }, :quiet => true, :hint => :solar_subhail_hint
    solved { $game_switches[10] }
    arrival_hint :solar_subhail_rule
  end
end

# Realidea's forced ground, one tile after each step the player takes (not after a push):
#   terrain 42 (0242_Deslizarse.rb), a slope one tile down;
#   terrains 44-47 (0205_Surf.rb), currents one tile up, right, left or down while switch 182 (water walking) is on.
PokeAccess::Game.define("realidea_slides") do
  pushes = { 42 => 2 }
  currents = { 44 => 8, 45 => 6, 46 => 4, 47 => 2 }
  terrain_rule do |x, y, _d|
    tag = PokeAccess::Terrain.number_at(x, y)
    d = pushes[tag] || (($game_switches[182] rescue false) ? currents[tag] : nil)
    next nil if d.nil?
    dd = PokeAccess::DIR_DELTA[d]
    PokeAccess::Pathfinder.landing(x + dd[0], y + dd[1]) || false
  end
end

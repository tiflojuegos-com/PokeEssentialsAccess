# Realidea's forced ground: a step onto it is followed by a push of one tile with Through on, and each push ends in a
# step taken (pbOnStepTaken runs once the move route has let go), so the pushes run on to the first tile that does
# not push, through walls and closed passages alike:
#   terrain 42 (0242_Deslizarse.rb), a slope one tile down;
#   terrains 44-47 (0205_Surf.rb), currents one tile up, right, left or down while switch 182 (water walking) is on.
PokeAccess::Game.define("realidea_slides") do
  pushes = { 42 => 2 }
  currents = { 44 => 8, 45 => 6, 46 => 4, 47 => 2 }
  push = lambda do |x, y|
    tag = PokeAccess::World::Terrain.number(x, y)
    pushes[tag] || (($game_switches[182] rescue false) ? currents[tag] : nil)
  end
  terrain_rule(:tags => pushes.keys + currents.keys) do |x, y, _d|
    d = push.call(x, y)
    next nil if d.nil?
    cap = PokeAccess::Routes::Moves::ARRIVAL_CAP
    steps = 0
    while d && steps <= cap
      dd = PokeAccess::DIR_DELTA[d]
      break unless $game_map.valid?(x + dd[0], y + dd[1])
      x += dd[0]
      y += dd[1]
      steps += 1
      d = push.call(x, y)
    end
    steps > cap ? false : [x, y]
  end
end

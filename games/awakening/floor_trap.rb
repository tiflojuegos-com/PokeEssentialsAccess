# Awakening's floor traps (terrain 17, "TrampaPiso"): a step onto one is followed by a tile down unless right,
# left or up is held, so walking down slides to its end; the guides say to hold the key.
PokeAccess::Game.define("awakening_floor_trap") do
  trap = lambda { |x, y| PokeAccess::Terrain.number_at(x, y) == 17 }
  held_key_ground { |x, y| trap.call(x, y) }
  terrain_rule do |x, y, d|
    next nil if d != 2 || !trap.call(x, y)
    pf = PokeAccess::Pathfinder
    steps = 0
    while trap.call(x, y) && pf.passable_at?(x, y, 2)
      steps += 1
      break if steps > pf::ARRIVAL_CAP
      y += 1
    end
    steps > pf::ARRIVAL_CAP ? false : [x, y]
  end
end

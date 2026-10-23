# Awakening's floor traps (terrain 17, "TrampaPiso"): with none of right, left or up held, each step on one is followed
# by a tile down, so only walking down slides, to the trap's end; the guides say to hold the key. The game leaves
# $PokemonGlobal.sliding on until the player is off the trap, so sliding? holds there only while moving down.
PokeAccess::Game.define("awakening_floor_trap") do
  trap = lambda { |x, y| PokeAccess::World::Terrain.number(x, y) == 17 }
  held_key_ground(:tags => [17]) { |x, y| trap.call(x, y) }
  terrain_rule(:tags => [17]) do |x, y, d|
    next nil if d != 2 || !trap.call(x, y)
    cap = PokeAccess::Routes::Moves::ARRIVAL_CAP
    steps = 0
    while trap.call(x, y) && PokeAccess::World::Probe.step?(x, y, 2)
      steps += 1
      break if steps > cap
      y += 1
    end
    steps > cap ? false : [x, y]
  end
  override("PokeAccess::Control", :sliding?) do |_mod, original, _args|
    p = $game_player
    next original.call unless p && trap.call(p.x, p.y)
    (p.moving? && p.direction == 2) ? true : false
  end
end

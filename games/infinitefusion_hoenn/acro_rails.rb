# IF Hoenn's acro-bike rails (terrain flag acroBike): on the bike, the action button facing one jumps onto it,
# the bike rides along it, and a press toward a non-rail tile hops one tile off, whatever that tile's passage, where
# the jump may land (hopOffFence's pbJumpToward(1) refuses a tile someone stands on, and the press bumps).
PokeAccess::Game.define("ifh_acro_rails") do
  rail = lambda { |x, y| PokeAccess::World::Terrain.flag?(x, y, :acroBike) }

  assisted_step(:front_flags => [:acroBike]) do |x, y, dir, lvl|
    nx = x + dir[0]; ny = y + dir[1]
    next nil unless ($PokemonGlobal.bicycle rescue false) && !rail.call(x, y) && rail.call(nx, ny)
    PokeAccess::Routes::Moves::Step.new(nx, ny, lvl, 1, { :kind => :act, :face => dir[2], :x => x, :y => y })
  end

  terrain_exit(:flags => [:acroBike]) do |x, y, dir|
    nx = x + dir[0]; ny = y + dir[1]
    next nil unless rail.call(x, y) && !rail.call(nx, ny)
    PokeAccess::World::Probe.lands?(x, y, dir[2], nx, ny) ? [nx, ny] : false
  end
end

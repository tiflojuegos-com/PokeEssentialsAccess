# IF Hoenn's acro-bike rails (terrain flag acroBike): on the bike, the action button facing one jumps onto it,
# the bike rides along it, and a press toward a non-rail tile hops one tile off, whatever that tile's passage.
PokeAccess::Game.define("ifh_acro_rails") do
  rail = lambda { |x, y| PokeAccess::Terrain.flag_at?(x, y, :acroBike) }

  assisted_step do |x, y, dir, lvl|
    nx = x + dir[0]; ny = y + dir[1]
    next nil unless ($PokemonGlobal.bicycle rescue false) && !rail.call(x, y) && rail.call(nx, ny)
    PokeAccess::Pathfinder::Step.new(nx, ny, lvl, 1, { :kind => :act, :face => dir[2], :x => x, :y => y })
  end

  terrain_exit do |x, y, dir|
    next nil unless rail.call(x, y) && !rail.call(x + dir[0], y + dir[1])
    PokeAccess::Pathfinder.landing(x + dir[0], y + dir[1]) || false
  end
end

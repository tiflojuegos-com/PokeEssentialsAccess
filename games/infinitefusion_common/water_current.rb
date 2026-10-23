# The saga's water currents (terrain flag waterCurrent): a surfer ending a step on one is pushed up, else left,
# right or down as the tile allows (pbSlideOnWater's order, not the drawn one), while still on the current.
module PokeAccess
  module IFWaterCurrent
    PUSH_ORDER = [8, 4, 6, 2]

    # True if (x,y) is a current.
    def self.current?(x, y)
      PokeAccess::World::Terrain.flag?(x, y, :waterCurrent)
    end

    # Where a surfer arriving on (x,y) in direction d ends up, as [x, y], or false when the game would push forever.
    def self.carry(x, y, d)
      cap = PokeAccess::Routes::Moves::ARRIVAL_CAP
      steps = 0
      while current?(x, y) && PokeAccess::World::Probe.step?(x, y, d)
        k = PUSH_ORDER.find { |dir| ($game_map.passable?(x, y, dir) rescue false) }
        return [x, y] if k.nil?
        return false unless PokeAccess::World::Probe.step?(x, y, k)
        steps += 1
        return false if steps > cap
        dd = PokeAccess::DIR_DELTA[k]
        x += dd[0]; y += dd[1]
      end
      [x, y]
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  terrain_rule(:flags => [:waterCurrent]) do |x, y, d|
    next nil unless ($PokemonGlobal.surfing rescue false) && PokeAccess::IFWaterCurrent.current?(x, y)
    PokeAccess::IFWaterCurrent.carry(x, y, d)
  end
end

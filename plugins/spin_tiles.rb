module PokeAccess
  # Spin Tiles (a v17 script): arrow tiles spin the player tile after tile until the way ahead is blocked, each arrow
  # turning the spin; the way is checked before turning, so a spin arriving blocked stops even on an open arrow.
  module SpinTiles
    # The four arrows by their PBTerrain names, and the way each one spins.
    ARROWS = [["SpinTileUp", 8], ["SpinTileDown", 2], ["SpinTileLeft", 4], ["SpinTileRight", 6]]

    # terrain number => direction, read from the constants the script defines.
    def self.arrows
      return @arrows if @arrows
      @arrows = {}
      ARROWS.each { |name, d| @arrows[::PBTerrain.const_get(name)] = d if ::PBTerrain.const_defined?(name) }
      @arrows
    rescue StandardError
      @arrows = {}
    end

    # True where a game's own copy of the script ends the spin besides a blocked way: none in the original.
    # param x, y the player's tile before each step of the spin
    def self.extra_stop?(_x, _y)
      false
    end

    # The way the arrow at (x,y) spins the player, or nil.
    def self.dir_at(x, y)
      arrows[PokeAccess::Terrain.number_at(x, y)]
    rescue StandardError
      nil
    end

    # Where a spin started on (x,y) facing face ends, as [x, y], or false when it would never end.
    def self.spin(x, y, face)
      pf = PokeAccess::Pathfinder
      steps = 0
      loop do
        break unless pf.passable_at?(x, y, face)
        break if (extra_stop?(x, y) rescue false)
        face = dir_at(x, y) || face
        break unless pf.passable_at?(x, y, face)
        steps += 1
        return false if steps > pf::ARRIVAL_CAP
        dd = PokeAccess::DIR_DELTA[face]
        x += dd[0]; y += dd[1]
      end
      [x, y]
    end
  end
end

PokeAccess::Pathfinder.arrival_rule do |x, y, _d|
  face = PokeAccess::SpinTiles.dir_at(x, y)
  face ? PokeAccess::SpinTiles.spin(x, y, face) : nil
end

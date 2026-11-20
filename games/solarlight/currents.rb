# Solar Light's water currents (terrain tags 18 to 21, 0107_PField_Field.rb): each step that ends on one moves the player a
# tile left, up, right or down, as a plain move that stops where it is blocked and ends in a step of its own, so the moves run
# on to the first tile that is no current. Waytide's gym and Victory Isle have them; the free camera names each.
module PokeAccess
  module SolarCurrents
    DIRS = { 18 => 4, 19 => 8, 20 => 6, 21 => 2 }
    DIR_KEYS = { 4 => :dir_left, 8 => :dir_up, 6 => :dir_right, 2 => :dir_down }

    # The way the current at (x,y) carries the player, or nil off the currents.
    def self.dir_at(x, y)
      DIRS[PokeAccess::World::Terrain.number(x, y)]
    end

    # Where a step arriving on (x,y) ends, as [x, y], or false for currents that would carry the player forever.
    def self.carry(x, y)
      steps = 0
      while (d = dir_at(x, y)) && PokeAccess::World::Probe.step?(x, y, d)
        steps += 1
        return false if steps > PokeAccess::Routes::Moves::ARRIVAL_CAP
        dd = PokeAccess::DIR_DELTA[d]
        x += dd[0]
        y += dd[1]
      end
      [x, y]
    end
  end
end

PokeAccess::Game.define("solarlight") do
  currents = PokeAccess::SolarCurrents
  terrain_rule(:tags => currents::DIRS.keys) { |x, y, _d| currents.carry(x, y) }
  camera_tile(:tags => currents::DIRS.keys) do |x, y|
    d = currents.dir_at(x, y)
    d ? PokeAccess::I18n.t(:solar_current, :dir => PokeAccess::I18n.t(currents::DIR_KEYS[d])) : nil
  end
end

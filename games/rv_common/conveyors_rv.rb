module PokeAccess
  # The conveyor belts of the engine Reborn, Rejuvenation and Desolation share (its PBTerrain DownConveyor to
  # UpConveyor): a step onto one carries the player along each belt tile's own way while the step that way is open,
  # until off the belts (pbConveyorMove, run by the step taken).
  module ConveyorsRV
    NAMES = [[:DownConveyor, 2], [:LeftConveyor, 4], [:RightConveyor, 6], [:UpConveyor, 8]]

    @ways = {}

    # The belt tags the engine names, each with the way it carries; empty where it names none.
    def self.named_ways
      out = {}
      return out unless defined?(::PBTerrain)
      NAMES.each { |name, d| out[::PBTerrain.const_get(name)] = d if ::PBTerrain.const_defined?(name) }
      out
    end

    # Where a step onto the belt at (x,y) ends, as [x, y], short of a boulder where a push search has one though the
    # boulders are lent through (Routes::Moves.obstacle_at?); false for belts the player would never leave, nil off
    # them.
    def self.carry(x, y)
      d = @ways[PokeAccess::World::Terrain.number(x, y)]
      return nil unless d
      moves = PokeAccess::Routes::Moves
      steps = 0
      while d
        dd = PokeAccess::DIR_DELTA[d]
        break unless PokeAccess::World::Probe.step?(x, y, d) && !moves.obstacle_at?(x + dd[0], y + dd[1])
        steps += 1
        return false if steps > moves::ARRIVAL_CAP
        x += dd[0]
        y += dd[1]
        d = @ways[PokeAccess::World::Terrain.number(x, y)]
      end
      [x, y]
    end

    # Registers the belts the engine names as terrain the routes follow.
    def self.bind
      @ways = named_ways
      return if @ways.empty?
      PokeAccess::Routes::Moves.arrival_rule(:tags => @ways.keys) { |x, y, _d| PokeAccess::ConveyorsRV.carry(x, y) }
    end
  end
end

PokeAccess::ConveyorsRV.bind if PokeAccess::DataRV.engine?

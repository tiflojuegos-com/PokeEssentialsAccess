module PokeAccess
  # The Ancient Tower's pitfalls (maps 366 to 368): invisible parallel events named "Pitfall" that drop the player to
  # the floor below unless, riding the bicycle, it goes on without stopping (the page checks the tile again eight
  # frames later, and a new direction only turns the player first). On foot they are walls to the route; riding,
  # ground crossed straight on with the direction key held, never stopped or turned on.
  module InsurgencePits
    # The Ancient Tower's maps, the only ones of the game with a "Pitfall" event.
    MAPS = [366, 367, 368]

    # True if a pitfall waits on (x, y); off the tower's maps, without reading the tile.
    def self.pit?(x, y)
      return false unless MAPS.include?(($game_map.map_id rescue 0))
      PokeAccess::World::Events.anchored(x, y).any? { |r| r.name.to_s == "Pitfall" }
    end

    # True while the player rides the bicycle.
    def self.riding?
      ($PokemonGlobal.bicycle rescue false) ? true : false
    end

    # A step arriving on (x, y) moving d: nil off the pits; false on foot, or riding where the way on along d stops
    # on a pit; riding, the first tile past the pits along d and the presses it takes, as [x, y, presses].
    def self.arrival(x, y, d)
      return nil unless pit?(x, y)
      return false unless riding?
      dd = PokeAccess::DIR_DELTA[d]
      presses = 1
      while pit?(x, y)
        return false if presses > PokeAccess::Routes::Moves::ARRIVAL_CAP || !PokeAccess::World::Probe.step?(x, y, d)
        x += dd[0]
        y += dd[1]
        presses += 1
      end
      [x, y, presses]
    end
  end

  # Insurgence's waterfalls have no crest tile (no map carries tag 9): a step that ends facing down with a fall below,
  # surfing or on foot, is carried past it (onStepTakenFieldMovement, 086_PokemonField.rb), and a planned surf moving
  # down into a fall is carried from any of its tiles (Routes::Moves.crestless_falls!).
  module InsurgenceFalls
    # Where a step arriving on (x, y) moving down ends: the tile past the fall below as [x, y], false past the map's
    # edge, or nil with no fall below.
    def self.descent(x, y, d)
      return nil unless d == 2
      return nil unless PokeAccess::World::Terrain.kind(x, y + 1) == :waterfall
      PokeAccess::Routes::Moves.fall_end(x, y + 1, 1) || false
    end

    # True if a fall lies below (x, y); on a map with no fall tile, without reading the tile.
    def self.above_fall?(x, y)
      falls_here? && PokeAccess::World::Terrain.kind(x, y + 1) == :waterfall
    end

    # Whether the map has a fall tile, worked out once per map.
    def self.falls_here?
      id = ($game_map.map_id rescue 0)
      return @falls[1] if @falls && @falls[0] == id
      t = PokeAccess::World::Terrain
      w = ($game_map.width rescue 0).to_i
      h = ($game_map.height rescue 0).to_i
      @falls = [id, (0...h).any? { |y| (0...w).any? { |x| t.kind(x, y) == :waterfall } }]
      @falls[1]
    end

    # Forgets which map has falls (a new map, a load, a reset).
    def self.forget; @falls = nil; end
  end

  # Insurgence's Rock Climb (Kernel.pbRockClimb, 088_PokemonHiddenMoves.rb): with the Hiking Boots, the action button
  # facing climbable rocks (tag 4) up or down takes the player to the first tile past them, then one step on where the
  # game allows it (pbAscendRockClimb, pbDescendRockClimb); facing them across does nothing.
  module InsurgenceRockClimb
    # PBTerrain::RockClimb.
    TAG = 4

    # The climb from (x, y) toward dir ([dx, dy, d]) as an assisted step whose gate is the rocks', cleared by the
    # Hiking Boots; nil facing across, with no rocks in front, or without the boots.
    def self.step(x, y, dir, lvl)
      return nil unless dir[0] == 0
      l = landing(x, y, dir[1])
      return nil if l.nil?
      gate = { :kind => :field, :label => :ins_rock_climb, :item => :HIKINGBOOTS, :x => x, :y => y + dir[1] }
      return nil unless PokeAccess::FieldMoves.clear?(gate)
      PokeAccess::Routes::Moves::Step.new(l[0], l[1], lvl, 1, gate)
    end

    # Where a climb from (x, y) going dy rows at a time ends: on the first tile past the rocks, or the one after it
    # when the step there is open; nil with no rocks in front, or rocks that run off the map or on past ARRIVAL_CAP.
    def self.landing(x, y, dy)
      ty = y + dy
      return nil unless rock?(x, ty)
      guard = 0
      while rock?(x, ty)
        guard += 1
        return nil if guard > PokeAccess::Routes::Moves::ARRIVAL_CAP
        ty += dy
      end
      return nil unless ($game_map.valid?(x, ty) rescue false)
      PokeAccess::World::Probe.step?(x, ty, dy > 0 ? 2 : 8) ? [x, ty + dy] : [x, ty]
    end

    # True for a tile of climbable rocks.
    def self.rock?(x, y)
      PokeAccess::World::Terrain.number(x, y) == TAG
    end
  end
end

PokeAccess::Caches.register(:insurgence_falls) { PokeAccess::InsurgenceFalls.forget }

PokeAccess::Game.define("insurgence") do
  pits = { :tiles => lambda { |x, y| PokeAccess::InsurgencePits.pit?(x, y) } }
  terrain_rule(pits) { |x, y, d| PokeAccess::InsurgencePits.arrival(x, y, d) }
  held_key_ground(pits) { |x, y| PokeAccess::InsurgencePits.riding? && PokeAccess::InsurgencePits.pit?(x, y) }

  above_falls = { :tiles => lambda { |x, y| PokeAccess::InsurgenceFalls.above_fall?(x, y) } }
  terrain_rule(above_falls) { |x, y, d| PokeAccess::InsurgenceFalls.descent(x, y, d) }
  PokeAccess::Routes::Moves.crestless_falls!

  assisted_step(:front_tags => [PokeAccess::InsurgenceRockClimb::TAG]) do |x, y, dir, lvl|
    PokeAccess::InsurgenceRockClimb.step(x, y, dir, lvl)
  end
end

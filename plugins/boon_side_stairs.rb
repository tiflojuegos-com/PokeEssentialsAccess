module PokeAccess
  # Boon's Terrain Tag Side Stairs (gen-6 copies): on tiles tagged PBTerrain::StairLeft or StairRight a press left or
  # right walks along the slope, a row up or down, and stepping onto a slope from level ground drops a row on the way
  # down it. The route finder plays each press as Game_Player#move_left and #move_right do.
  module BoonSideStairs
    # The two stair tags the script defines, as [left, right], or [] without them.
    def self.tags
      @tags ||= [PokeAccess.const_at("PBTerrain::StairLeft"), PokeAccess.const_at("PBTerrain::StairRight")].compact
    end

    # The stair tag of (x,y), or nil on any other tile.
    def self.stair_at(x, y)
      n = PokeAccess::World::Terrain.number(x, y)
      tags.include?(n) ? n : nil
    end

    # True when a press toward d leaving tag behind goes down the slope: left on a left stair, right on a right one.
    def self.descends?(tag, d)
      tag == tags[d == 4 ? 0 : 1]
    end

    # Where a press toward d takes the player from the stair (x,y), as [x, y, 1], false when the step is closed, nil
    # for an up or down press, which the stairs leave to the engine. The slope is taken when the tile beyond it is open
    # as the script asks, going down only onto the same stair; else the press is an ordinary step.
    def self.leave(x, y, d)
      return nil unless d == 4 || d == 6
      tag = stair_at(x, y)
      return nil if tag.nil?
      dx = d == 4 ? -1 : 1
      down = descends?(tag, d)
      dy = down ? 1 : -1
      probe = PokeAccess::World::Probe
      if probe.step?(x + dx, y + dy, tag == tags[0] ? 4 : 6) && (!down || stair_at(x + dx, y + dy) == tag)
        return settled(x + dx, y + dy, d, tag)
      end
      probe.step?(x, y, d) ? settled(x + dx, y, d, tag) : false
    end

    # The tile a press toward d ends on, having arrived on (x,y) from a tile tagged from: a row lower when it steps onto
    # another stair on the way down it.
    def self.settled(x, y, d, from)
      tag = stair_at(x, y)
      [x, (tag && tag != from && descends?(tag, d)) ? y + 1 : y, 1]
    end

    # Where a step from level ground onto the stair (x,y) moving toward d ends, or nil when it stays there.
    def self.arrival(x, y, d)
      return nil unless d == 4 || d == 6
      tag = stair_at(x, y)
      (tag && descends?(tag, d)) ? [x, y + 1, 1] : nil
    end
  end
end

PokeAccess::Routes::Moves.leave_rule(:tags => lambda { PokeAccess::BoonSideStairs.tags }) do |x, y, dir|
  PokeAccess::BoonSideStairs.leave(x, y, dir[2])
end

PokeAccess::Routes::Moves.arrival_rule(:tags => lambda { PokeAccess::BoonSideStairs.tags }) do |x, y, d|
  PokeAccess::BoonSideStairs.arrival(x, y, d)
end

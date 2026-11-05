# Rock Climb in Keishou's copy of Advanced Items, older than plugins/advanced_items.rb's (06_Field Move.rb, 03_Item
# Handler.rb): facing up or down at a climbable tile, the action button carries the player straight along it to the
# first tile that is not, $PokemonGlobal.rockclimbing on meanwhile. One assisted route step.
module PokeAccess
  module KeishouRockClimb
    # True if (x,y) is climbable, the crest included.
    def self.rock?(x, y)
      PokeAccess::World::Terrain.flag?(x, y, :can_climb)
    end

    # Where a climb begun from (x,y) facing d sets the player down, as [x, y], or nil.
    def self.climb(x, y, d)
      return nil unless d == 8 || d == 2
      step = d == 8 ? -1 : 1
      cy = y + step
      return nil unless rock?(x, cy)
      steps = 0
      while rock?(x, cy + step)
        cy += step
        steps += 1
        return nil if steps > PokeAccess::Routes::Moves::ARRIVAL_CAP
      end
      PokeAccess::World::Probe.landing(x, cy + step)
    end
  end
end

PokeAccess::Routes::Moves.assist_source(:front_flags => [:rockclimb, :rockclimb_crest]) do |x, y, dir, lvl|
  l = PokeAccess::KeishouRockClimb.climb(x, y, dir[2])
  next nil if l.nil?
  PokeAccess::Routes::Moves::Step.new(l[0], l[1], lvl, 1, { :kind => :field, :label => :loc_rock_climb, :move => :ROCKCLIMB, :x => x + dir[0], :y => y + dir[1] })
end

PokeAccess::Control.carrier(:rock_climb) { $PokemonGlobal.rockclimbing }

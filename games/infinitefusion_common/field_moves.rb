# The saga's field moves also work from the bag: a surfboard for Surf, scuba gear for Dive and climbing gear for
# Rock Climb, which jumps two tiles over a ledge, up as well as down (the assisted step).
PokeAccess::Game.define("infinitefusion_common") do
  field_move_item(:SURF, :SURFBOARD)
  field_move_item(:DIVE, :SCUBAGEAR)
  field_move_item(:ROCKCLIMB, :CLIMBINGGEAR)

  assisted_step do |x, y, dir, lvl|
    next nil unless PokeAccess::Terrain.ledge_at?(x + dir[0], y + dir[1])
    l = PokeAccess::Pathfinder.landing(x + 2 * dir[0], y + 2 * dir[1])
    next nil if l.nil?
    PokeAccess::Pathfinder::Step.new(l[0], l[1], lvl, 1, { :kind => :field, :label => :loc_ledge, :move => :ROCKCLIMB, :x => x + dir[0], :y => y + dir[1] })
  end
end

# The saga's field moves also work from the bag, with no Pokemon and no badge: a machete for Cut, a pickaxe for Rock
# Smash, a lever for Strength, a surfboard for Surf, a jetpack for Waterfall, scuba gear for Dive and climbing gear
# for Rock Climb, which jumps two tiles over a ledge, up as well as down (the assisted step).
PokeAccess::Game.define("infinitefusion_common") do
  field_move_item(:CUT, :MACHETE)
  field_move_item(:ROCKSMASH, :PICKAXE)
  field_move_item(:STRENGTH, :LEVER)
  field_move_item(:SURF, :SURFBOARD)
  field_move_item(:WATERFALL, :JETPACK)
  field_move_item(:DIVE, :SCUBAGEAR)
  field_move_item(:ROCKCLIMB, :CLIMBINGGEAR)

  # Both games' pbSurf refuse while anyone walks along as a dependent event.
  surf_company(:dependents)

  # The climb is the game's pbJumpToward(2): it lands where the jump may (passable? of the landing, which refuses a
  # tile someone stands on), as the core's ledge hop asks.
  assisted_step(:front_tiles => lambda { |x, y| PokeAccess::World::Terrain.ledge?(x, y) }) do |x, y, dir, lvl|
    next nil unless PokeAccess::World::Terrain.ledge?(x + dir[0], y + dir[1])
    lx = x + 2 * dir[0]
    ly = y + 2 * dir[1]
    next nil if PokeAccess::Routes::Moves.obstacle_at?(lx, ly) || !PokeAccess::World::Probe.lands?(x, y, dir[2], lx, ly)
    PokeAccess::Routes::Moves::Step.new(lx, ly, lvl, 1, { :kind => :field, :label => :loc_ledge, :move => :ROCKCLIMB, :x => x + dir[0], :y => y + dir[1] })
  end
end

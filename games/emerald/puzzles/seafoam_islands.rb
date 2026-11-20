# Seafoam Islands (maps 725 to 728): Strength boulders to drop through holes, each watched by a parallel event that
# waits for it on one tile and then turns on its switch; a boulder that falls shows up on the floor below. TARGETS holds
# per map each boulder, the tile its check waits for and its switch. The two boulders that fall from map 727 land on map
# 728 at (28,11) and (29,11), in the current (var 190 at 2 calms it), away from that floor's own four. The core's push
# planner (Planner.carry, run on the real maps) takes all eight to their tiles with the assist.
module PokeAccess
  module EmSeafoam
    TARGETS = {
      725 => [[4, [26, 11], 650], [5, [35, 11], 652]],
      726 => [[3, [28, 13], 651], [6, [33, 13], 653]],
      727 => [[2, [29, 11], 655], [3, [33, 11], 654]],
      728 => [[5, [14, 21], 648], [2, [11, 21], 649]]
    }
  end
end

PokeAccess::Game.define("emerald") do
  PokeAccess::EmSeafoam::TARGETS.each do |map, boulders|
    mechanic(:state, map) do
      auto
      boulders.each do |id, (x, y), sw|
        watch :switch => sw, :say => :em_seafoam_fell
        phase lambda { !$game_switches[sw] }, :quiet => true, :hint => :em_seafoam_hint,
              :track => { :event => id, :label => :em_seafoam_boulder, :goal => [x, y, x, y], :goal_label => :em_seafoam_hole }
      end
      solved(nil, :quiet => true) { boulders.all? { |_, _, sw| $game_switches[sw] } }
    end
  end
end

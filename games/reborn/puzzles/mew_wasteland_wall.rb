# The Wasteland Wall (map 279): Strength boulders dropped through holes, each watched by a parallel event that turns its
# switch on. HOLES holds each boulder, the tile its check waits for and its switch; the first and last show on the floor
# below (events 31 and 29), the second as boulder 26 once 385 is on. The west exit 5 turns the switches off.
module PokeAccess
  module RebornMewWastelandWall
    HOLES = [[1, [20, 37], 384], [3, [31, 14], 385], [26, [46, 37], 386]]

    # True while the boulder stands on the floor above: its switch is off and, for the last one, the one before is on.
    def self.waiting?(id, sw)
      return false if $game_switches[sw]
      id != 26 || $game_switches[385]
    end
  end
end

PokeAccess::Game.define("reborn") do
  wall = PokeAccess::RebornMewWastelandWall
  mechanic(:state, 279, :part => :holes) do
    auto
    wall::HOLES.each do |id, (x, y), sw|
      watch :switch => sw, :say => :rbe_ww_fell
      phase lambda { wall.waiting?(id, sw) }, :quiet => true, :hint => :rbe_ww_hint,
            :track => { :event => id, :label => :rbe_ww_boulder, :goal => [x, y, x, y], :goal_label => :rbe_ww_hole }
    end
    solved(nil, :quiet => true) { wall::HOLES.all? { |_, _, sw| $game_switches[sw] } }
  end
end

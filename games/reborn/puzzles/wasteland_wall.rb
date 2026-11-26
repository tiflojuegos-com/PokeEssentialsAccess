# Wasteland Wall (map 212), Medicham at level 65: the Strength boulder at (32, 12) runs east to the hole at (44, 12); a
# parallel process sets switch 192 and it drops to (44, 32), breaking the rock at (43, 32). The player drops through the
# hole onto (45, 32) and pushes it west to the way out at (39, 31). The fall is said; with the assist, what to push.
module PokeAccess
  module RebornWastelandWall
    MAP = 212
    HOLE = 7
    LOWER = 3
    DROPPED = 192

    # True while the boulder that fell still stands under the way out or east of it, on the one-tile corridor.
    def self.lower_in_way?
      ev = $game_map.events[LOWER]
      ev && ev.x >= 39
    end
  end
end

PokeAccess::Game.define("reborn") do
  ww = PokeAccess::RebornWastelandWall
  mechanic(:state, ww::MAP, :part => :boulder_hole) do
    auto
    name ww::HOLE, :rbd_ww_hole
    watch :switch => ww::DROPPED, :say => :rbd_ww_dropped
    sent_back :rbd_ww_fell, :to => [45, 32], :events => [ww::HOLE]
    phase(lambda { PokeAccess::Puzzles.assist? && !$game_switches[ww::DROPPED] }, :quiet => true,
          :hint => :rbd_ww_hint_push)
    phase(lambda { PokeAccess::Puzzles.assist? && $game_switches[ww::DROPPED] && ww.lower_in_way? }, :quiet => true,
          :hint => :rbd_ww_hint_below)
    solved(nil, :quiet => true) { $game_switches[ww::DROPPED] && !ww.lower_in_way? }
  end
end

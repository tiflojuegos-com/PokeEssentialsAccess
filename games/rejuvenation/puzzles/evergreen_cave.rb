# Evergreen Cave, north (maps 485, 486 and 490): variable 471 is the boulders' stage, reset to 0 on leaving map 485 by
# its doors unless it is 7. Boulder 1 onto the hole (21,10) makes 1; on map 490 boulder 17 into (30,15) makes 4 (the
# holes (12,13) and (17,21) make 2 and 3, dead ends), then boulder 19 into (20,58) makes 5 and 7, opening map 491.
# Map 485's icy field melts on a water-surface battle and drops the player to map 486, the same cave without the ice.
module PokeAccess
  module RejuvEvergreen
    # The boulders' stage.
    def self.stage
      $game_variables[471].to_i
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  evergreen = PokeAccess::RejuvEvergreen
  mechanic(:state, [485, 486], :part => :boulders) do
    auto
    phase lambda { evergreen.stage == 0 }, :quiet => true, :hint => :rj_evergreen_first_hint,
          :track => { :event => 1, :label => :rj_evergreen_boulder, :goal => [21, 10, 21, 10], :goal_label => :rj_evergreen_hole }
    phase lambda { [2, 3].include?(evergreen.stage) }, :quiet => true, :hint => :rj_evergreen_wrong_hole
    phase lambda { evergreen.stage.between?(1, 6) }, :quiet => true, :hint => :rj_evergreen_go_down
    solved(nil, :quiet => true) { evergreen.stage >= 7 }
  end
  mechanic(:state, 485, :part => :ice) do
    auto
    active { PokeAccess::Puzzles.assist? }
    hint :rj_evergreen_ice_hint
  end
  mechanic(:state, 486) do
    auto
    sent_back :rj_evergreen_fell, :maps => [485]
  end
  mechanic(:state, 490, :part => :boulders) do
    auto
    phase lambda { evergreen.stage == 0 }, :quiet => true, :hint => :rj_evergreen_back_up
    phase lambda { evergreen.stage == 1 }, :quiet => true, :hint => :rj_evergreen_second_hint,
          :track => { :event => 17, :label => :rj_evergreen_boulder, :goal => [30, 15, 30, 15], :goal_label => :rj_evergreen_hole }
    phase lambda { [2, 3].include?(evergreen.stage) }, :quiet => true, :hint => :rj_evergreen_wrong_hole
    phase lambda { evergreen.stage == 4 }, :quiet => true, :hint => :rj_evergreen_third_hint,
          :track => { :event => 19, :label => :rj_evergreen_boulder, :goal => [20, 58, 20, 58], :goal_label => :rj_evergreen_hole }
    solved(nil, :quiet => true) { evergreen.stage >= 5 }
  end
end

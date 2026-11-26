# Byxbysion Cave 3F (map 277), on Mew's way: three reactor buttons at the foot of their tubes (events 42, 46 and 50),
# each under a field boulder, toggle switches 380 to 382 when pressed facing north; all three on, event 54 lights 383
# and the pink tree before the north-east exit goes. The stairs (event 88) turn them off; the assist gives the pushes.
module PokeAccess
  module RebornByxbysion
    MAP = 277
    BUTTONS = [42, 46, 50]
    # Per switch, in the order the plan takes them: the button's number in reading order and the pushes, each a boulder
    # by where it starts and the way it goes.
    PLANS = [
      [381, 2, [[18, 10, 2], [19, 11, 2], [20, 12, 2], [21, 13, 2], [22, 14, 2], [24, 14, 6]]],
      [380, 1, [[12, 10, 2], [14, 10, 6], [14, 12, 2], [13, 13, 2], [12, 14, 2], [10, 14, 4]]],
      [382, 3, [[15, 13, 2], [17, 13, 6], [19, 15, 6], [20, 16, 6], [20, 18, 2], [19, 19, 2], [17, 19, 4]]]
    ]
    WAYS = { 2 => :rbf_dir_down, 4 => :rbf_dir_left, 6 => :rbf_dir_right, 8 => :rbf_dir_up }

    # The plan for the first button of PLANS still off, said as a list of pushes.
    def self.hint
      plan = PLANS.find { |sw, _n, _pushes| !$game_switches[sw] }
      return nil unless plan
      steps = plan[2].map { |x, y, d| PokeAccess::I18n.t(:rbf_byx_push, :x => x, :y => y, :dir => PokeAccess::I18n.t(WAYS[d])) }
      [:rbf_byx_plan, { :list => steps.join("; "), :n => plan[1] }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  cave = PokeAccess::RebornByxbysion
  mechanic(:state, cave::MAP) do
    auto
    not_control cave::BUTTONS
    name cave::BUTTONS, :rbf_byx_button, :numbered => true
    count :rbf_byx_count, :switches => [380, 381, 382]
    arrival_hint :rbf_byx_rule
    phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[383] }, :quiet => true, :hint => lambda { cave.hint }
    solved(:rbf_byx_open) { $game_switches[383] }
  end
end

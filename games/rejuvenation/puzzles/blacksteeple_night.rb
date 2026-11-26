# Blacksteeple Castle while Emma sneaks out by night (switch 1291, variable 232). Maps 435 and 438, from 232 at 64:
# guards named Trainer(n) see n tiles ahead, Counter(n) see over obstacles; one that sees Emma sends her to her cell.
# Map 443: robots to their panels (232 at 36 and 37; events 55 and 56 fly Emma over the gap), then the plans (event 85).
module PokeAccess
  module RejuvBlacksteepleNight
    ROBOTS = [[35, [78, 69], :rjd_bs_robot_gold, :rjd_bs_panel_gold],
              [32, [67, 69], :rjd_bs_robot_purple, :rjd_bs_panel_purple],
              [31, [53, 76], :rjd_bs_robot_green, :rjd_bs_panel_green]]

    # Emma's night step, variable 232.
    def self.step; $game_variables[232].to_i; end

    # True while the guards watch the halls.
    def self.night?; $game_switches[1291] && step >= 64 && step < 67; end

    # True while the robots wait for their panels.
    def self.robots?; step == 36 || step == 37; end

    # True when robot id stands on its panel.
    def self.placed?(id, goal)
      ev = $game_map.events[id]
      !ev.nil? && ev.x == goal[0] && ev.y == goal[1]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  night = PokeAccess::RejuvBlacksteepleNight
  watchers([435, 438])
  mechanic(:state, [435, 438], :part => :guards) do
    auto
    name(/^(Trainer|Counter)\(\d+\)$/, lambda { |_ev| night.night? ? :rjd_bs_guard : nil },
         :when => lambda { |_ev| night.night? })
    arrival_hint lambda { night.night? ? :rjd_bs_stealth_rule : nil }, :once => true
    active { night.night? }
  end
  mechanic(:state, 443, :part => :robots) do
    auto
    night::ROBOTS.each do |id, goal, label, panel|
      name id, label, :when => lambda { |_ev| night.robots? }
      spot :at => goal, :label => panel, :when => lambda { night.robots? }
      phase(lambda { night.robots? && !night.placed?(id, goal) }, :quiet => true,
            :track => { :event => id, :label => label, :goal => [goal[0], goal[1], goal[0], goal[1]], :goal_label => panel })
    end
    name [55, 56], :rjd_bs_fly, :when => lambda { |_ev| night.robots? }
    hint :rjd_bs_robots_hint
    active { night.robots? }
    solved { night.step >= 38 }
  end
  mechanic(:state, 443, :part => :plans) do
    auto
    on_reach 85, { :text => /Oh wow/ }, :rjd_bs_plans_picture
    spot :event => 86, :label => :rjd_bs_plans_bookcase, :assist => true, :when => lambda { night.step == 67 }
    hint :rjd_bs_plans_hint
    active { night.step == 67 }
    solved { night.step >= 68 }
  end
end

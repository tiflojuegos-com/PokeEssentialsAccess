# The Underground Railnet (map 228) once the train is boarded (switch 969): twelve levers turn the junction beside each,
# one press a step (variables 124 to 129, 131, 132 and 134 to 137, back to 0 after the last). Noel (event 83) turns
# switch 971 on when ten are set as he wants. Levers 3 and 9 are off the way; the core says what the gates open.
module PokeAccess
  module RebornRailnet
    MAP = 228
    # [event, variable, the junction at each value, the value Noel wants or nil], in the game's order.
    LEVERS = [
      [17, 124, [:rbf_rail_se, :rbf_rail_ns], 1], [26, 125, [:rbf_rail_sw, :rbf_rail_ns, :rbf_rail_se], 2],
      [37, 126, [:rbf_rail_ns, :rbf_rail_ne], nil], [46, 127, [:rbf_rail_sw, :rbf_rail_we, :rbf_rail_nw], 1],
      [57, 128, [:rbf_rail_ns, :rbf_rail_sw], 1], [66, 129, [:rbf_rail_nw, :rbf_rail_ns, :rbf_rail_ne], 2],
      [86, 131, [:rbf_rail_sw, :rbf_rail_ns, :rbf_rail_se], 1], [97, 132, [:rbf_rail_se, :rbf_rail_ns, :rbf_rail_sw], nil],
      [117, 134, [:rbf_rail_we, :rbf_rail_se], 1], [126, 135, [:rbf_rail_we, :rbf_rail_sw], 0],
      [135, 136, [:rbf_rail_nw, :rbf_rail_ns], 1], [144, 137, [:rbf_rail_se, :rbf_rail_we, :rbf_rail_ne], 2]
    ]

    # True while Noel waits for the switches.
    def self.live?
      $game_switches[969] && !$game_switches[971] ? true : false
    end

    # Presses a lever still needs, or nil for one Noel does not check.
    def self.left(lever)
      return nil unless lever[3]
      (lever[3] - $game_variables[lever[1]].to_i) % lever[2].size
    end

    # How many of the ten checked switches stand as Noel wants.
    def self.right
      LEVERS.select { |lv| left(lv) == 0 }.size
    end

    # The phase's values: each lever as its junction now.
    def self.values
      out = []
      LEVERS.each_with_index do |lv, k|
        words = {}
        lv[2].each_with_index { |w, v| words[v] = w }
        out.push(:var => lv[1], :event => lv[0], :label => [:rbf_rail_lever, { :n => k + 1 }], :words => words)
      end
      out
    end

    # With the assist, the presses left on each lever, or that Noel can be asked.
    def self.plan
      return nil unless PokeAccess::Puzzles.assist?
      list = []
      LEVERS.each_with_index do |lv, k|
        n = left(lv)
        next unless n && n > 0
        list.push(PokeAccess::I18n.t(:rbf_rail_times, :name => PokeAccess::I18n.t(:rbf_rail_lever, :n => k + 1), :n => n))
      end
      list.empty? ? :rbf_rail_ready : [:rbf_rail_plan, { :list => list.join(", ") }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  rail = PokeAccess::RebornRailnet
  mechanic(:state, rail::MAP, :part => :train) do
    auto
    not_control rail::LEVERS.map { |lv| lv[0] }
    phase lambda { !$game_switches[971] }, :title => :rbf_rail_title, :quiet => true, :values => rail.values,
          :hint => lambda { rail.plan }
    count :rbf_rail_right, :value => lambda { rail.right }, :of => 10, :assist => true, :reset => false
    arrival_hint lambda { rail.live? ? :rbf_rail_rule : nil }, :once => true
    active { rail.live? }
    solved(nil, :quiet => true) { $game_switches[971] }
  end
end

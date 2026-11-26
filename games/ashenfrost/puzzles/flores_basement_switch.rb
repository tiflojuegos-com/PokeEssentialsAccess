# The Flores Mansion's basement switch (map 646, Case Fifteen): EV26, on the wall at (14,47) with no graphic, lowers the
# spikes EV25 at (14,43) through their self switch A. Nothing needs it, so the assist only says what it opens, below the
# combination door.
module PokeAccess
  module AshenBasementSwitch
    MAP = 646
    SWITCH = 26
    SPIKES = 25
    # The first row of the basement's part behind the combination door, where the switch and the spikes are.
    LOWER_ROW = 42

    # Whether the switch has been pressed: the spikes' self switch it sets.
    def self.pressed?
      $game_self_switches[[MAP, SPIKES, "A"]] ? true : false
    end

    # The spikes' name: lowered once the switch is pressed.
    def self.spikes_label
      pressed? ? :aff_spikes_down : :aff_spikes
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  basement = PokeAccess::AshenBasementSwitch
  mechanic(:state, basement::MAP, :part => :aff_basement_switch) do
    auto
    name basement::SWITCH, :aff_wall_switch, :when => lambda { |_ev| !basement.pressed? }
    name basement::SPIKES, lambda { |_ev| basement.spikes_label }, :when => lambda { |_ev| !basement.pressed? }
    phase lambda { $game_player.y >= basement::LOWER_ROW && !basement.pressed? }, :quiet => true, :hint => :aff_switch_hint
    solved(nil, :quiet => true) { basement.pressed? }
  end
end

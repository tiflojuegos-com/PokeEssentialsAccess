# Yureyu Power Plant (map 198), on the way to Shade: four monitors drawn on the walls of the dark rooms, used facing
# them: events 7 (13,4), 8 (13,13), 9 (35,13) and 10 (35,4). Each pings once, sets its self switch A and adds 1 to the
# story variable 104, from 28; on map 197 the barriers of the hall to Shade open at 29, 30, 31 and 32.
module PokeAccess
  module RebornYureyu
    MAP = 198
    MONITORS = [7, 8, 9, 10]
    DONE = 32

    # True once the monitor has been switched on.
    def self.on?(id); $game_self_switches[[MAP, id, "A"]] ? true : false; end

    # A monitor's name, on or off.
    def self.label(ev); on?(ev.id) ? :rbc_yureyu_monitor_on : :rbc_yureyu_monitor; end
  end
end

PokeAccess::Game.define("reborn") do
  plant = PokeAccess::RebornYureyu
  mechanic(:state, plant::MAP, :part => :monitors) do
    auto
    name plant::MONITORS, lambda { |ev| plant.label(ev) }
    count :rbc_yureyu_monitors, :selfs => [plant::MONITORS, "A", plant::MAP], :announce => false
    arrival_hint :rbc_yureyu_rule
    hint :rbc_yureyu_hint
    solved { $game_variables[104].to_i >= plant::DONE }
  end
end
